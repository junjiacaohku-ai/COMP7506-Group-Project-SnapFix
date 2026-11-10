"""SQLite 持久化：账号、诊断档案、真实语料与报修草稿。"""
from __future__ import annotations

import os
import sqlite3
from pathlib import Path

DB_PATH = Path(
    os.environ.get("SNAPFIX_DB", str(Path(__file__).parent / "snapfix.db"))
)
DATA_PATH = Path(__file__).parent / "data"

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
    expires_at TEXT NOT NULL,
    device_name TEXT,
    last_used_at TEXT
);
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, key)
);
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    device_category TEXT,
    brand TEXT, model TEXT, error_code TEXT,
    decision TEXT, decision_reason TEXT,
    safety_refused INTEGER DEFAULT 0,
    diagnosis_source TEXT NOT NULL DEFAULT 'mock',
    confidence REAL,
    status TEXT NOT NULL DEFAULT 'investigating',
    created_at TEXT,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS steps (
    id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    idx INTEGER, content TEXT,
    citation_manual TEXT, citation_section TEXT,
    citation_chunk_id TEXT, citation_text TEXT,
    feedback TEXT
);
CREATE TABLE IF NOT EXISTS report_drafts (
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    lang TEXT NOT NULL,
    content TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (session_id, lang)
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
    from corpus_store import import_corpus

    with connect() as conn:
        conn.executescript(_SCHEMA)
        _migrate_users_for_oauth(conn)
        session_columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(sessions)")
        }
        if "user_id" not in session_columns:
            conn.execute(
                "ALTER TABLE sessions ADD COLUMN user_id TEXT "
                "REFERENCES users(id) ON DELETE CASCADE"
            )
        if "diagnosis_source" not in session_columns:
            conn.execute(
                "ALTER TABLE sessions ADD COLUMN diagnosis_source TEXT "
                "NOT NULL DEFAULT 'mock'"
            )
        if "confidence" not in session_columns:
            conn.execute("ALTER TABLE sessions ADD COLUMN confidence REAL")
        if "status" not in session_columns:
            conn.execute(
                "ALTER TABLE sessions ADD COLUMN status TEXT "
                "NOT NULL DEFAULT 'investigating'"
            )
        step_columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(steps)")
        }
        if "citation_chunk_id" not in step_columns:
            conn.execute("ALTER TABLE steps ADD COLUMN citation_chunk_id TEXT")
        if "citation_text" not in step_columns:
            conn.execute("ALTER TABLE steps ADD COLUMN citation_text TEXT")
        token_columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(auth_tokens)")
        }
        if "device_name" not in token_columns:
            conn.execute("ALTER TABLE auth_tokens ADD COLUMN device_name TEXT")
        if "last_used_at" not in token_columns:
            conn.execute("ALTER TABLE auth_tokens ADD COLUMN last_used_at TEXT")
        conn.executescript("""
            CREATE INDEX IF NOT EXISTS idx_auth_tokens_user
                ON auth_tokens(user_id);
            CREATE INDEX IF NOT EXISTS idx_sessions_user_created
                ON sessions(user_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_identities_user
                ON auth_identities(user_id);
        """)
    import_corpus(DB_PATH, DATA_PATH)
