# Local Business Investing Backend

FastAPI backend for an iOS-first Hong Kong local business preservation and financing platform.

## Local Development

```powershell
python -m venv .venv
.\.venv\Scripts\pip install -e ".[dev]"
copy .env.example .env
.\.venv\Scripts\uvicorn app.main:app --reload
```

API docs:
- Swagger UI: `http://localhost:8000/docs`
- OpenAPI JSON: `http://localhost:8000/openapi.json`

## Docker

```powershell
docker compose up --build
```

## Current Scope

This is the initial backend scaffold: domain models, DTOs, routers, auth primitives, RBAC dependencies, deterministic recommendations, Docker, and seed data. Payment settlement, KYC/AML, escrow, and legal document execution are intentionally out of scope for this first implementation pass.
