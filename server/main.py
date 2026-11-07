"""SnapFix(solo 版)FastAPI 入口:API 层,薄壳,业务在 pipeline.py。"""
from __future__ import annotations

import os

from fastapi import Depends, FastAPI, Header, HTTPException, UploadFile
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

MOCK_MODE = not os.environ.get("GEMINI_API_KEY")


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
            "SELECT id,idx,content,citation_manual,citation_section,feedback "
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


class FeedbackRequest(BaseModel):
    feedback: str


class ReportRequest(BaseModel):
    lang: str = "zh"


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "mock": MOCK_MODE,
        "provider": "mock" if MOCK_MODE else "gemini",
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
async def analyze_image(file: UploadFile, user: dict = Depends(current_user)):
    image = await file.read()
    try:
        with db.connect() as conn:
            return pipeline.analyze_image(
                image, file.filename, MOCK_MODE, conn, user["id"]
            )
    except QualityError as e:
        raise HTTPException(status_code=422, detail=str(e))


@app.post("/api/diagnose/manual")
def diagnose_manual(
    req: ManualDiagnoseRequest, user: dict = Depends(current_user)
):
    with db.connect() as conn:
        return pipeline.diagnose_manual(
            req.brand, req.error_code, MOCK_MODE, conn, user["id"]
        )


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
    if req.feedback not in {"done", "not_useful", "skipped"}:
        raise HTTPException(status_code=400, detail="invalid feedback")
    with db.connect() as conn:
        _get(session_id, conn, user["id"])
        cur = conn.execute(
            "UPDATE steps SET feedback=? WHERE id=? AND session_id=?",
            (req.feedback, step_id, session_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="step not found")
        return _get(session_id, conn, user["id"])


@app.post("/api/sessions/{session_id}/report")
def generate_report(
    session_id: str, req: ReportRequest, user: dict = Depends(current_user)
):
    if req.lang not in {"zh", "en"}:
        raise HTTPException(status_code=400, detail="invalid language")
    with db.connect() as conn:
        s = _get(session_id, conn, user["id"])
    device = {
        "washing_machine": "洗衣机",
        "router": "路由器",
        "microwave": "微波炉",
        "ikea_furniture": "IKEA 家具",
        "water_heater": "热水器",
    }.get(s["device_category"], s["device_category"])
    brand = s["brand"]
    code = s["error_code"]
    if req.lang == "en":
        tried = ", ".join(
            f"step {st['idx']}" for st in s["steps"] if st["feedback"] == "done"
        ) or "none"
        brand_part = f" ({brand})" if brand else ""
        code_part = f", error code {code}" if code else ""
        content = (
            f"Repair request: {s['device_category']}{brand_part}{code_part}. "
            f"Steps already tried: {tried}. Photos attached. Please advise."
        )
    else:
        tried = "、".join(
            f"步骤{st['idx']}" for st in s["steps"] if st["feedback"] == "done"
        ) or "无"
        brand_part = f"({brand})" if brand else ""
        code_part = f",错误码 {code}" if code else ""
        content = (
            f"报修申请:{device}{brand_part}{code_part}。"
            f"已尝试步骤:{tried}。照片见附件,烦请安排处理,谢谢。"
        )
    return {"lang": req.lang, "content": content}


@app.get("/api/manuals")
def manuals():
    return retrieval.all_manuals()
