from app.services import ingestion, rag


SAMPLE = (
    "El Ministerio de Hacienda administra las finanzas públicas de El Salvador. "
    "El presupuesto general de la nación se aprueba anualmente por la Asamblea "
    "Legislativa.\n\n"
    "La Dirección General de Impuestos Internos es responsable de la "
    "recaudación tributaria. El IVA en El Salvador es del trece por ciento."
)


def test_ingest_and_search(app_ctx):
    doc_id = ingestion.ingest_now(
        app_ctx, "default", "hacienda.txt", SAMPLE.encode("utf-8"), "text/plain"
    )
    doc = app_ctx.store.get_document(doc_id)
    assert doc.status == "indexed"
    assert doc.chunk_count >= 1

    resp = rag.answer_question(app_ctx, "default", "¿Cuánto es el IVA?", top_k=3)
    assert resp.sources, "Debe recuperar al menos una fuente"
    assert any("IVA" in s.text or "trece" in s.text for s in resp.sources)
    assert resp.used_llm is False  # modo respaldo en pruebas


def test_multi_institution_isolation(app_ctx):
    app_ctx.store.create_institution("ministerio_a", "Ministerio A")
    app_ctx.store.create_institution("ministerio_b", "Ministerio B")

    ingestion.ingest_now(
        app_ctx, "ministerio_a", "a.txt",
        b"Documento exclusivo del ministerio A sobre carreteras.", "text/plain",
    )
    ingestion.ingest_now(
        app_ctx, "ministerio_b", "b.txt",
        b"Documento exclusivo del ministerio B sobre salud.", "text/plain",
    )

    resp_a = rag.answer_question(app_ctx, "ministerio_a", "carreteras", top_k=5)
    assert all(s.filename == "a.txt" for s in resp_a.sources)

    resp_b = rag.answer_question(app_ctx, "ministerio_b", "salud", top_k=5)
    assert all(s.filename == "b.txt" for s in resp_b.sources)


def test_delete_and_reindex(app_ctx):
    doc_id = ingestion.ingest_now(
        app_ctx, "default", "doc.txt", SAMPLE.encode("utf-8"), "text/plain"
    )
    assert app_ctx.vector_store.count_chunks("default") >= 1

    # Reindexar mantiene el documento y reconstruye los chunks.
    ingestion.process_document(app_ctx, doc_id)
    assert app_ctx.store.get_document(doc_id).status == "indexed"

    # Eliminar borra metadatos y vectores.
    assert ingestion.remove_document(app_ctx, doc_id) is True
    assert app_ctx.store.get_document(doc_id) is None
    assert app_ctx.vector_store.count_chunks("default") == 0
