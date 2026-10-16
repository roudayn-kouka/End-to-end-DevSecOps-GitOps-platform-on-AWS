# syntax=docker/dockerfile:1.7
# Multi-stage build:
#   builder      -> builds wheels for runtime dependencies
#   test         -> lint + unit tests (the build fails if they fail)
#   test-report  -> exports JUnit/coverage reports for Jenkins (docker buildx --output)
#   runtime      -> minimal, non-root production image

ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


FROM python:${PYTHON_VERSION}-slim AS test
WORKDIR /src
COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY . .
RUN mkdir -p /reports \
 && ruff check . \
 && ruff format --check . \
 && pytest --junitxml=/reports/junit.xml --cov-report=xml:/reports/coverage.xml


FROM scratch AS test-report
COPY --from=test /reports /


FROM python:${PYTHON_VERSION}-slim AS runtime

ARG APP_VERSION=dev
ARG GIT_COMMIT=unknown

LABEL org.opencontainers.image.title="skyforge-tasks" \
      org.opencontainers.image.description="SkyForge Tasks demo workload" \
      org.opencontainers.image.authors="Roudayna Kouka" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    GIT_COMMIT=${GIT_COMMIT}

RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

COPY --chown=app:app skyforge ./skyforge
COPY --chown=app:app wsgi.py gunicorn.conf.py ./

USER 10001
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/healthz').status == 200 else 1)"

CMD ["gunicorn", "--config", "gunicorn.conf.py", "wsgi:app"]
