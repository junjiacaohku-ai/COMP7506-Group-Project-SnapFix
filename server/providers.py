"""模型服务适配：Qwen 与 Gemini 共用结构化结果，密钥只从环境读取。"""
from __future__ import annotations

import base64
import json
import os
from typing import Literal
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from pydantic import BaseModel, Field

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass


class ProviderError(Exception):
    pass


class VisionResult(BaseModel):
    device_category: str
    brand: str | None = None
    model: str | None = None
    error_code: str | None = None
    visible_faults: list[str] = Field(default_factory=list)
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)


class GeneratedStep(BaseModel):
    content: str
    citation_manual: str
    citation_section: str


class GenerationResult(BaseModel):
    decision: Literal["diy", "landlord", "professional"]
    decision_reason: str
    steps: list[GeneratedStep]


_VISION_PROMPT = """你是家电维修诊断系统的视觉提取模块。只输出一个 JSON 对象，不要使用 Markdown。
字段：
device_category：设备类别，英文 snake_case，例如 washing_machine/router/microwave/ikea_furniture。
brand：实际可见或可明确辨认的品牌，否则 null。
model：实际可见的型号，否则 null，严禁根据外观猜型号。
error_code：屏幕或铭牌上实际可见的错误码，没有则 null。
visible_faults：只列照片中可见的现象，使用简短中文；不要推断内部零件故障。
confidence：0-1 的识别把握，只表示模型自身把握，不代表诊断准确概率。
如果图片与家电、家居维修无关，或无法可靠辨认设备，device_category 返回 unknown，其他无法确认的字段返回 null。
只描述可见信息，不要编造品牌、型号、错误码或故障。"""

_GEMINI_MODEL = "gemini-2.5-flash"
_PROVIDER_ERROR = "AI 诊断服务暂时不可用，请稍后重试"


def configured_provider() -> str | None:
    requested = os.environ.get("AI_PROVIDER", "").strip().lower()
    if requested == "qwen":
        return "qwen" if os.environ.get("DASHSCOPE_API_KEY") else None
    if requested == "gemini":
        return "gemini" if os.environ.get("GEMINI_API_KEY") else None
    if requested:
        return None
    if os.environ.get("DASHSCOPE_API_KEY"):
        return "qwen"
    if os.environ.get("GEMINI_API_KEY"):
        return "gemini"
    return None


def _gemini_client():
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise ProviderError("未配置 Gemini 诊断服务")
    from google import genai

    return genai.Client(api_key=key)


def _generation_prompt(
    vision: VisionResult, chunks: list[dict], language: str
) -> str:
    corpus = "\n\n".join(
        f"[{i}] 《{c['manual']}》{c['section']}\n{c['text']}"
        for i, c in enumerate(chunks)
    )
    output_language = "English" if language == "en" else "简体中文"
    return f"""你是家电维修指导生成器。用户设备：{vision.device_category}，品牌：{vision.brand or "未知"}，
错误码：{vision.error_code or "无"}，可见现象：{",".join(vision.visible_faults) or "无"}。

只能依据以下手册片段生成修理步骤，严禁编造片段之外的操作、工具或结论：
{corpus}

只输出一个 JSON 对象，不要使用 Markdown：
decision：diy（有充分手册依据且适合非破坏性自修）/ landlord（找房东）/ professional（找专业人员）。
decision_reason：一句话，区分可见现象与未经确认的可能原因。
steps：0-6 步，每步包含 content、citation_manual、citation_section。
citation_manual 和 citation_section 必须与上述片段逐字一致。
如果没有充分依据提供安全步骤，steps 返回空数组，decision 使用 professional。
decision_reason 和 steps.content 必须使用{output_language}；手册名和章节保持原文。"""


def _gemini_extract(
    image_bytes: bytes, mime_type: str = "image/jpeg"
) -> VisionResult:
    client = _gemini_client()
    try:
        from google.genai import types

        resp = client.models.generate_content(
            model=_GEMINI_MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                _VISION_PROMPT,
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json"
            ),
        )
        return VisionResult.model_validate(json.loads(resp.text))
    except Exception as exc:
        raise ProviderError(_PROVIDER_ERROR) from exc


