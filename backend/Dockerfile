# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
# Container image for the Wardrobe backend (deployed to Fly.io behind HTTPS).
# Uses the official uv base image so the build matches local `uv` tooling.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim@sha256:e5b65587bce7de595f299855d7385fe7fca39b8a74baa261ba1b7147afa78e58

# Compile bytecode for faster cold starts; copy (don't hard-link) from the uv
# cache; never fetch a managed Python (the base image already has 3.12).
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# The entrypoint starts with only enough privilege to prepare a root-owned Fly
# volume, then irrevocably drops to this fixed unprivileged identity before it
# executes Uvicorn (or an operator-supplied diagnostic command).
RUN groupadd --gid 10001 wardrobe \
    && useradd --uid 10001 --gid 10001 --no-create-home \
        --home-dir /nonexistent --shell /usr/sbin/nologin wardrobe

# Install dependencies first, keyed only on the manifest + lockfile, so app-code
# changes don't bust the dependency layer. `--no-dev` drops test/audit/lint tooling;
# `--no-install-project` because the app is run as a module, not an installed pkg.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

# Application code. Tests and secrets are excluded via .dockerignore.
COPY app ./app
COPY container_entrypoint.py ./container_entrypoint.py

# Fly routes public HTTPS (443) to this internal port (see fly.toml).
EXPOSE 8080
ENTRYPOINT ["python", "/app/container_entrypoint.py"]
CMD ["/app/.venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
