"""管线编排(PRD §8):质量门 → vision → 安全门 → 检索 → 生成 → 引用校验。

真管线任一步失败都降级 mock 确定性模式,演示永不翻车。
"""
from __future__ import annotations

import io

from PIL import Image, ImageFilter, ImageStat

import mock_data
import providers
import retrieval
import safety_gate


class QualityError(Exception):
    """照片质量不合格,前端应引导重拍。"""


def quality_gate(image_bytes: bytes) -> None:
    """分辨率 / 亮度 / 模糊度三道检查,任一不过即抛 QualityError。"""
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("L")
    except Exception:
        raise QualityError("无法识别的图片,请重拍")
    w, h = img.size
    if min(w, h) < 480:
        raise QualityError("照片分辨率过低,请靠近一些重拍")
    brightness = ImageStat.Stat(img).mean[0]
    if brightness < 25:
        raise QualityError("照片过暗,请开灯或到亮处重拍")
    # 模糊度:边缘能量的方差近似 Laplacian 方差(无 OpenCV 依赖)
    edges = img.filter(ImageFilter.FIND_EDGES)
    if ImageStat.Stat(edges).var[0] < 20:
        raise QualityError("照片模糊,请拿稳对焦后重拍")


def _persist(session: dict, conn) -> dict:
    import uuid
    from datetime import datetime, timezone

    session["id"] = str(uuid.uuid4())
    session["created_at"] = datetime.now(timezone.utc).isoformat()
    session.setdefault("safety_refused", False)
    conn.execute(
        "INSERT INTO sessions VALUES (:id,:device_category,:brand,:model,:error_code,"
        ":decision,:decision_reason,:safety_refused,:created_at)",
        {**session, "safety_refused": int(session["safety_refused"])},
    )
    for i, (content, manual, section) in enumerate(session.pop("steps"), start=1):
        step = {"id": str(uuid.uuid4()), "session_id": session["id"], "idx": i,
                "content": content, "citation_manual": manual,
                "citation_section": section, "feedback": None}
        session.setdefault("steps", []).append(step)
        conn.execute(
            "INSERT INTO steps VALUES (:id,:session_id,:idx,:content,"
            ":citation_manual,:citation_section,:feedback)", step)
    return session


def _mock_session(image_bytes: bytes, filename: str | None) -> dict:
    return dict(mock_data.route(filename, image_bytes))


def analyze_image(image_bytes: bytes, filename: str | None, mock: bool, conn) -> dict:
    quality_gate(image_bytes)  # 质量门对 mock/真实模式同样生效(场景 5 靠它)

    if mock:
        return _persist(_mock_session(image_bytes, filename), conn)

    vision = providers.gemini_extract(image_bytes)
    if vision is None:
        return _persist(_mock_session(image_bytes, filename), conn)

    verdict = safety_gate.check(vision.device_category, vision.brand,
                                *vision.visible_faults)
    if verdict.refused:
        return _persist({
            "device_category": vision.device_category, "brand": vision.brand,
            "model": vision.model, "error_code": vision.error_code,
            "decision": "refused", "decision_reason": f"{verdict.reason}{verdict.advice}",
            "safety_refused": True, "steps": [],
        }, conn)

    query = f"{vision.device_category} {vision.brand or ''} {vision.error_code or ''} " \
            f"{' '.join(vision.visible_faults)}"
    chunks = retrieval.search(query, vision.device_category, vision.error_code)
    gen = providers.gemini_generate(vision, chunks)
    if gen is None:  # 生成失败或语料空:降级 mock,前端标注演示数据
        return _persist(_mock_session(image_bytes, filename), conn)

    # 引用校验:引用不在检索到的片段集合内的步骤丢弃(宁缺毋假)
    valid = {(c["manual"], c["section"]) for c in chunks}
    steps = [(s.content, s.citation_manual, s.citation_section)
             for s in gen.steps if (s.citation_manual, s.citation_section) in valid]
    return _persist({
        "device_category": vision.device_category, "brand": vision.brand,
        "model": vision.model, "error_code": vision.error_code,
        "decision": gen.decision, "decision_reason": gen.decision_reason,
        "steps": steps,
    }, conn)


def diagnose_manual(brand: str, error_code: str, mock: bool, conn) -> dict:
    verdict = safety_gate.check(brand, error_code)
    if verdict.refused:
        return _persist({
            "device_category": "unknown", "brand": brand, "model": None,
            "error_code": error_code, "decision": "refused",
            "decision_reason": f"{verdict.reason}{verdict.advice}",
            "safety_refused": True, "steps": [],
        }, conn)

    chunks = retrieval.search(f"{brand} {error_code}", None, error_code)
    if mock:
        return _persist(_mock_session(f"{brand}{error_code}".encode(), "e24"
                                      if error_code.strip().lower() == "e24" else ""), conn)

    vision = providers.VisionResult(device_category="unknown", brand=brand,
                                    error_code=error_code, confidence=1.0)
    gen = providers.gemini_generate(vision, chunks) if chunks else None
    if gen is None:
        return _persist(_mock_session(f"{brand}{error_code}".encode(), ""), conn)
    valid = {(c["manual"], c["section"]) for c in chunks}
    steps = [(s.content, s.citation_manual, s.citation_section)
             for s in gen.steps if (s.citation_manual, s.citation_section) in valid]
    return _persist({
        "device_category": "unknown", "brand": brand, "model": None,
        "error_code": error_code, "decision": gen.decision,
        "decision_reason": gen.decision_reason, "steps": steps,
    }, conn)
