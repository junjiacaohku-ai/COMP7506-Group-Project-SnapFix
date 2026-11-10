"""管线编排：质量门 → vision → 安全门 → 检索 → 生成 → 引用校验。"""
from __future__ import annotations

import io

from PIL import Image, ImageFilter, ImageStat

import mock_data
import providers
import retrieval
import safety_gate


class QualityError(Exception):
    """照片质量不合格，前端应引导重拍。"""


class AnalysisError(Exception):
    def __init__(self, message: str, status_code: int = 503):
        super().__init__(message)
        self.status_code = status_code


def quality_gate(image_bytes: bytes) -> str:
    try:
        source = Image.open(io.BytesIO(image_bytes))
        mime_type = Image.MIME.get(source.format or "", "image/jpeg")
        img = source.convert("L")
    except Exception:
        raise QualityError("无法识别的图片,请重拍")
    w, h = img.size
    if min(w, h) < 480:
        raise QualityError("照片分辨率过低,请靠近一些重拍")
    brightness = ImageStat.Stat(img).mean[0]
    if brightness < 25:
        raise QualityError("照片过暗,请开灯或到亮处重拍")
    edges = img.filter(ImageFilter.FIND_EDGES)
    if ImageStat.Stat(edges).var[0] < 20:
        raise QualityError("照片模糊,请拿稳对焦后重拍")
    return mime_type


def _persist(session: dict, conn, user_id) -> dict:
    import uuid
    from datetime import datetime, timezone

    session["id"] = str(uuid.uuid4())
    session["created_at"] = datetime.now(timezone.utc).isoformat()
    session.setdefault("safety_refused", False)
    session.setdefault("diagnosis_source", "mock")
    session.setdefault("confidence", None)
    conn.execute(
        "INSERT INTO sessions (id,device_category,brand,model,error_code,"
        "decision,decision_reason,safety_refused,diagnosis_source,confidence,"
        "created_at,user_id) "
        "VALUES (:id,:device_category,:brand,:model,:error_code,"
        ":decision,:decision_reason,:safety_refused,:diagnosis_source,"
        ":confidence,:created_at,:user_id)",
        {
            **session,
            "user_id": user_id,
            "safety_refused": int(session["safety_refused"]),
        },
    )
    steps = session.pop("steps")
    session["steps"] = []
    for i, (content, manual, section) in enumerate(steps, start=1):
        step = {
            "id": str(uuid.uuid4()),
            "session_id": session["id"],
            "idx": i,
            "content": content,
            "citation_manual": manual,
            "citation_section": section,
            "feedback": None,
        }
        session.setdefault("steps", []).append(step)
        conn.execute(
            "INSERT INTO steps VALUES (:id,:session_id,:idx,:content,"
            ":citation_manual,:citation_section,:feedback)",
            step,
        )
    return session


def _mock_session(image_bytes: bytes, filename: str | None) -> dict:
    return dict(mock_data.route(filename, image_bytes))


def _vision_session(vision: providers.VisionResult, provider: str) -> dict:
    return {
        "device_category": vision.device_category,
        "brand": vision.brand,
        "model": vision.model,
        "error_code": vision.error_code,
        "diagnosis_source": provider,
        "confidence": vision.confidence,
    }


def _without_steps(session: dict, reason: str) -> dict:
    return {
        **session,
        "decision": "professional",
        "decision_reason": reason,
        "steps": [],
    }


def _citation_key(manual: str, section: str) -> tuple[str, str]:
    manual = manual.strip()
    section = section.strip()
    if manual.startswith("《") and "》" in manual:
        title, suffix = manual[1:].split("》", 1)
        if not suffix.strip() or suffix.strip() == section:
            manual = title.strip()
    return manual, section


def _generated_session(
    session: dict,
    gen: providers.GenerationResult,
    chunks: list[dict],
) -> dict:
    valid = {
        _citation_key(c["manual"], c["section"]): (c["manual"], c["section"])
        for c in chunks
    }
    steps = []
    for step in gen.steps:
        citation = valid.get(
            _citation_key(step.citation_manual, step.citation_section)
        )
        if citation:
            steps.append((step.content, *citation))
    if gen.decision == "diy" and not steps:
        return _without_steps(
            session, "生成内容未通过手册引用校验，已停止提供自行维修步骤。"
        )
    return {
        **session,
        "decision": gen.decision,
        "decision_reason": gen.decision_reason,
        "steps": steps,
    }


def analyze_image(
    image_bytes: bytes,
    filename: str | None,
    provider: str | None,
    conn,
    user_id,
    language: str = "zh",
) -> dict:
    mime_type = quality_gate(image_bytes)
    if provider is None:
        return _persist(_mock_session(image_bytes, filename), conn, user_id)

    try:
        vision = providers.extract(image_bytes, provider, mime_type)
    except providers.ProviderError as exc:
        raise AnalysisError(str(exc)) from exc
    if vision.device_category.strip().lower() in {
        "",
        "unknown",
        "other",
        "unsupported",
        "none",
    }:
        raise AnalysisError(
            "无法可靠识别设备，请补拍整机、铭牌或错误码", status_code=422
        )

    verdict = safety_gate.check(
        vision.device_category, vision.brand, *vision.visible_faults
    )
    if verdict.refused:
        return _persist(
            {
                **_vision_session(vision, provider),
                "decision": "refused",
                "decision_reason": f"{verdict.reason}{verdict.advice}",
                "safety_refused": True,
                "steps": [],
            },
            conn,
            user_id,
        )

    query = (
        f"{vision.device_category} {vision.brand or ''} {vision.error_code or ''} "
        f"{' '.join(vision.visible_faults)}"
    )
    chunks = retrieval.search(query, vision.device_category, vision.error_code)
    session = _vision_session(vision, provider)
    if not chunks:
        return _persist(
            _without_steps(
                session, "未找到与此设备匹配的手册，无法提供有依据的自行维修步骤。"
            ),
            conn,
            user_id,
        )
    try:
        gen = providers.generate(vision, chunks, provider, language)
    except providers.ProviderError as exc:
        raise AnalysisError(str(exc)) from exc
    return _persist(_generated_session(session, gen, chunks), conn, user_id)


def diagnose_manual(
    brand: str,
    error_code: str,
    provider: str | None,
    conn,
    user_id,
    language: str = "zh",
) -> dict:
    source = provider or "mock"
    verdict = safety_gate.check(brand, error_code)
    if verdict.refused:
        return _persist(
            {
                "device_category": "unknown",
                "brand": brand,
                "model": None,
                "error_code": error_code,
                "decision": "refused",
                "decision_reason": f"{verdict.reason}{verdict.advice}",
                "safety_refused": True,
                "diagnosis_source": source,
                "steps": [],
            },
            conn,
            user_id,
        )

    if provider is None:
        return _persist(
            _mock_session(
                f"{brand}{error_code}".encode(),
                "e24" if error_code.strip().lower() == "e24" else "",
            ),
            conn,
            user_id,
        )

    vision = providers.VisionResult(
        device_category="unknown", brand=brand, error_code=error_code
    )
    session = _vision_session(vision, provider)
    session["confidence"] = None
    chunks = retrieval.search(f"{brand} {error_code}", None, error_code)
    if not chunks:
        return _persist(
            _without_steps(
                session, "未找到与品牌和错误码匹配的手册，无法提供维修步骤。"
            ),
            conn,
            user_id,
        )
    try:
        gen = providers.generate(vision, chunks, provider, language)
    except providers.ProviderError as exc:
        raise AnalysisError(str(exc)) from exc
    return _persist(_generated_session(session, gen, chunks), conn, user_id)
