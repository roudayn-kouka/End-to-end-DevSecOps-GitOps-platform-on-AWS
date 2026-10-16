import os

bind = f"0.0.0.0:{os.getenv('PORT', '5000')}"
workers = int(os.getenv("GUNICORN_WORKERS", "2"))
threads = int(os.getenv("GUNICORN_THREADS", "4"))
timeout = 30
graceful_timeout = 20
accesslog = "-"
errorlog = "-"
# Write worker heartbeat files to memory: the root filesystem is read-only in Kubernetes.
worker_tmp_dir = "/dev/shm"  # noqa: S108
