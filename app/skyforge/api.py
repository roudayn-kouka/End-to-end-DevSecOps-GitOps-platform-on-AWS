from flask import Blueprint, abort, jsonify, request

from .metrics import TASKS_CREATED
from .models import Task, db

api_bp = Blueprint("api", __name__)

MAX_TITLE_LENGTH = 200


def _validated_title(payload: dict) -> str:
    title = payload.get("title")
    if not isinstance(title, str) or not title.strip():
        abort(400, description="'title' must be a non-empty string")
    title = title.strip()
    if len(title) > MAX_TITLE_LENGTH:
        abort(400, description=f"'title' must be at most {MAX_TITLE_LENGTH} characters")
    return title


@api_bp.get("/tasks")
def list_tasks():
    tasks = db.session.execute(db.select(Task).order_by(Task.id)).scalars()
    return jsonify([task.to_dict() for task in tasks])


@api_bp.post("/tasks")
def create_task():
    payload = request.get_json(silent=True) or {}
    task = Task(title=_validated_title(payload))
    db.session.add(task)
    db.session.commit()
    TASKS_CREATED.inc()
    return jsonify(task.to_dict()), 201


@api_bp.get("/tasks/<int:task_id>")
def get_task(task_id: int):
    return jsonify(db.get_or_404(Task, task_id).to_dict())


@api_bp.patch("/tasks/<int:task_id>")
def update_task(task_id: int):
    task = db.get_or_404(Task, task_id)
    payload = request.get_json(silent=True) or {}
    if "title" in payload:
        task.title = _validated_title(payload)
    if "done" in payload:
        if not isinstance(payload["done"], bool):
            abort(400, description="'done' must be a boolean")
        task.done = payload["done"]
    db.session.commit()
    return jsonify(task.to_dict())


@api_bp.delete("/tasks/<int:task_id>")
def delete_task(task_id: int):
    task = db.get_or_404(Task, task_id)
    db.session.delete(task)
    db.session.commit()
    return "", 204


@api_bp.errorhandler(400)
@api_bp.errorhandler(404)
def json_error(error):
    return jsonify(error=error.name, message=error.description), error.code
