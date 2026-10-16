"""SkyForge Tasks - a small cloud-native task tracker used to showcase the platform."""

from flask import Flask

from .api import api_bp
from .config import Config
from .health import health_bp
from .metrics import init_metrics
from .models import db
from .web import web_bp

__version__ = "1.0.0"


def create_app(config: type[Config] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config or Config)

    db.init_app(app)
    with app.app_context():
        db.create_all()

    app.register_blueprint(web_bp)
    app.register_blueprint(api_bp, url_prefix="/api")
    app.register_blueprint(health_bp)
    init_metrics(app)

    return app
