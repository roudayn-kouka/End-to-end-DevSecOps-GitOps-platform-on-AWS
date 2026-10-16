import pytest


def create(client, title="Write Terraform modules"):
    return client.post("/api/tasks", json={"title": title})


def test_list_is_empty_initially(client):
    response = client.get("/api/tasks")
    assert response.status_code == 200
    assert response.get_json() == []


def test_create_task(client):
    response = create(client, "  Deploy with ArgoCD  ")
    assert response.status_code == 201
    body = response.get_json()
    assert body["title"] == "Deploy with ArgoCD"
    assert body["done"] is False
    assert "created_at" in body


@pytest.mark.parametrize(
    "payload", [{}, {"title": ""}, {"title": "   "}, {"title": 42}, {"title": "x" * 201}]
)
def test_create_task_rejects_invalid_title(client, payload):
    response = client.post("/api/tasks", json=payload)
    assert response.status_code == 400
    assert response.get_json()["error"] == "Bad Request"


def test_create_task_rejects_non_json_body(client):
    response = client.post("/api/tasks", data="not json")
    assert response.status_code == 400


def test_get_task(client):
    task_id = create(client).get_json()["id"]
    response = client.get(f"/api/tasks/{task_id}")
    assert response.status_code == 200
    assert response.get_json()["id"] == task_id


def test_get_missing_task_returns_404(client):
    response = client.get("/api/tasks/999")
    assert response.status_code == 404
    assert response.get_json()["error"] == "Not Found"


def test_update_task(client):
    task_id = create(client).get_json()["id"]
    response = client.patch(f"/api/tasks/{task_id}", json={"done": True, "title": "Renamed"})
    assert response.status_code == 200
    assert response.get_json()["done"] is True
    assert response.get_json()["title"] == "Renamed"


def test_update_task_rejects_non_boolean_done(client):
    task_id = create(client).get_json()["id"]
    response = client.patch(f"/api/tasks/{task_id}", json={"done": "yes"})
    assert response.status_code == 400


def test_delete_task(client):
    task_id = create(client).get_json()["id"]
    assert client.delete(f"/api/tasks/{task_id}").status_code == 204
    assert client.get(f"/api/tasks/{task_id}").status_code == 404


def test_tasks_are_listed_in_creation_order(client):
    for title in ("first", "second", "third"):
        create(client, title)
    titles = [task["title"] for task in client.get("/api/tasks").get_json()]
    assert titles == ["first", "second", "third"]
