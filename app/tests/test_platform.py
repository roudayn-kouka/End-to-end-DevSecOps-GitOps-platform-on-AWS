"""Endpoints the platform relies on: probes, metrics, version and the UI."""

from sqlalchemy.exc import OperationalError


def test_liveness(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_readiness_when_database_is_up(client):
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.get_json()["database"] == "up"


def test_readiness_when_database_is_down(client, monkeypatch):
    from skyforge.models import db

    def broken(*args, **kwargs):
        raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    monkeypatch.setattr(db.session, "execute", broken)
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.get_json()["database"] == "down"


def test_version(client):
    body = client.get("/version").get_json()
    assert set(body) == {"version", "commit", "environment"}
    assert body["environment"] == "test"


def test_metrics_are_exposed(client):
    client.post("/api/tasks", json={"title": "observe me"})
    client.get("/api/tasks/1")
    body = client.get("/metrics").get_data(as_text=True)
    assert "skyforge_http_requests_total" in body
    assert 'endpoint="/api/tasks/<int:task_id>"' in body
    assert "skyforge_tasks_created_total" in body


def test_index_page(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"SkyForge" in response.data
