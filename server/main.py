"""SnapFix(solo 版)FastAPI 入口:API 层,薄壳,业务在 pipeline.py。"""
from __future__ import annotations

from fastapi import Depends, FastAPI, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import auth
import db
import oauth
import pipeline
import providers
import retrieval
from pipeline import QualityError

app = FastAPI(title="SnapFix Solo API", version="1.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

db.init()

PROVIDER = providers.configured_provider()
MOCK_MODE = PROVIDER is None


def _bearer_token(authorization: str) -> str:
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(
            status_code=401,
            detail="请先登录",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token.strip()


def current_user(authorization: str = Header(default="")) -> dict:
    token = _bearer_token(authorization)
    with db.connect() as conn:
        user = auth.user_by_token(conn, token)
    if user is None:
        raise HTTPException(
            status_code=401,
            detail="登录已过期，请重新登录",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def _row_to_session(row, conn) -> dict:
    s = dict(row)
    s.pop("user_id", None)
    s["safety_refused"] = bool(s["safety_refused"])
    s["steps"] = [
        dict(r)
        for r in conn.execute(
            "SELECT id,idx,content,citation_manual,citation_section,"
            "citation_chunk_id,citation_text,feedback "
            "FROM steps WHERE session_id=? ORDER BY idx",
            (s["id"],),
        )
    ]
    return s


class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


class GoogleAuthRequest(BaseModel):
    identity_token: str


class AppleAuthRequest(BaseModel):
    identity_token: str
    nonce: str
    name: str | None = None


class NameRequest(BaseModel):
    name: str


class PasswordChangeRequest(BaseModel):
    current_password: str | None = None
    new_password: str


class PreferencesRequest(BaseModel):
    values: dict[str, str]


class DeleteAccountRequest(BaseModel):
    confirmation: str


class ManualDiagnoseRequest(BaseModel):
    brand: str
    error_code: str
    language: str = "zh"


class FeedbackRequest(BaseModel):
    feedback: str


class ReportRequest(BaseModel):
    lang: str = "zh"


class StatusRequest(BaseModel):
    status: str


class ReportDraftRequest(BaseModel):
    lang: str = "zh"
    content: str


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "mock": MOCK_MODE,
        "provider": PROVIDER or "mock",
        "providers": providers.status(),
    }


@app.post("/api/auth/register", status_code=201)
def register(req: RegisterRequest):
    try:
        with db.connect() as conn:
            user = auth.create_user(conn, req.name, req.email, req.password)
            token = auth.issue_token(conn, user["id"])
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"token": token, "user": user}


@app.post("/api/auth/login")
def login(req: LoginRequest):
    try:
        with db.connect() as conn:
            user = auth.authenticate(conn, req.email, req.password)
            token = auth.issue_token(conn, user["id"])
    except auth.AuthError as e:
        raise HTTPException(status_code=401, detail=str(e))
    return {"token": token, "user": user}


@app.post("/api/auth/google")
def google_oauth(req: GoogleAuthRequest):
    try:
        with db.connect() as conn:
            user = oauth.google_login(conn, req.identity_token)
            token = auth.issue_token(conn, user["id"])
    except oauth.OAuthUnavailable as e:
        raise HTTPException(status_code=503, detail=str(e))
    except auth.AuthError as e:
        raise HTTPException(status_code=401, detail=str(e))
    return {"token": token, "user": user}


@app.post("/api/auth/apple/nonce")
def apple_nonce():
    with db.connect() as conn:
        nonce = oauth.create_apple_nonce(conn)
    return {"nonce": nonce}


@app.post("/api/auth/apple")
def apple_oauth(req: AppleAuthRequest):
    try:
        with db.connect() as conn:
            user = oauth.apple_login(
                conn, req.identity_token, req.nonce, req.name
            )
            token = auth.issue_token(conn, user["id"])
    except auth.AuthError as e:
        raise HTTPException(status_code=401, detail=str(e))
    return {"token": token, "user": user}


@app.get("/api/auth/me")
def me(user: dict = Depends(current_user)):
    return {"user": user}


@app.patch("/api/auth/me")
def update_me(req: NameRequest, user: dict = Depends(current_user)):
    try:
        with db.connect() as conn:
            updated = auth.update_name(conn, user["id"], req.name)
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"user": updated}


@app.post("/api/auth/logout")
def logout(
    user: dict = Depends(current_user),
    authorization: str = Header(default=""),
):
    with db.connect() as conn:
        auth.revoke_token(conn, _bearer_token(authorization))
    return {"logged_out": True}


@app.get("/api/auth/identities")
def identities(user: dict = Depends(current_user)):
    with db.connect() as conn:
        return {"identities": auth.list_identities(conn, user["id"])}


@app.post("/api/auth/google/link")
def link_google(req: GoogleAuthRequest, user: dict = Depends(current_user)):
    try:
        with db.connect() as conn:
            linked = oauth.google_login(conn, req.identity_token, user["id"])
    except oauth.OAuthUnavailable as e:
        raise HTTPException(status_code=503, detail=str(e))
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"user": linked}


