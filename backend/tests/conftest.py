import os
from datetime import date

import pytest

os.environ.setdefault("SAATH_DB_URL", "sqlite://")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.clock import get_today  # noqa: E402
from app.db import Base, get_db  # noqa: E402
from app.main import create_app  # noqa: E402


class Clock:
    def __init__(self):
        self.today = date(2026, 10, 19)


@pytest.fixture
def clock():
    return Clock()


@pytest.fixture
def client(clock):
    # Fresh in-memory DB per test so tests can't leak into each other
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def _db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app = create_app()
    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_today] = lambda: clock.today
    with TestClient(app) as c:
        yield c


def signup(client, name):
    r = client.post("/users", json={"name": name})
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


@pytest.fixture
def couple(client):
    """Two users, already paired. Returns (rahul_headers, priya_headers)."""
    rahul = signup(client, "Rahul")
    priya = signup(client, "Priya")
    code = client.post("/couples", headers=rahul).json()["invite_code"]
    r = client.post("/couples/join", json={"code": code}, headers=priya)
    assert r.status_code == 200, r.text
    return rahul, priya


def answer_all(client, headers, mine="a", guess="a", overrides=None):
    qs = client.get("/games/today", headers=headers).json()["questions"]
    overrides = overrides or {}
    payload = []
    for q in qs:
        m, g = overrides.get(q["id"], (mine, guess))
        payload.append({"question_id": q["id"], "mine": m, "guess": g})
    return client.post("/games/today/answers", json={"answers": payload}, headers=headers)
