"""SQLite 持久化:sessions / steps 两张表(PRD §9 的 MVP 子集)。

stdlib sqlite3,零额外依赖;数据库文件为 server/snapfix.db(已 gitignore)。
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent / "snapfix.db"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    device_category TEXT,
    brand TEXT, model TEXT, error_code TEXT,
    decision TEXT, decision_reason TEXT,
    safety_refused INTEGER DEFAULT 0,
    created_at TEXT
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
