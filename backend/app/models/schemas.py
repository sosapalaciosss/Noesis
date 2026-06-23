"""Esquemas Pydantic compartidos por la API."""
from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


# --------------------------------------------------------------------------- #
# Instituciones
# --------------------------------------------------------------------------- #
class InstitutionCreate(BaseModel):
    id: str = Field(..., description="Identificador único (slug) de la institución")
    name: str
    description: str = ""


class InstitutionOut(BaseModel):
    id: str
    name: str
    description: str
    document_count: int = 0
    created_at: datetime


# --------------------------------------------------------------------------- #
# Documentos
# --------------------------------------------------------------------------- #
class DocumentOut(BaseModel):
    id: str
    institution_id: str
    filename: str
    content_type: str
    size_bytes: int
    status: str
    chunk_count: int
    error: Optional[str] = None
    uploaded_at: datetime


# --------------------------------------------------------------------------- #
# Chat / RAG
# --------------------------------------------------------------------------- #
class SourceChunk(BaseModel):
    document_id: str
    filename: str
    chunk_index: int
    text: str
    score: float


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1)
    top_k: Optional[int] = None


class ChatResponse(BaseModel):
    answer: str
    sources: List[SourceChunk]
    used_llm: bool


# --------------------------------------------------------------------------- #
# Estadísticas
# --------------------------------------------------------------------------- #
class StatsOut(BaseModel):
    institution_id: str
    document_count: int
    indexed_documents: int
    chunk_count: int
    total_size_bytes: int
    status_breakdown: dict
