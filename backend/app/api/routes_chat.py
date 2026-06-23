"""Ruta del chat institucional (RAG)."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from ..context import AppContext
from ..models.schemas import ChatRequest, ChatResponse
from ..services import rag
from .deps import context, institution_id

router = APIRouter(prefix="/api/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    inst_id: str = Depends(institution_id),
    ctx: AppContext = Depends(context),
):
    return rag.answer_question(ctx, inst_id, payload.question, payload.top_k)
