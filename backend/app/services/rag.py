"""Servicio RAG: recuperación + generación con citas."""
from __future__ import annotations

from ..context import AppContext
from ..models.schemas import ChatResponse, SourceChunk


def answer_question(
    ctx: AppContext, institution_id: str, question: str, top_k: int | None = None
) -> ChatResponse:
    top_k = top_k or ctx.settings.rag_top_k
    hits = ctx.vector_store.search(institution_id, question, top_k=top_k)
    answer = ctx.llm.generate(question, hits)
    sources = [
        SourceChunk(
            document_id=h["document_id"],
            filename=h["filename"],
            chunk_index=h["chunk_index"],
            text=h["text"],
            score=h["score"],
        )
        for h in hits
    ]
    return ChatResponse(answer=answer, sources=sources, used_llm=ctx.uses_real_llm)
