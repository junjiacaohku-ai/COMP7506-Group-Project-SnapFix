"""手册检索:轻量 BM25 变体,单机语料规模下足够。

错误码精确命中给大额加权;中英文按字符/词混合切分(语料以中文为主)。
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

_CORPUS_PATH = Path(__file__).parent / "corpus" / "manuals.json"

_chunks: list[dict] | None = None


def _load() -> list[dict]:
    global _chunks
    if _chunks is None:
        data = json.loads(_CORPUS_PATH.read_text(encoding="utf-8"))
        _chunks = [
            {
                "manual": m["title"],
                "brand": m.get("brand"),
                "category": m["category"],
                "section": c["section"],
                "text": c["text"],
            }
            for m in data["manuals"]
            for c in m["chunks"]
        ]
    return _chunks


def _tokenize(text: str) -> list[str]:
    text = text.lower()
    latin = re.findall(r"[a-z0-9]+", text)
    cjk = re.findall(r"[一-鿿]", text)
    bigrams = [a + b for a, b in zip(cjk, cjk[1:])]
    return latin + cjk + bigrams


def search(query: str, category: str | None = None, error_code: str | None = None,
           top_k: int = 4) -> list[dict]:
    """按相关性返回手册片段;类别匹配优先,错误码精确命中大加权。"""
    chunks = _load()
    if category:
        preferred = [c for c in chunks if c["category"] == category]
        pool = preferred or chunks
    else:
        pool = chunks

    q_tokens = _tokenize(query)
    code = (error_code or "").strip().lower()

    scored = []
    for c in pool:
        tokens = _tokenize(c["text"] + " " + c["section"])
        tf: dict[str, int] = {}
        for t in tokens:
            tf[t] = tf.get(t, 0) + 1
        score = sum(math.log(1 + tf.get(t, 0)) for t in set(q_tokens))
        if code and code in (c["text"] + c["section"]).lower():
            score += 10.0
        scored.append((score, c))

    scored.sort(key=lambda x: x[0], reverse=True)
    return [c for s, c in scored[:top_k] if s > 0]


def all_manuals() -> list[dict]:
    seen: dict[str, dict] = {}
    for c in _load():
        seen.setdefault(c["manual"], {"title": c["manual"], "category": c["category"],
                                      "brand": c.get("brand")})
    return list(seen.values())
