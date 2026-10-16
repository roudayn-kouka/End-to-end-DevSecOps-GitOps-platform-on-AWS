import os


class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL", "sqlite:///skyforge.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}

    APP_ENV = os.getenv("APP_ENV", "local")
    APP_VERSION = os.getenv("APP_VERSION", "dev")
    GIT_COMMIT = os.getenv("GIT_COMMIT", "unknown")


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite://"
    SQLALCHEMY_ENGINE_OPTIONS = {}
    APP_ENV = "test"
