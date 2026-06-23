"""Rutas del panel administrativo: estadísticas, eliminar y reindexar."""
from __future__ import annotations

from collections import Counter

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException

from ..context import AppContext
from ..models.schemas import DocumentOut, StatsOut
from ..services import ingestion
from .deps import context, institution_id

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.get("/stats", response_model=StatsOut)
def stats(
    inst_id: str = Depends(institution_id), ctx: AppContext = Depends(context)
):
    docs = ctx.store.list_documents(inst_id)
    breakdown = Counter(d.status for d in docs)
    return StatsOut(
        institution_id=inst_id,
        document_count=len(docs),
        indexed_documents=sum(1 for d in docs if d.status == "indexed"),
        chunk_count=ctx.vector_store.count_chunks(inst_id),
        total_size_bytes=sum(d.size_bytes for d in docs),
        status_breakdown=dict(breakdown),
    )


@router.delete("/documents/{doc_id}", status_code=204)
def delete_document(doc_id: str, ctx: AppContext = Depends(context)):
    if not ingestion.remove_document(ctx, doc_id):
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    return None


@router.post("/documents/{doc_id}/reindex", response_model=DocumentOut)
def reindex_document(
    doc_id: str, background: BackgroundTasks, ctx: AppContext = Depends(context)
):
    doc = ctx.store.get_document(doc_id)
    if doc is None:
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    ctx.store.update_document(doc_id, status="pending", error=None)
    background.add_task(ingestion.process_document, ctx, doc_id)
    return DocumentOut(
        id=doc.id,
        institution_id=doc.institution_id,
        filename=doc.filename,
        content_type=doc.content_type,
        size_bytes=doc.size_bytes,
        status="pending",
        chunk_count=doc.chunk_count,
        error=None,
        uploaded_at=doc.uploaded_at,
    )
