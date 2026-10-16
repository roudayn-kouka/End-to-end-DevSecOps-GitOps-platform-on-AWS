from flask import Blueprint, current_app, jsonify
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from .models import db

health_bp = Blueprint("health", __name__)


@health_bp.get("/healthz")
def liveness():
    """Liveness: the process is up and serving requests."""
    return jsonify(status="ok")


@health_bp.get("/readyz")
def readiness():
    """Readiness: the app can reach its database."""
    try:
        db.session.execute(text("SELECT 1"))
    except SQLAlchemyError:
        current_app.logger.exception("Readiness check failed")
        return jsonify(status="unavailable", database="down"), 503
    return jsonify(status="ok", database="up")


@health_bp.get("/version")
def version():
    return jsonify(
        version=current_app.config["APP_VERSION"],
        commit=current_app.config["GIT_COMMIT"],
        environment=current_app.config["APP_ENV"],
    )
