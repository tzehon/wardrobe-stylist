# Wardrobe backend (FastAPI)

Thin proxy that holds the Anthropic API key and calls Claude. **Stateless** — it never
persists email content. See [`../docs/architecture.md`](../docs/architecture.md).

## Setup

```bash
cd backend
uv sync                      # create .venv and install deps
cp .env.example .env         # then fill in ANTHROPIC_API_KEY + DEVICE_TOKEN
```

## Run

```bash
uv run uvicorn app.main:app --reload
# health check:
curl localhost:8000/health
```

## Test & lint (run after every change)

```bash
uv run pytest
uv run ruff check .
uv run mypy app
```

## Endpoints

| Route | Phase | Purpose |
|---|---|---|
| `GET /health` | 0 | liveness |
| `POST /extract` | 2 | receipt text/image → structured purchase (Claude Haiku, tool use) |
| `POST /categorize` | 3 | catalog attributes → browsable taxonomy |
| `POST /recommend` | 5 | "Aria" stylist → daily outfit (streamed) |
