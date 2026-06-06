from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "Local Business Investing API"
    app_env: str = "local"
    database_url: str = "postgresql+psycopg://app:app_dev_password@localhost:5432/local_business_investing"
    jwt_secret: str = Field(default="replace-me", min_length=10)
    jwt_algorithm: str = "HS256"
    jwt_access_token_minutes: int = 15
    jwt_refresh_token_days: int = 30
    max_upload_bytes: int = 10 * 1024 * 1024
    allowed_upload_content_types: str = "application/pdf,image/jpeg,image/png"
    log_level: str = "INFO"

    @property
    def allowed_upload_types(self) -> set[str]:
        return {item.strip() for item in self.allowed_upload_content_types.split(",") if item.strip()}


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
