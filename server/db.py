"""SQLite 持久化:账号、第三方身份、访问令牌与个人诊断档案。

stdlib sqlite3,零额外依赖;数据库文件为 server/snapfix.db(已 gitignore)。
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent / "snapfix.db"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    password_salt TEXT,
    password_hash TEXT,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS auth_identities (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_user_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE(provider, provider_user_id),
    UNIQUE(user_id, provider)
);
CREATE TABLE IF NOT EXISTS oauth_challenges (
    nonce_hash TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS auth_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    device_category TEXT,
    brand TEXT, model TEXT, error_code TEXT,
    decision TEXT, decision_reason TEXT,
    safety_refused INTEGER DEFAULT 0,
    created_at TEXT,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS steps (
    id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    idx INTEGER, content TEXT,
    citation_manual TEXT, citation_section TEXT,
    feedback TEXT
);
"""


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def _migrate_users_for_oauth(conn: sqlite3.Connection) -> None:
    row = conn.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='users'"
    ).fetchone()
    if row is None or "email TEXT NOT NULL" not in row["sql"]:
        return
    conn.execute("PRAGMA foreign_keys=OFF")
    conn.executescript("""
        CREATE TABLE users_oauth (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT UNIQUE,
            password_salt TEXT,
            password_hash TEXT,
            created_at TEXT NOT NULL
        );
        INSERT INTO users_oauth
            SELECT id,name,email,password_salt,password_hash,created_at FROM users;
        DROP TABLE users;
        ALTER TABLE users_oauth RENAME TO users;
    """)
    conn.execute("PRAGMA foreign_keys=ON")
    issues = conn.execute("PRAGMA foreign_key_check").fetchall()
    if issues:
        raise RuntimeError("用户表迁移后外键校验失败")


def init() -> None:
    with connect() as conn:
        conn.executescript(_SCHEMA)
        _migrate_users_for_oauth(conn)
        columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(sessions)")
        }
        if "user_id" not in columns:
            conn.execute(
                "ALTER TABLE sessions ADD COLUMN user_id TEXT "
                "REFERENCES users(id) ON DELETE CASCADE"
            )
        conn.executescript("""
            CREATE INDEX IF NOT EXISTS idx_auth_tokens_user
                ON auth_tokens(user_id);
            CREATE INDEX IF NOT EXISTS idx_sessions_user_created
                ON sessions(user_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_identities_user
                ON auth_identities(user_id);
        """)
