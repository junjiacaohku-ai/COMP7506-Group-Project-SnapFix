from __future__ import annotations

import hashlib
import os
import secrets
import sqlite3
import uuid
from datetime import timedelta

import jwt
from jwt import PyJWKClient

import auth

_GOOGLE_JWKS = "https://www.googleapis.com/oauth2/v3/certs"
_APPLE_JWKS = "https://appleid.apple.com/auth/keys"
_APPLE_ISSUER = "https://appleid.apple.com"
_APPLE_BUNDLE_ID = "hk.snapfix.snapfixSolo"
_google_jwk_client = PyJWKClient(_GOOGLE_JWKS)
_apple_jwk_client = PyJWKClient(_APPLE_JWKS)


class OAuthUnavailable(RuntimeError):
    pass


def _decode_token(
    token: str,
    client: PyJWKClient,
    audience: str,
    issuers: list[str],
) -> dict:
    signing_key = client.get_signing_key_from_jwt(token)
    return jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        audience=audience,
        issuer=issuers,
        leeway=60,
        options={"require": ["exp", "iat", "iss", "sub"]},
    )


def _display_name(name: str | None, email: str | None, provider: str) -> str:
    if name and name.strip():
        return auth.validate_name(name)
    if email:
        return auth.validate_name(email.split("@", 1)[0])
    return "Apple 用户" if provider == "apple" else "Google 用户"


def _find_or_create_user(
    conn: sqlite3.Connection,
    provider: str,
    subject: str,
    email: str | None,
    name: str | None,
    link_user_id: str | None = None,
) -> dict:
    if not subject:
        raise auth.AuthError("第三方账号缺少用户标识")
    row = conn.execute(
        "SELECT u.* FROM auth_identities i JOIN users u ON u.id=i.user_id "
        "WHERE i.provider=? AND i.provider_user_id=?",
        (provider, subject),
    ).fetchone()
    if row is not None:
        if link_user_id is not None and row["id"] != link_user_id:
            raise auth.AuthError("此第三方账号已绑定其他 SnapFix 账户")
        return auth.public_user(row)

    if link_user_id is not None:
        row = conn.execute(
            "SELECT * FROM users WHERE id=?", (link_user_id,)
        ).fetchone()
        if row is None:
            raise auth.AuthError("当前账户不存在")
        try:
            conn.execute(
                "INSERT INTO auth_identities "
                "(id,user_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    link_user_id,
                    provider,
                    subject,
                    auth._now().isoformat(),
                ),
            )
        except sqlite3.IntegrityError:
            raise auth.AuthError("当前账户已绑定此类型的登录方式")
        return auth.public_user(row)

    normalized_email = auth.normalize_email(email) if email else None
    if normalized_email:
        row = conn.execute(
            "SELECT * FROM users WHERE email=?", (normalized_email,)
        ).fetchone()
        if row is not None:
            user_id = row["id"]
            conn.execute(
                "INSERT INTO auth_identities "
                "(id,user_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)",
                (
                    str(uuid.uuid4()),
                    user_id,
                    provider,
                    subject,
                    auth._now().isoformat(),
                ),
            )
            return auth.public_user(row)

    user_id = str(uuid.uuid4())
    display_name = _display_name(name, normalized_email, provider)
    conn.execute(
        "INSERT INTO users (id,name,email,password_salt,password_hash,created_at) "
        "VALUES (?,?,?,?,?,?)",
        (
            user_id,
            display_name,
            normalized_email,
            None,
            None,
            auth._now().isoformat(),
        ),
    )
    conn.execute(
        "INSERT INTO auth_identities "
        "(id,user_id,provider,provider_user_id,created_at) VALUES (?,?,?,?,?)",
        (
            str(uuid.uuid4()),
            user_id,
            provider,
            subject,
            auth._now().isoformat(),
        ),
    )
    row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    return auth.public_user(row)


def google_login(
    conn: sqlite3.Connection, identity_token: str, link_user_id: str | None = None
) -> dict:
    client_id = (
        os.environ.get("GOOGLE_SERVER_CLIENT_ID", "").strip()
        or os.environ.get("GOOGLE_CLIENT_ID", "").strip()
    )
    if not client_id:
        raise OAuthUnavailable("Google 登录尚未配置 Client ID")
    try:
        claims = _decode_token(
            identity_token,
            _google_jwk_client,
            client_id,
            ["https://accounts.google.com", "accounts.google.com"],
        )
    except Exception:
        raise auth.AuthError("Google 令牌无效或已过期")
    email = claims.get("email") if claims.get("email_verified") is True else None
    return _find_or_create_user(
        conn,
        "google",
        claims["sub"],
        email,
        claims.get("name"),
        link_user_id,
    )


def create_apple_nonce(conn: sqlite3.Connection) -> str:
    nonce = secrets.token_urlsafe(32)
    now = auth._now()
    conn.execute("DELETE FROM oauth_challenges WHERE expires_at<=?", (now.isoformat(),))
    conn.execute(
        "INSERT INTO oauth_challenges (nonce_hash,provider,expires_at) VALUES (?,?,?)",
        (
            hashlib.sha256(nonce.encode()).hexdigest(),
            "apple",
            (now + timedelta(minutes=10)).isoformat(),
        ),
    )
    return nonce


def _consume_apple_nonce(conn: sqlite3.Connection, nonce: str) -> None:
    nonce_hash = hashlib.sha256(nonce.encode()).hexdigest()
    row = conn.execute(
        "SELECT * FROM oauth_challenges WHERE nonce_hash=? AND provider='apple' "
        "AND expires_at>?",
        (nonce_hash, auth._now().isoformat()),
    ).fetchone()
    if row is None:
        raise auth.AuthError("Apple 登录请求已过期，请重试")
    conn.execute("DELETE FROM oauth_challenges WHERE nonce_hash=?", (nonce_hash,))


def apple_login(
    conn: sqlite3.Connection,
    identity_token: str,
    nonce: str,
    name: str | None,
    link_user_id: str | None = None,
) -> dict:
    _consume_apple_nonce(conn, nonce)
    try:
        claims = _decode_token(
            identity_token,
            _apple_jwk_client,
            _APPLE_BUNDLE_ID,
            [_APPLE_ISSUER],
        )
        token_nonce = claims.get("nonce")
        if not isinstance(token_nonce, str) or not secrets.compare_digest(
            token_nonce, nonce
        ):
            raise auth.AuthError("Apple 登录校验失败，请重试")
    except auth.AuthError:
        raise
    except Exception:
        raise auth.AuthError("Apple 令牌无效或已过期")
    return _find_or_create_user(
        conn,
        "apple",
        claims["sub"],
        claims.get("email"),
        name,
        link_user_id,
    )
