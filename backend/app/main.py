"""Punto de entrada de la API de Noesis."""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import routes_admin, routes_chat, routes_documents, routes_institutions
from .config import get_settings
from .context import get_context

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicializa el contexto (modelos, Qdrant, BD) al arrancar.
    get_context()
    yield


app = FastAPI(
    title="Noesis API",
    description="Capa de conocimiento institucional basada en RAG.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routes_institutions.router)
app.include_router(routes_documents.router)
app.include_router(routes_chat.router)
app.include_router(routes_admin.router)


@app.get("/api/health", tags=["health"])
def health():
    ctx = get_context()
    return {
        "status": "ok",
        "uses_llm": ctx.uses_real_llm,
        "embedding_provider": ctx.settings.embedding_provider,
        "embedding_dim": ctx.embedder.dimension,
    }


@app.get("/", include_in_schema=False)
def root():
    return {"name": "Noesis", "docs": "/docs", "health": "/api/health"}
