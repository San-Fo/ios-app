from fastapi import FastAPI

from app.core.config import settings
from app.routers import admin, auth, businesses, deal_rooms, investments, recommendations, takeover_groups


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Backend API for preserving and financing beloved Hong Kong local businesses.",
)


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok", "environment": settings.app_env}


app.include_router(auth.router)
app.include_router(businesses.router)
app.include_router(investments.router)
app.include_router(recommendations.router)
app.include_router(takeover_groups.router)
app.include_router(deal_rooms.router)
app.include_router(admin.router)