def _gemini_generate(
    vision: VisionResult, chunks: list[dict], language: str
) -> GenerationResult:
    client = _gemini_client()
    try:
        resp = client.models.generate_content(
            model=_GEMINI_MODEL,
            contents=_generation_prompt(vision, chunks, language),
            config={"response_mime_type": "application/json"},
        )
        return GenerationResult.model_validate(json.loads(resp.text))
    except Exception as exc:
        raise ProviderError(_PROVIDER_ERROR) from exc


def _qwen_content(payload: dict) -> str:
    content = payload["choices"][0]["message"]["content"]
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            part.get("text", "") for part in content if isinstance(part, dict)
        )
    raise ValueError("missing model content")


def _qwen_chat(messages: list[dict]) -> dict:
    key = os.environ.get("DASHSCOPE_API_KEY")
    base_url = os.environ.get(
        "DASHSCOPE_BASE_URL",
        "https://cn-hongkong.dashscope.aliyuncs.com/compatible-mode/v1",
    ).rstrip("/")
    model = os.environ.get("QWEN_MODEL", "qwen3-vl-plus")
    if not key:
        raise ProviderError("未配置 Qwen 诊断服务")
    request = Request(
        f"{base_url}/chat/completions",
        data=json.dumps(
            {
                "model": model,
                "messages": messages,
                "temperature": 0.1,
                "max_tokens": 1800,
                "enable_thinking": False,
                "response_format": {"type": "json_object"},
            }
        ).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(request, timeout=150) as response:
            return json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, ValueError) as exc:
        raise ProviderError(_PROVIDER_ERROR) from exc


def _json_object(content: str) -> dict:
    text = content.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        text = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
    value = json.loads(text)
    if not isinstance(value, dict):
        raise ValueError("model response is not a JSON object")
    return value


def _qwen_extract(image_bytes: bytes, mime_type: str) -> VisionResult:
    encoded = base64.b64encode(image_bytes).decode("ascii")
    payload = _qwen_chat(
        [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": _VISION_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{mime_type};base64,{encoded}"
                        },
                    },
                ],
            }
        ]
    )
    try:
        return VisionResult.model_validate(
            _json_object(_qwen_content(payload))
        )
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise ProviderError(_PROVIDER_ERROR) from exc


def _qwen_generate(
    vision: VisionResult, chunks: list[dict], language: str
) -> GenerationResult:
    payload = _qwen_chat(
        [
            {
                "role": "user",
                "content": _generation_prompt(vision, chunks, language),
            }
        ]
    )
    try:
        return GenerationResult.model_validate(
            _json_object(_qwen_content(payload))
        )
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise ProviderError(_PROVIDER_ERROR) from exc


def extract(
    image_bytes: bytes,
    provider: str,
    mime_type: str = "image/jpeg",
) -> VisionResult:
    if provider == "qwen":
        return _qwen_extract(image_bytes, mime_type)
    if provider == "gemini":
        return _gemini_extract(image_bytes, mime_type)
    raise ProviderError("未配置真实 AI 诊断服务")


def generate(
    vision: VisionResult,
    chunks: list[dict],
    provider: str,
    language: str = "zh",
) -> GenerationResult:
    if not chunks:
        raise ProviderError("没有可用于生成维修建议的手册片段")
    if provider == "qwen":
        return _qwen_generate(vision, chunks, language)
    if provider == "gemini":
        return _gemini_generate(vision, chunks, language)
    raise ProviderError("未配置真实 AI 诊断服务")


def status() -> dict:
    return {
        "qwen": bool(os.environ.get("DASHSCOPE_API_KEY")),
        "gemini": bool(os.environ.get("GEMINI_API_KEY")),
        "selected": configured_provider() or "mock",
    }
