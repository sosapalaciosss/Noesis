"""Almacén vectorial sobre Qdrant con soporte multi-institución.

Multi-tenancy: se usa una única colección con un índice de payload sobre
`institution_id`. Cada búsqueda filtra por institución, garantizando el
aislamiento del conocimiento entre entidades (patrón recomendado por Qdrant).

Si `QDRANT_URL` está vacío, se utiliza Qdrant embebido. Si además se define
`QDRANT_PATH`, los vectores se persisten en disco (ideal para ejecución local
sin servidor); en caso contrario se usa el modo en memoria (pruebas).
"""
from __future__ import annotations

import os
import uuid
from typing import List, Optional

from qdrant_client import QdrantClient
from qdrant_client.http import models as qm

from .embeddings import EmbeddingProvider


class VectorStore:
    def __init__(
        self,
        collection: str,
        embedder: EmbeddingProvider,
        url: str = "",
        api_key: str = "",
        path: str = "",
    ):
        self.collection = collection
        self.embedder = embedder
        if url:
            # Servidor Qdrant externo (p. ej. Docker).
            self.client = QdrantClient(url=url, api_key=api_key or None, timeout=30)
        elif path:
            # Qdrant embebido y persistente en disco (ejecución local sin servidor).
            os.makedirs(path, exist_ok=True)
            self.client = QdrantClient(path=path)
        else:
            # Modo embebido en memoria (pruebas).
            self.client = QdrantClient(location=":memory:")
        self._ensure_collection()

    def _ensure_collection(self) -> None:
        existing = {c.name for c in self.client.get_collections().collections}
        if self.collection not in existing:
            self.client.create_collection(
                collection_name=self.collection,
                vectors_config=qm.VectorParams(
                    size=self.embedder.dimension, distance=qm.Distance.COSINE
                ),
            )
        # Índice de payload para filtrar eficientemente por institución.
        try:
            self.client.create_payload_index(
                collection_name=self.collection,
                field_name="institution_id",
                field_schema=qm.PayloadSchemaType.KEYWORD,
            )
            self.client.create_payload_index(
                collection_name=self.collection,
                field_name="document_id",
                field_schema=qm.PayloadSchemaType.KEYWORD,
            )
        except Exception:
            # El índice ya existe; Qdrant es idempotente salvo en versiones antiguas.
            pass

    # --- Escritura --------------------------------------------------------- #
    def upsert_document_chunks(
        self, institution_id: str, document_id: str, filename: str, chunks: List[str]
    ) -> int:
        if not chunks:
            return 0
        vectors = self.embedder.embed_texts(chunks)
        points = [
            qm.PointStruct(
                id=str(uuid.uuid4()),
                vector=vec,
                payload={
                    "institution_id": institution_id,
                    "document_id": document_id,
                    "filename": filename,
                    "chunk_index": idx,
                    "text": text,
                },
            )
            for idx, (text, vec) in enumerate(zip(chunks, vectors))
        ]
        self.client.upsert(collection_name=self.collection, points=points)
        return len(points)

    # --- Lectura ----------------------------------------------------------- #
    def search(
        self, institution_id: str, query: str, top_k: int = 5
    ) -> List[dict]:
        query_vector = self.embedder.embed_query(query)
        flt = qm.Filter(
            must=[
                qm.FieldCondition(
                    key="institution_id",
                    match=qm.MatchValue(value=institution_id),
                )
            ]
        )
        results = self.client.search(
            collection_name=self.collection,
            query_vector=query_vector,
            query_filter=flt,
            limit=top_k,
            with_payload=True,
        )
        out = []
        for r in results:
            payload = r.payload or {}
            out.append(
                {
                    "document_id": payload.get("document_id", ""),
                    "filename": payload.get("filename", ""),
                    "chunk_index": payload.get("chunk_index", 0),
                    "text": payload.get("text", ""),
                    "score": float(r.score),
                }
            )
        return out

    # --- Mantenimiento ----------------------------------------------------- #
    def delete_document(self, document_id: str) -> None:
        self.client.delete(
            collection_name=self.collection,
            points_selector=qm.FilterSelector(
                filter=qm.Filter(
                    must=[
                        qm.FieldCondition(
                            key="document_id",
                            match=qm.MatchValue(value=document_id),
                        )
                    ]
                )
            ),
        )

    def count_chunks(self, institution_id: Optional[str] = None) -> int:
        flt = None
        if institution_id:
            flt = qm.Filter(
                must=[
                    qm.FieldCondition(
                        key="institution_id",
                        match=qm.MatchValue(value=institution_id),
                    )
                ]
            )
        return self.client.count(
            collection_name=self.collection, count_filter=flt, exact=True
        ).count