@app.post("/api/auth/apple/link")
def link_apple(req: AppleAuthRequest, user: dict = Depends(current_user)):
    try:
        with db.connect() as conn:
            linked = oauth.apple_login(
                conn, req.identity_token, req.nonce, req.name, user["id"]
            )
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"user": linked}


@app.delete("/api/auth/identities/{provider}")
def unlink_identity(provider: str, user: dict = Depends(current_user)):
    try:
        with db.connect() as conn:
            auth.unlink_identity(conn, user["id"], provider)
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"unlinked": True}


@app.post("/api/auth/password")
def change_password(
    req: PasswordChangeRequest,
    user: dict = Depends(current_user),
    authorization: str = Header(default=""),
):
    try:
        with db.connect() as conn:
            auth.change_password(
                conn, user["id"], req.current_password, req.new_password
            )
            revoked = auth.revoke_other_tokens(
                conn, user["id"], _bearer_token(authorization)
            )
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"changed": True, "revoked_devices": revoked}


@app.delete("/api/auth/me")
def delete_account(
    req: DeleteAccountRequest, user: dict = Depends(current_user)
):
    if req.confirmation != "DELETE":
        raise HTTPException(status_code=400, detail="请输入 DELETE 以确认删除账号")
    with db.connect() as conn:
        auth.delete_user(conn, user["id"])
    return {"deleted": True}


@app.get("/api/preferences")
def preferences(user: dict = Depends(current_user)):
    with db.connect() as conn:
        return {"values": auth.get_preferences(conn, user["id"])}


@app.put("/api/preferences")
def update_preferences(
    req: PreferencesRequest, user: dict = Depends(current_user)
):
    try:
        with db.connect() as conn:
            values = auth.update_preferences(conn, user["id"], req.values)
    except auth.AuthError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"values": values}


@app.post("/api/analyze/image")
async def analyze_image(
    file: UploadFile,
    language: str = Form(default="zh"),
    user: dict = Depends(current_user),
):
    image = await file.read()
    try:
        with db.connect() as conn:
            return pipeline.analyze_image(
                image, file.filename, PROVIDER, conn, user["id"], language
            )
    except QualityError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except pipeline.AnalysisError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))


@app.post("/api/diagnose/manual")
def diagnose_manual(
    req: ManualDiagnoseRequest, user: dict = Depends(current_user)
):
    try:
        with db.connect() as conn:
            return pipeline.diagnose_manual(
                req.brand,
                req.error_code,
                PROVIDER,
                conn,
                user["id"],
                req.language,
            )
    except pipeline.AnalysisError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))


@app.get("/api/sessions")
def list_sessions(user: dict = Depends(current_user)):
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT * FROM sessions WHERE user_id=? ORDER BY created_at DESC",
            (user["id"],),
        ).fetchall()
        return [_row_to_session(r, conn) for r in rows]


def _get(session_id: str, conn, user_id: str) -> dict:
    row = conn.execute(
        "SELECT * FROM sessions WHERE id=? AND user_id=?", (session_id, user_id)
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="session not found")
    return _row_to_session(row, conn)


@app.get("/api/sessions/{session_id}")
def get_session(session_id: str, user: dict = Depends(current_user)):
    with db.connect() as conn:
        return _get(session_id, conn, user["id"])


@app.delete("/api/sessions/{session_id}")
def delete_session(session_id: str, user: dict = Depends(current_user)):
    with db.connect() as conn:
        _get(session_id, conn, user["id"])
        conn.execute("DELETE FROM steps WHERE session_id=?", (session_id,))
        conn.execute("DELETE FROM sessions WHERE id=?", (session_id,))
        return {"deleted": True}


