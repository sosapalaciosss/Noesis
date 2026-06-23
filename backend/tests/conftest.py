"""Configuración de pruebas: entorno offline con embedder 'hash' y Qdrant en memoria."""
from __future__ import annotations

import os
import tempfile

import pytest

# Configura el entorno ANTES de importar la app.
os.environ["EMBEDDING_PROVIDER"] = "hash"
os.environ["EMBEDDING_DIM"] = "256"
os.environ["QDRANT_URL"] = ""  # Qdrant embebido en memoria
os.environ["MISTRAL_API_KEY"] = ""  # fuerza el LLM de respaldo
os.environ["DEFAULT_INSTITUTION_ID"] = "default"
os.environ["DEFAULT_INSTITUTION_NAME"] = "Institución Demo"


@pytest.fixture()
def app_ctx(tmp_path):
    """Crea un AppContext aislado por prueba."""
    from app.config import Settings
    from app.context import AppContext

    db_path = tmp_path / "noesis_test.db"
    settings = Settings(
        DATABASE_URL=f"sqlite:///{db_path}",
        UPLOAD_DIR=str(tmp_path / "uploads"),
        EMBEDDING_PROVIDER="hash",
        EMBEDDING_DIM=256,
        QDRANT_URL="",
        QDRANT_COLLECTION="test_chunks",
        MISTRAL_API_KEY="",
    )
    return AppContext(settings)


@pytest.fixture()
def client(tmp_path, monkeypatch):
    """Cliente de prueba de FastAPI con un contexto aislado en disco temporal."""
    from fastapi.testclient import TestClient

    from app.config import Settings
    from app.context import AppContext
    import app.context as context_module

    db_path = tmp_path / "noesis_api.db"
    settings = Settings(
        DATABASE_URL=f"sqlite:///{db_path}",
        UPLOAD_DIR=str(tmp_path / "uploads"),
        EMBEDDING_PROVIDER="hash",
        EMBEDDING_DIM=256,
        QDRANT_URL="",
        QDRANT_COLLECTION="api_test_chunks",
        MISTRAL_API_KEY="",
    )
    ctx = AppContext(settings)
    monkeypatch.setattr(context_module, "_context", ctx)

    from app.main import app

    with TestClient(app) as c:
        yield c
