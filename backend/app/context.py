"""Contenedor de dependencias de la aplicación.

Centraliza la construcción de los componentes pesados (embedder, almacén
vectorial, LLM, base de metadatos) para reutilizarlos en toda la API.
"""
from __future__ import annotations

from .config import Settings, get_settings
from .core.embeddings import EmbeddingProvider, build_embedder
from .core.llm import build_llm
from .core.vector_store import VectorStore
from .db.store import MetadataStore


class AppContext:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.store = MetadataStore(settings.database_url)
        self.embedder: EmbeddingProvider = build_embedder(settings)
        self.vector_store = VectorStore(
            collection=settings.qdrant_collection,
            embedder=self.embedder,
            url=settings.qdrant_url,
            api_key=settings.qdrant_api_key,
        )
        self.llm, self.uses_real_llm = build_llm(
            settings.mistral_api_key, settings.mistral_model
        )
        # Garantiza la institución por defecto para el MVP de una entidad.
        self.store.ensure_institution(
            settings.default_institution_id, settings.default_institution_name
        )


_context: AppContext | None = None


def get_context() -> AppContext:
    global _context
    if _context is None:
        _context = AppContext(get_settings())
    return _context


def reset_context() -> None:
    """Reinicia el contexto (usado en pruebas)."""
    global _context
    _context = None
