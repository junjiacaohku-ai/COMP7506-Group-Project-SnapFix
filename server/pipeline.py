"""质量门 → 视觉提取 → 安全门 → BM25 → 生成 → chunk 引用与安全复核。"""
from __future__ import annotations

import io
import re

from PIL import Image

import mock_data
import providers
import retrieval
import safety_gate
from image_quality import check_image


class QualityError(Exception):
    """照片质量不合格，前端应引导重拍。"""


class AnalysisError(Exception):
    def __init__(self, message: str, status_code: int = 503):
        super().__init__(message)
        self.status_code = status_code


def _normalize_code(value: str | None) -> str | None:
    value = (value or "").strip().upper()
    return re.sub(r"^E\s*[:：]?\s*(\d+)$", r"E\1", value) or None


def quality_gate(image_bytes: bytes) -> str:
    quality = check_image(image_bytes)
    if not quality.accepted:
        raise QualityError(quality.reason)
    try:
        source = Image.open(io.BytesIO(image_bytes))
        return Image.MIME.get(source.format or "", "image/jpeg")
    except Exception:
        raise QualityError("无法读取图片，请上传有效图片。")


def _persist(session: dict, conn, user_id) -> dict:
    import uuid
    from datetime import datetime, timezone

    session["id"] = str(uuid.uuid4())
    session["created_at"] = datetime.now(timezone.utc).isoformat()
    session.setdefault("safety_refused", False)
    session.setdefault("diagnosis_source", "mock")
    session.setdefault("confidence", None)
    session.setdefault("status", "investigating")
    conn.execute(
        "INSERT INTO sessions (id,device_category,brand,model,error_code,"
        "decision,decision_reason,safety_refused,diagnosis_source,confidence,"
        "status,created_at,user_id) "
        "VALUES (:id,:device_category,:brand,:model,:error_code,"
        ":decision,:decision_reason,:safety_refused,:diagnosis_source,"
        ":confidence,:status,:created_at,:user_id)",
        {
            **session,
            "user_id": user_id,
            "safety_refused": int(session["safety_refused"]),
        },
    )
    steps = session.pop("steps")
    session["steps"] = []
    for i, item in enumerate(steps, start=1):
        content, manual, section = item[:3]
        chunk_id, citation_text = item[3:] if len(item) == 5 else (None, None)
        step = {
            "id": str(uuid.uuid4()),
            "session_id": session["id"],
            "idx": i,
            "content": content,
            "citation_manual": manual,
            "citation_section": section,
            "citation_chunk_id": chunk_id,
            "citation_text": citation_text,
            "feedback": None,
        }
        session["steps"].append(step)
        conn.execute(
            "INSERT INTO steps (id,session_id,idx,content,citation_manual,"
            "citation_section,citation_chunk_id,citation_text,feedback) "
            "VALUES (:id,:session_id,:idx,:content,:citation_manual,"
            ":citation_section,:citation_chunk_id,:citation_text,:feedback)",
            step,
        )
    return session


def _mock_session(
    image_bytes: bytes, filename: str | None, language: str = "zh"
) -> dict:
    session = mock_data.route(filename, image_bytes)
    if session is None:
        raise AnalysisError(
            "无法可靠识别设备，请补拍整机、铭牌或错误码", status_code=422
        )
    session = dict(session)
    verdict = safety_gate.check(
        session["device_category"],
        session.get("brand"),
        session["decision_reason"],
        *(step[0] for step in session["steps"]),
    )
    if verdict.refused:
        return _refusal_session(session, verdict, language)
    return session


