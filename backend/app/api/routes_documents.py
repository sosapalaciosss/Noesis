"""Rutas de ingesta y biblioteca documental."""
from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File

from ..context import AppContext
from ..models.schemas import DocumentOut
from ..services import ingestion, parsing
from .deps import context, institution_id

router = APIRouter(prefix="/api/documents", tags=["documents"])


def _to_out(doc) -> DocumentOut:
    return DocumentOut(
        id=doc.id,
        institution_id=doc.institution_id,
        filename=doc.filename,
        content_type=doc.content_type,
        size_bytes=doc.size_bytes,
        status=doc.status,
        chunk_count=doc.chunk_count,
        error=doc.error,
        uploaded_at=doc.uploaded_at,
    )


@router.get("", response_model=list[DocumentOut])
def list_documents(
    inst_id: str = Depends(institution_id), ctx: AppContext = Depends(context)
):
    return [_to_out(d) for d in ctx.store.list_documents(inst_id)]


@router.post("", response_model=DocumentOut, status_code=201)
async def upload_document(
    background: BackgroundTasks,
    file: UploadFile = File(...),
    inst_id: str = Depends(institution_id),
    ctx: AppContext = Depends(context),
):
    filename = file.filename or "documento"
    if not any(filename.lower().endswith(ext) for ext in parsing.SUPPORTED_EXTENSIONS):
        raise HTTPException(
            status_code=422,
            detail="Formato no soportado. Use PDF, DOCX, TXT o MD.",
        )
    data = await file.read()
    if not data:
        raise HTTPException(status_code=422, detail="El archivo está vacío.")

    doc_id = ingestion.register_upload(
        ctx, inst_id, filename, data, file.content_type or ""
    )
    # El procesamiento (parseo + embeddings + indexado) ocurre en segundo plano.
    background.add_task(ingestion.process_document, ctx, doc_id)
    return _to_out(ctx.store.get_document(doc_id))


@router.get("/{doc_id}", response_model=DocumentOut)
def get_document(doc_id: str, ctx: AppContext = Depends(context)):
    doc = ctx.store.get_document(doc_id)
    if doc is None:
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    return _to_out(doc)
