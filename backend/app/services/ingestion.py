"""Orquestación de la ingesta documental.

Flujo: guardar archivo → extraer texto → dividir en chunks → generar
embeddings → indexar en Qdrant → actualizar metadatos.
"""
from __future__ import annotations

import os
import uuid

from ..context import AppContext
from ..core.chunking import chunk_text
from . import parsing


def register_upload(
    ctx: AppContext, institution_id: str, filename: str, data: bytes, content_type: str
) -> str:
    """Registra el documento como 'pending' y persiste el archivo en disco."""
    doc_id = str(uuid.uuid4())
    os.makedirs(ctx.settings.upload_dir, exist_ok=True)
    safe_name = f"{doc_id}__{os.path.basename(filename)}"
    storage_path = os.path.join(ctx.settings.upload_dir, safe_name)
    with open(storage_path, "wb") as f:
        f.write(data)

    ctx.store.create_document(
        id=doc_id,
        institution_id=institution_id,
        filename=filename,
        content_type=content_type or "",
        size_bytes=len(data),
        status="pending",
        chunk_count=0,
        storage_path=storage_path,
    )
    return doc_id


def process_document(ctx: AppContext, doc_id: str) -> None:
    """Procesa e indexa un documento ya registrado. Idempotente por reindexado."""
    doc = ctx.store.get_document(doc_id)
    if doc is None:
        return
    ctx.store.update_document(doc_id, status="processing", error=None)
    try:
        with open(doc.storage_path, "rb") as f:
            data = f.read()
        text = parsing.extract_text(doc.filename, data, doc.content_type)
        if not text.strip():
            raise ValueError("No se pudo extraer texto del documento.")

        chunks = chunk_text(
            text,
            chunk_size=ctx.settings.chunk_size,
            chunk_overlap=ctx.settings.chunk_overlap,
        )
        # Limpia índices previos (reindexado) y vuelve a insertar.
        ctx.vector_store.delete_document(doc_id)
        count = ctx.vector_store.upsert_document_chunks(
            institution_id=doc.institution_id,
            document_id=doc_id,
            filename=doc.filename,
            chunks=chunks,
        )
        ctx.store.update_document(
            doc_id, status="indexed", chunk_count=count, error=None
        )
    except Exception as exc:  # noqa: BLE001
        ctx.store.update_document(doc_id, status="failed", error=str(exc))


def ingest_now(
    ctx: AppContext, institution_id: str, filename: str, data: bytes, content_type: str
) -> str:
    """Atajo síncrono: registra y procesa de inmediato."""
    doc_id = register_upload(ctx, institution_id, filename, data, content_type)
    process_document(ctx, doc_id)
    return doc_id


def remove_document(ctx: AppContext, doc_id: str) -> bool:
    doc = ctx.store.get_document(doc_id)
    if doc is None:
        return False
    ctx.vector_store.delete_document(doc_id)
    if doc.storage_path and os.path.exists(doc.storage_path):
        try:
            os.remove(doc.storage_path)
        except OSError:
            pass
    return ctx.store.delete_document(doc_id)
