"""SQLite 持久化:账号、访问令牌与个人诊断档案。

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
    email TEXT NOT NULL UNIQUE,
    password_salt TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL
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


def init() -> None:
    with connect() as conn:
        conn.executescript(_SCHEMA)
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
        """)
