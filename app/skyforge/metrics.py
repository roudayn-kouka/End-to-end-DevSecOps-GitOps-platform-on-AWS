"""Prometheus instrumentation (scraped by the ServiceMonitor shipped in the Helm chart)."""

import time

from flask import Flask, Response, g, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

REQUEST_COUNT = Counter(
    "skyforge_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "skyforge_http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
)
TASKS_CREATED = Counter("skyforge_tasks_created_total", "Number of tasks created")

_UNTRACKED = {"/metrics", "/healthz", "/readyz"}


def init_metrics(app: Flask) -> None:
    @app.before_request
    def _start_timer():
        g.request_start = time.perf_counter()

    @app.after_request
    def _record(response):
        if request.path in _UNTRACKED or "request_start" not in g:
            return response
        # Use the route template (/api/tasks/<int:task_id>) to keep label cardinality bounded.
        endpoint = request.url_rule.rule if request.url_rule else "unmatched"
        REQUEST_LATENCY.labels(request.method, endpoint).observe(time.perf_counter() - g.request_start)
        REQUEST_COUNT.labels(request.method, endpoint, response.status_code).inc()
        return response

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