@app.post("/api/sessions/{session_id}/steps/{step_id}/feedback")
def step_feedback(
    session_id: str,
    step_id: str,
    req: FeedbackRequest,
    user: dict = Depends(current_user),
):
    if req.feedback not in {"done", "not_useful", "skipped", ""}:
        raise HTTPException(status_code=400, detail="invalid feedback")
    with db.connect() as conn:
        _get(session_id, conn, user["id"])
        cur = conn.execute(
            "UPDATE steps SET feedback=? WHERE id=? AND session_id=?",
            (req.feedback or None, step_id, session_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="step not found")
        return _get(session_id, conn, user["id"])


@app.post("/api/sessions/{session_id}/status")
def update_status(
    session_id: str, req: StatusRequest, user: dict = Depends(current_user)
):
    if req.status not in {"investigating", "awaiting_repair", "resolved"}:
        raise HTTPException(status_code=400, detail="invalid status")
    with db.connect() as conn:
        _get(session_id, conn, user["id"])
        conn.execute(
            "UPDATE sessions SET status=? WHERE id=?", (req.status, session_id)
        )
        return _get(session_id, conn, user["id"])


@app.put("/api/sessions/{session_id}/report")
def save_report_draft(
    session_id: str, req: ReportDraftRequest, user: dict = Depends(current_user)
):
    content = req.content.strip()
    if req.lang not in {"zh", "en"}:
        raise HTTPException(status_code=400, detail="invalid language")
    if not content or len(content) > 20000:
        raise HTTPException(status_code=400, detail="invalid report content")
    from datetime import datetime, timezone

    with db.connect() as conn:
        _get(session_id, conn, user["id"])
        conn.execute(
            "INSERT INTO report_drafts (session_id,lang,content,updated_at) "
            "VALUES (?,?,?,?) ON CONFLICT(session_id,lang) DO UPDATE SET "
            "content=excluded.content,updated_at=excluded.updated_at",
            (
                session_id,
                req.lang,
                content,
                datetime.now(timezone.utc).isoformat(),
            ),
        )
    return {"lang": req.lang, "content": content}


@app.post("/api/sessions/{session_id}/report")
def generate_report(
    session_id: str,
    req: ReportRequest,
    user: dict = Depends(current_user),
    reset: bool = False,
):
    if req.lang not in {"zh", "en"}:
        raise HTTPException(status_code=400, detail="invalid language")
    with db.connect() as conn:
        s = _get(session_id, conn, user["id"])
        if reset:
            conn.execute(
                "DELETE FROM report_drafts WHERE session_id=? AND lang=?",
                (session_id, req.lang),
            )
        else:
            draft = conn.execute(
                "SELECT content FROM report_drafts WHERE session_id=? AND lang=?",
                (session_id, req.lang),
            ).fetchone()
            if draft:
                return {"lang": req.lang, "content": draft["content"]}
    devices = {
        "washing_machine": ("洗衣机", "Washing machine"),
        "dishwasher": ("洗碗机", "Dishwasher"),
        "router": ("路由器", "Router"),
        "microwave": ("微波炉", "Microwave"),
        "ikea_furniture": ("IKEA 家具", "IKEA furniture"),
        "furniture": ("家具", "Furniture"),
        "water_heater": ("热水器", "Water heater"),
        "electric_water_heater": ("电热水器", "Electric water heater"),
        "gas_water_heater": ("燃气热水器", "Gas water heater"),
        "unknown": ("设备", "Appliance"),
    }
    device = devices.get(
        s["device_category"], (s["device_category"], s["device_category"])
    )[0 if req.lang == "zh" else 1]
    brand = s["brand"]
    model = s["model"]
    code = s["error_code"]
    high_risk = s["safety_refused"] or s["decision"] == "professional"
    reason_en = {
        "Internet 红灯多为接线或拨号问题,非破坏性排查,约 10 分钟。": "WAN cabling or dial-up issue; unconfirmed.",
        "排水泵滤网堵塞,非破坏性操作,工具只需一枚硬币,约 15 分钟。": "Drain pump filter blockage; unconfirmed.",
        "板式家具组装,工具只需螺丝刀与锤子,约 40 分钟,两人更佳。": "Flat-pack furniture assembly assistance requested.",
        "微波炉内部高压电容断电后仍可致命,属于高危类目,不提供任何拆解步骤。": "High-risk microwave fault; no DIY diagnosis provided.",
        "热水器属房东配置,内部维修责任在房东;可先自行尝试复位键。": "Possible water heater fault requiring landlord inspection.",
    }.get(s["decision_reason"])
    reason_text = s["decision_reason"] or ""
    if (
        reason_en is None
        and reason_text
        and s["diagnosis_source"] != "mock"
        and not any("\u4e00" <= char <= "\u9fff" for char in reason_text)
    ):
        reason_en = reason_text
    if req.lang == "en":
        tried = ", ".join(
            f"step {st['idx']}" for st in s["steps"] if st["feedback"] == "done"
        ) or "none"
        lines = ["Repair request", f"Device: {device}"]
        if brand:
            lines.append(f"Brand: {brand}")
        if model:
            lines.append(f"Model: {model}")
        lines.append(
            f"Observed issue: Error code {code} reported by the user."
            if code else "Observed issue: Appliance fault reported by the user."
        )
        if reason_en:
            lines.append(f"Possible cause: {reason_en}")
        lines.append(f"Steps already tried: {tried}.")
        if high_risk:
            lines.append(
                "Safety note: High-risk appliance. Do not disassemble; "
                "internal components may remain dangerous after power is disconnected."
            )
        lines.append(
            "Please attach photos of the fault when sending this request. Please advise."
        )
        content = "\n".join(lines)
    else:
        tried = "、".join(
            f"步骤{st['idx']}" for st in s["steps"] if st["feedback"] == "done"
        ) or "无"
        lines = ["报修申请", f"设备:{device}"]
        if brand:
            lines.append(f"品牌:{brand}")
        if model:
            lines.append(f"型号:{model}")
        lines.append(f"故障现象:用户报告错误码 {code}。" if code else "故障现象:用户报告设备故障。")
        if s["decision_reason"]:
            lines.append(f"可能原因(未经确认):{s['decision_reason']}")
        lines.append(f"已尝试步骤:{tried}。")
        if high_risk:
            lines.append("安全注意:高风险设备,请勿自行拆解;断电后内部元件仍可能存在危险。")
        lines.append("发送时请另附故障照片,烦请安排处理,谢谢。")
        content = "\n".join(lines)
    return {"lang": req.lang, "content": content}


@app.get("/api/manuals")
def manuals():
    return retrieval.all_manuals()
