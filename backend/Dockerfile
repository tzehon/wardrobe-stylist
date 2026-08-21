# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
# Container image for the Wardrobe backend (deployed to Fly.io behind HTTPS).
# Keep uv and its build-only OS packages out of the runtime image. Both stages
# are digest-pinned; the runtime stays on Python 3.12 to match CI and local
# validation while using Alpine's smaller audited package surface.
FROM ghcr.io/astral-sh/uv:python3.12-alpine@sha256:138f90e67682b923c4bbcc91d2bae98434e8ba8b32b555e390b055b504f69f91 AS builder

# Compile bytecode for faster cold starts; copy (don't hard-link) from the uv
# cache; never fetch a managed Python (the base image already has 3.12).
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install dependencies first, keyed only on the manifest + lockfile, so app-code
# changes don't bust the dependency layer. `--no-dev` drops test/audit/lint tooling;
# `--no-install-project` because the app is run as a module, not an installed pkg.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

FROM python:3.12-alpine@sha256:78098ea6a3a9c6a7727a5d4674e4a44e57e01fac878ee9cb4d24a86bd93916ff

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# The entrypoint starts with only enough privilege to prepare a root-owned Fly
# volume, then irrevocably drops to this fixed unprivileged identity before it
# executes Uvicorn (or an operator-supplied diagnostic command).
RUN addgroup -S -g 10001 wardrobe \
    && adduser -S -D -H -u 10001 -G wardrobe \
        -s /sbin/nologin wardrobe

COPY --from=builder /app/.venv /app/.venv

# Application code. Tests and secrets are excluded via .dockerignore.
COPY app ./app
COPY container_entrypoint.py ./container_entrypoint.py
COPY uvicorn-logging.json ./uvicorn-logging.json

# Fly routes public HTTPS (443) to this internal port (see fly.toml).
EXPOSE 8080
ENTRYPOINT ["python", "/app/container_entrypoint.py"]
# APP-009 forbids application access logs because they include client/request
# metadata. Emit INFO only from the bounded App Attest security-event logger;
# other application loggers retain their default WARNING threshold.
CMD ["/app/.venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--log-config", "/app/uvicorn-logging.json", "--no-access-log"]
