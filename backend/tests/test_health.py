import inspect

from fastapi.testclient import TestClient

from app.main import app, health

client = TestClient(app)


def test_health_ok() -> None:
    assert inspect.iscoroutinefunction(health)
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert "environment" in body
