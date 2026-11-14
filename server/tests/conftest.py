import os
from pathlib import Path
from tempfile import TemporaryDirectory

import pytest

_TEMP = TemporaryDirectory(prefix='snapfix-team-tests-')
_PREVIOUS_DB = os.environ.get('SNAPFIX_DB')
os.environ['SNAPFIX_DB'] = str(Path(_TEMP.name) / 'test.db')

import auth
import db
import main


db.init()


@pytest.fixture(autouse=True)
def mock_provider(monkeypatch):
    monkeypatch.setattr(main, 'PROVIDER', None)
    monkeypatch.setattr(main, 'MOCK_MODE', True)


@pytest.fixture
def client():
    from fastapi.testclient import TestClient

    with TestClient(main.app) as test_client:
        yield test_client


@pytest.fixture
def user():
    import time

    with db.connect() as conn:
        created = auth.create_user(
            conn,
            'Test User',
            f'test-{time.time_ns()}@example.com',
            'test-password-2026',
        )
        token = auth.issue_token(conn, created['id'])
        user_id = created['id']
    try:
        yield created, token
    finally:
        with db.connect() as conn:
            conn.execute('DELETE FROM users WHERE id=?', (user_id,))


@pytest.fixture
def auth_headers(user):
    return {'Authorization': f'Bearer {user[1]}'}


def pytest_sessionfinish(session, exitstatus):
    if _PREVIOUS_DB is None:
        os.environ.pop('SNAPFIX_DB', None)
    else:
        os.environ['SNAPFIX_DB'] = _PREVIOUS_DB
    _TEMP.cleanup()
