"""SnapFix(solo 版)FastAPI 入口:API 层,薄壳,业务在 pipeline.py。

契约与团队版 docs/api-contract.md 一致,外加 GET /api/manuals(语料自查)。
"""
from __future__ import annotations

import os

from fastapi import FastAPI, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import db
import pipeline
import providers
import retrieval
from pipeline import QualityError

app = FastAPI(title="SnapFix Solo API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"],
                   allow_headers=["*"])

db.init()

MOCK_MODE = not os.environ.get("GEMINI_API_KEY")


def _row_to_session(row, conn) -> dict:
    s = dict(row)
    s["safety_refused"] = bool(s["safety_refused"])
    s["steps"] = [dict(r) for r in conn.execute(
        "SELECT id,idx,content,citation_manual,citation_section,feedback "
        "FROM steps WHERE session_id=? ORDER BY idx", (s["id"],))]
    return s


class ManualDiagnoseRequest(BaseModel):
    brand: str
    error_code: str


class FeedbackRequest(BaseModel):
    feedback: str  # done / not_useful / skipped


class ReportRequest(BaseModel):
    lang: str = "zh"  # zh / en


@app.get("/api/health")
def health():
    return {"status": "ok", "mock": MOCK_MODE,
            "provider": "mock" if MOCK_MODE else "gemini",
            "providers": providers.status()}


@app.post("/api/analyze/image")
async def analyze_image(file: UploadFile):
    image = await file.read()  # 隐私:照片处理后即删,不落盘
    try:
        with db.connect() as conn:
            return pipeline.analyze_image(image, file.filename, MOCK_MODE, conn)
    except QualityError as e:
        raise HTTPException(status_code=422, detail=str(e))


@app.post("/api/diagnose/manual")
def diagnose_manual(req: ManualDiagnoseRequest):
    with db.connect() as conn:
        return pipeline.diagnose_manual(req.brand, req.error_code, MOCK_MODE, conn)


@app.get("/api/sessions")
def list_sessions():
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT * FROM sessions ORDER BY created_at DESC").fetchall()
        return [_row_to_session(r, conn) for r in rows]


def _get(session_id: str, conn) -> dict:
    row = conn.execute("SELECT * FROM sessions WHERE id=?", (session_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="session not found")
    return _row_to_session(row, conn)


@app.get("/api/sessions/{session_id}")
def get_session(session_id: str):
    with db.connect() as conn:
        return _get(session_id, conn)


@app.delete("/api/sessions/{session_id}")
def delete_session(session_id: str):
    with db.connect() as conn:
        _get(session_id, conn)
        conn.execute("DELETE FROM steps WHERE session_id=?", (session_id,))
        conn.execute("DELETE FROM sessions WHERE id=?", (session_id,))
        return {"deleted": True}


@app.post("/api/sessions/{session_id}/steps/{step_id}/feedback")
def step_feedback(session_id: str, step_id: str, req: FeedbackRequest):
    with db.connect() as conn:
        cur = conn.execute(
            "UPDATE steps SET feedback=? WHERE id=? AND session_id=?",
            (req.feedback, step_id, session_id))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="step not found")
        return _get(session_id, conn)


@app.post("/api/sessions/{session_id}/report")
def generate_report(session_id: str, req: ReportRequest):
    with db.connect() as conn:
        s = _get(session_id, conn)
    device = {"washing_machine": "洗衣机", "router": "路由器", "microwave": "微波炉",
              "ikea_furniture": "IKEA 家具", "water_heater": "热水器"}.get(
        s["device_category"], s["device_category"])
    brand = s["brand"]
    code = s["error_code"]
    if req.lang == "en":
        tried = ", ".join(f"step {st['idx']}" for st in s["steps"]
                          if st["feedback"] == "done") or "none"
        brand_part = f" ({brand})" if brand else ""
        code_part = f", error code {code}" if code else ""
        content = (f"Repair request: {s['device_category']}{brand_part}{code_part}. "
                   f"Steps already tried: {tried}. Photos attached. Please advise.")
    else:
        tried = "、".join(f"步骤{st['idx']}" for st in s["steps"]
                          if st["feedback"] == "done") or "无"
        brand_part = f"({brand})" if brand else ""
        code_part = f",错误码 {code}" if code else ""
        content = (f"报修申请:{device}{brand_part}{code_part}。"
                   f"已尝试步骤:{tried}。照片见附件,烦请安排处理,谢谢。")
    return {"lang": req.lang, "content": content}


@app.get("/api/manuals")
def manuals():
    return retrieval.all_manuals()
