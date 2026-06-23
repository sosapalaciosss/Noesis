"""Configuración central de Noesis.

Todos los parámetros se leen de variables de entorno para facilitar el
despliegue en contenedores y entornos múltiples.
"""
from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # --- Mistral ---
    mistral_api_key: str = Field(default="", alias="MISTRAL_API_KEY")
    mistral_model: str = Field(default="mistral-large-latest", alias="MISTRAL_MODEL")

    # --- Embeddings ---
    embedding_provider: str = Field(
        default="sentence_transformers", alias="EMBEDDING_PROVIDER"
    )
    embedding_model: str = Field(
        default="intfloat/multilingual-e5-small", alias="EMBEDDING_MODEL"
    )
    embedding_dim: int = Field(default=384, alias="EMBEDDING_DIM")

    # --- Qdrant ---
    qdrant_url: str = Field(default="", alias="QDRANT_URL")
    qdrant_api_key: str = Field(default="", alias="QDRANT_API_KEY")
    qdrant_path: str = Field(default="", alias="QDRANT_PATH")
    qdrant_collection: str = Field(default="noesis_chunks", alias="QDRANT_COLLECTION")

    # --- Metadatos ---
    database_url: str = Field(default="sqlite:///./data/noesis.db", alias="DATABASE_URL")
    upload_dir: str = Field(default="./data/uploads", alias="UPLOAD_DIR")

    # --- RAG ---
    chunk_size: int = Field(default=900, alias="CHUNK_SIZE")
    chunk_overlap: int = Field(default=150, alias="CHUNK_OVERLAP")
    rag_top_k: int = Field(default=5, alias="RAG_TOP_K")

    # --- API ---
    cors_origins: str = Field(
        default="http://localhost:5173,http://localhost:4173", alias="CORS_ORIGINS"
    )
    default_institution_id: str = Field(default="default", alias="DEFAULT_INSTITUTION_ID")
    default_institution_name: str = Field(
        default="Institución Demo", alias="DEFAULT_INSTITUTION_NAME"
    )

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
