"""Provider 适配:Gemini 主用,无 key/失败一律返回 None 由上层降级 mock。

key 只从环境变量 / server/.env 读取,绝不出现在代码与日志里。
"""
from __future__ import annotations

import json
import os

from pydantic import BaseModel

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass


class VisionResult(BaseModel):
    device_category: str
    brand: str | None = None
    model: str | None = None
    error_code: str | None = None
    visible_faults: list[str] = []
    confidence: float = 0.0


class GeneratedStep(BaseModel):
    content: str
    citation_manual: str
    citation_section: str


class GenerationResult(BaseModel):
    decision: str  # diy / landlord / professional
    decision_reason: str
    steps: list[GeneratedStep]


_VISION_PROMPT = """你是家电维修诊断系统的视觉提取模块。观察这张照片,只输出 JSON,字段:
device_category(设备类别,英文 snake_case,如 washing_machine/router/microwave/ikea_furniture)
brand(品牌,认不出为 null)
model(型号,认不出为 null)
error_code(屏幕上/铭牌上的错误码,没有为 null)
visible_faults(可见故障迹象,中文短语列表)
confidence(0-1,整体识别置信度)
拿不准就把 confidence 调低,不要编造型号。"""

_MODEL = "gemini-2.5-flash"


def _client():
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        return None
    from google import genai

    return genai.Client(api_key=key)


def gemini_extract(image_bytes: bytes, mime_type: str = "image/jpeg") -> VisionResult | None:
    client = _client()
    if client is None:
        return None
    try:
        from google.genai import types

        resp = client.models.generate_content(
            model=_MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                _VISION_PROMPT,
            ],
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )
        return VisionResult.model_validate(json.loads(resp.text))
    except Exception:
        return None


def gemini_generate(vision: VisionResult, chunks: list[dict]) -> GenerationResult | None:
    """基于检索到的手册片段生成分步指导;约束只能引用给定片段。

    chunks: [{"manual": 手册名, "section": 章节号, "text": 原文}]
    """
    client = _client()
    if client is None or not chunks:
        return None
    corpus = "\n\n".join(
        f"[{i}] 《{c['manual']}》{c['section']}\n{c['text']}" for i, c in enumerate(chunks)
    )
    prompt = f"""你是家电维修指导生成器。用户设备:{vision.device_category},品牌:{vision.brand or "未知"},
错误码:{vision.error_code or "无"},可见故障:{",".join(vision.visible_faults) or "无"}。

只能依据以下手册片段生成修理步骤,严禁编造片段之外的内容:
{corpus}

输出 JSON:
decision:diy(适合自修)/ landlord(找房东)/ professional(必须找师傅)
decision_reason:一句话理由(中文)
steps:3-6 步,每步 content(中文操作说明)、citation_manual(手册名,必须与片段一致)、
citation_section(章节号,必须与片段一致)"""
    try:
        resp = client.models.generate_content(
            model=_MODEL,
            contents=prompt,
            config={"response_mime_type": "application/json"},
        )
        return GenerationResult.model_validate(json.loads(resp.text))
    except Exception:
        return None


def status() -> dict:
    """供 /api/health 汇报(只报 key 有无,绝不报本体)。"""
    return {"gemini": bool(os.environ.get("GEMINI_API_KEY"))}
