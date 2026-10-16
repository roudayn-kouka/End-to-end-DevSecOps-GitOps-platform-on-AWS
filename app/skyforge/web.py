from flask import Blueprint, current_app, render_template

web_bp = Blueprint("web", __name__)


@web_bp.get("/")
def index():
    return render_template(
        "index.html",
        version=current_app.config["APP_VERSION"],
        commit=current_app.config["GIT_COMMIT"][:7],
        environment=current_app.config["APP_ENV"],
    )
