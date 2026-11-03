from __future__ import annotations

import base64
import hashlib
import re
import secrets
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone

_PASSWORD_ITERATIONS = 600_000
_TOKEN_DAYS = 30
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class AuthError(ValueError):
    pass


def _now() -> datetime:
    return datetime.now(timezone.utc)


def normalize_email(email: str) -> str:
    email = email.strip().lower()
    if len(email) > 254 or not _EMAIL_RE.fullmatch(email):
        raise AuthError("请输入有效的邮箱地址")
    return email


def validate_name(name: str) -> str:
    name = name.strip()
    if not name or len(name) > 30:
        raise AuthError("昵称需为 1–30 个字符")
    return name


def _hash_password(password: str, salt: bytes) -> str:
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), salt, _PASSWORD_ITERATIONS
    )
    return base64.b64encode(digest).decode()


def _validate_password(password: str) -> None:
    if len(password) < 8:
        raise AuthError("密码至少需要 8 个字符")
    if len(password) > 128:
        raise AuthError("密码不能超过 128 个字符")


def public_user(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "email": row["email"],
        "created_at": row["created_at"],
    }


def create_user(
    conn: sqlite3.Connection, name: str, email: str, password: str
) -> dict:
    name = validate_name(name)
    email = normalize_email(email)
    _validate_password(password)
    salt = secrets.token_bytes(16)
    user = {
        "id": str(uuid.uuid4()),
        "name": name,
        "email": email,
        "password_salt": base64.b64encode(salt).decode(),
        "password_hash": _hash_password(password, salt),
        "created_at": _now().isoformat(),
    }
    try:
        conn.execute(
            "INSERT INTO users (id,name,email,password_salt,password_hash,created_at) "
            "VALUES (:id,:name,:email,:password_salt,:password_hash,:created_at)",
            user,
        )
    except sqlite3.IntegrityError:
        raise AuthError("该邮箱已注册，请直接登录")
    return {key: user[key] for key in ("id", "name", "email", "created_at")}


def authenticate(conn: sqlite3.Connection, email: str, password: str) -> dict:
    try:
        email = normalize_email(email)
    except AuthError:
        raise AuthError("邮箱或密码不正确")
    if len(password) > 128:
        raise AuthError("邮箱或密码不正确")
    row = conn.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()
    if row is None:
        raise AuthError("邮箱或密码不正确")
    salt = base64.b64decode(row["password_salt"])
    candidate = _hash_password(password, salt)
    if not secrets.compare_digest(candidate, row["password_hash"]):
        raise AuthError("邮箱或密码不正确")
    return public_user(row)


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def issue_token(conn: sqlite3.Connection, user_id: str) -> str:
    token = secrets.token_urlsafe(32)
    now = _now()
    conn.execute("DELETE FROM auth_tokens WHERE expires_at<=?", (now.isoformat(),))
    conn.execute(
        "INSERT INTO auth_tokens (token_hash,user_id,created_at,expires_at) "
        "VALUES (?,?,?,?)",
        (
            _token_hash(token),
            user_id,
            now.isoformat(),
            (now + timedelta(days=_TOKEN_DAYS)).isoformat(),
        ),
    )
    return token


def user_by_token(conn: sqlite3.Connection, token: str) -> dict | None:
    row = conn.execute(
        "SELECT u.* FROM auth_tokens t JOIN users u ON u.id=t.user_id "
        "WHERE t.token_hash=? AND t.expires_at>?",
        (_token_hash(token), _now().isoformat()),
    ).fetchone()
    return public_user(row) if row is not None else None


def revoke_token(conn: sqlite3.Connection, token: str) -> None:
    conn.execute("DELETE FROM auth_tokens WHERE token_hash=?", (_token_hash(token),))


def update_name(conn: sqlite3.Connection, user_id: str, name: str) -> dict:
    name = validate_name(name)
    conn.execute("UPDATE users SET name=? WHERE id=?", (name, user_id))
    row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    return public_user(row)