def _vision_session(vision: providers.VisionResult, provider: str) -> dict:
    return {
        "device_category": retrieval.normalize_category(vision.device_category),
        "brand": (vision.brand or "").strip() or None,
        "model": (vision.model or "").strip() or None,
        "error_code": _normalize_code(vision.error_code),
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


def _refusal_session(
    session: dict, verdict: safety_gate.SafetyVerdict, language: str
) -> dict:
    localized = safety_gate.localize(verdict, language)
    return {
        **session,
        "decision": "refused",
        "decision_reason": f"{localized.reason}{localized.advice}",
        "safety_refused": True,
        "steps": [],
    }


def _source_label(chunk: dict) -> str:
    section = chunk.get("section") or ""
    if not section or section == f"PDF page {chunk['page']}":
        return f"PDF p.{chunk['page']} · {chunk['id']}"
    return f"{section} · PDF p.{chunk['page']} · {chunk['id']}"


def _generated_session(
    session: dict,
    gen: providers.GenerationResult,
    chunks: list[dict],
) -> dict:
    by_id = {chunk["id"]: chunk for chunk in chunks}
    steps = []
    for generated in gen.steps:
        chunk = by_id.get(generated.citation_chunk_id)
        content = generated.content.strip()
        if chunk is None or not content:
            continue
        if safety_gate.check(
            session["device_category"], session.get("brand"), content
        ).refused:
            continue
        steps.append(
            (
                content,
                chunk["title"],
                _source_label(chunk),
                chunk["id"],
                chunk["content"],
            )
        )
    if gen.decision == "diy" and not steps:
        return _without_steps(
            session, "生成内容未通过手册引用或安全校验，已停止提供自行维修步骤。"
        )
    return {
        **session,
        "decision": gen.decision,
        "decision_reason": gen.decision_reason.strip(),
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
        return _persist(_mock_session(image_bytes, filename, language), conn, user_id)

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

    session = _vision_session(vision, provider)
    verdict = safety_gate.check(
        vision.device_category,
        vision.brand,
        vision.error_code,
        *vision.visible_faults,
    )
    if verdict.refused:
        return _persist(
            _refusal_session(session, verdict, language), conn, user_id
        )
    if vision.confidence < 0.55:
        return _persist(
            _without_steps(
                session,
                "图片识别置信度较低，无法可靠确认设备或故障。请补拍铭牌或错误码，不提供猜测性维修步骤。",
            ),
            conn,
            user_id,
        )

    query = " ".join(
        value
        for value in [
            session["device_category"],
            vision.brand,
            vision.model,
            vision.error_code,
            *vision.visible_faults,
        ]
        if value
    )
    chunks = retrieval.search(
        query,
        session["device_category"],
        session["error_code"],
        brand=vision.brand or "",
    )
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
    code = _normalize_code(error_code) or ""
    session = {
        "device_category": "unknown",
        "brand": brand.strip() or None,
        "model": None,
        "error_code": code,
        "diagnosis_source": source,
        "confidence": None,
    }
    verdict = safety_gate.check(brand, error_code)
    if verdict.refused:
        return _persist(
            _refusal_session(session, verdict, language), conn, user_id
        )

    if provider is None:
        # A code alone does not identify a brand, appliance or model. The only
        # supported manual mock fixture is the explicitly labelled Bosch E24
        # dishwasher scenario; never turn another brand into a Bosch washer.
        if retrieval.normalize_brand(brand) != "bosch" or code != "E24":
            raise AnalysisError(
                "Offline demo supports only Bosch / E24 manual input; configure a live provider "
                "or select an explicit demo scenario."
                if language == "en"
                else "演示模式仅支持 Bosch / E24 手动输入，请启用在线模型或使用明确的演示场景。",
                status_code=422,
            )
        return _persist(
            _without_steps(
                {**session, "device_category": "dishwasher"},
                "Offline demo: Bosch dishwasher E24. The model is unconfirmed; "
                "check its label and matching manual, then contact Bosch service "
                "or a qualified technician. No fault cause or repair procedure "
                "has been verified."
                if language == "en"
                else "离线演示场景：Bosch 洗碗机 E24。型号未确认，请核对铭牌和对应说明书，"
                "联系品牌售后或合资格维修人员；尚未验证故障原因，不提供拆修步骤。",
            ),
            conn,
            user_id,
        )

    chunks = retrieval.search(f"{brand} {code}", None, code, brand=brand)
    if not chunks:
        return _persist(
            _without_steps(
                session, "未找到与品牌和错误码匹配的手册，无法提供维修步骤。"
            ),
            conn,
            user_id,
        )
    vision = providers.VisionResult(
        device_category="unknown", brand=brand, error_code=code
    )
    try:
        gen = providers.generate(vision, chunks, provider, language)
    except providers.ProviderError as exc:
        raise AnalysisError(str(exc)) from exc
    return _persist(_generated_session(session, gen, chunks), conn, user_id)
