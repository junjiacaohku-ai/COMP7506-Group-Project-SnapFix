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
_PREFERENCE_VALUES = {
    "language": {"en", "zh"},
    "appearance": {"system", "light", "dark"},
    "reduce_motion": {"true", "false"},
    "accent": {"purple", "teal", "blue", "amber"},
    "text_scale": {"small", "default", "large"},
    "notifications": {"true", "false"},
}


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
        "has_password": row["password_hash"] is not None,
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
    return public_user(user)


def authenticate(conn: sqlite3.Connection, email: str, password: str) -> dict:
    try:
        email = normalize_email(email)
    except AuthError:
        raise AuthError("邮箱或密码不正确")
    if len(password) > 128:
        raise AuthError("邮箱或密码不正确")
    row = conn.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()
    if row is None or row["password_hash"] is None:
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


def revoke_other_tokens(conn: sqlite3.Connection, user_id: str, token: str) -> int:
    cur = conn.execute(
        "DELETE FROM auth_tokens WHERE user_id=? AND token_hash<>?",
        (user_id, _token_hash(token)),
    )
    return cur.rowcount


def update_name(conn: sqlite3.Connection, user_id: str, name: str) -> dict:
    name = validate_name(name)
    conn.execute("UPDATE users SET name=? WHERE id=?", (name, user_id))
    row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    return public_user(row)


def list_identities(conn: sqlite3.Connection, user_id: str) -> list[dict]:
    rows = conn.execute(
        "SELECT provider,created_at FROM auth_identities WHERE user_id=? "
        "ORDER BY created_at",
        (user_id,),
    ).fetchall()
    return [dict(row) for row in rows]


def unlink_identity(conn: sqlite3.Connection, user_id: str, provider: str) -> None:
    if provider not in {"google", "apple"}:
        raise AuthError("不支持解绑此登录方式")
    row = conn.execute(
        "SELECT password_hash FROM users WHERE id=?", (user_id,)
    ).fetchone()
    count = conn.execute(
        "SELECT COUNT(*) AS count FROM auth_identities WHERE user_id=?", (user_id,)
    ).fetchone()["count"]
    if row["password_hash"] is None and count <= 1:
        raise AuthError("请先设置邮箱密码，再解绑最后的登录方式")
    cur = conn.execute(
        "DELETE FROM auth_identities WHERE user_id=? AND provider=?",
        (user_id, provider),
    )
    if cur.rowcount == 0:
        raise AuthError("此登录方式尚未绑定")


def change_password(
    conn: sqlite3.Connection,
    user_id: str,
    current_password: str | None,
    new_password: str,
) -> None:
    _validate_password(new_password)
    row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    if row["password_hash"] is not None:
        if not current_password:
            raise AuthError("请输入当前密码")
        salt = base64.b64decode(row["password_salt"])
        candidate = _hash_password(current_password, salt)
        if not secrets.compare_digest(candidate, row["password_hash"]):
            raise AuthError("当前密码不正确")
    salt = secrets.token_bytes(16)
    conn.execute(
        "UPDATE users SET password_salt=?,password_hash=? WHERE id=?",
        (
            base64.b64encode(salt).decode(),
            _hash_password(new_password, salt),
            user_id,
        ),
    )


def delete_user(conn: sqlite3.Connection, user_id: str) -> None:
    conn.execute("DELETE FROM users WHERE id=?", (user_id,))


def get_preferences(conn: sqlite3.Connection, user_id: str) -> dict[str, str]:
    rows = conn.execute(
        "SELECT key,value FROM user_preferences WHERE user_id=?", (user_id,)
    ).fetchall()
    return {row["key"]: row["value"] for row in rows}


def update_preferences(
    conn: sqlite3.Connection, user_id: str, values: dict[str, str]
) -> dict[str, str]:
    for key, value in values.items():
        if key not in _PREFERENCE_VALUES or value not in _PREFERENCE_VALUES[key]:
            raise AuthError("偏好设置格式不正确")
    now = _now().isoformat()
    for key, value in values.items():
        conn.execute(
            "INSERT INTO user_preferences (user_id,key,value,updated_at) "
            "VALUES (?,?,?,?) ON CONFLICT(user_id,key) DO UPDATE SET "
            "value=excluded.value,updated_at=excluded.updated_at",
            (user_id, key, value, now),
        )
    return get_preferences(conn, user_id)
