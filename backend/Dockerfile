# syntax=docker/dockerfile:1
# Container image for the Wardrobe backend (deployed to Fly.io behind HTTPS).
# Uses the official uv base image so the build matches local `uv` tooling.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Compile bytecode for faster cold starts; copy (don't hard-link) from the uv
# cache; never fetch a managed Python (the base image already has 3.12).
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install dependencies first, keyed only on the manifest + lockfile, so app-code
# changes don't bust the dependency layer. `--no-dev` drops pytest/ruff/mypy;
# `--no-install-project` because the app is run as a module, not an installed pkg.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Application code. Tests and secrets are excluded via .dockerignore.
COPY app ./app

# Fly routes public HTTPS (443) to this internal port (see fly.toml).
EXPOSE 8080
CMD ["uv", "run", "--no-sync", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
