"""Proveedores de embeddings con una interfaz común e intercambiable.

- SentenceTransformerEmbedder: modelo local open source (por defecto,
  multilingüe, ideal para español).
- MistralEmbedder: usa la API de embeddings de Mistral (`mistral-embed`).
- HashEmbedder: embeddings deterministas sin dependencias externas, pensado
  para pruebas y entornos sin acceso a internet/modelos.
"""
from __future__ import annotations

import hashlib
import math
from abc import ABC, abstractmethod
from typing import List

from ..config import Settings


class EmbeddingProvider(ABC):
    dimension: int

    @abstractmethod
    def embed_texts(self, texts: List[str]) -> List[List[float]]:
        ...

    def embed_query(self, text: str) -> List[float]:
        return self.embed_texts([text])[0]


class HashEmbedder(EmbeddingProvider):
    """Embedding determinista basado en hashing de tokens (bag of words).

    No captura semántica profunda, pero es estable, rápido y sin dependencias.
    Útil para CI/pruebas y como respaldo offline.
    """

    def __init__(self, dimension: int = 384):
        self.dimension = dimension

    def embed_texts(self, texts: List[str]) -> List[List[float]]:
        return [self._embed_one(t) for t in texts]

    def _embed_one(self, text: str) -> List[float]:
        vec = [0.0] * self.dimension
        tokens = [t for t in _simple_tokenize(text)]
        for tok in tokens:
            h = int(hashlib.md5(tok.encode("utf-8")).hexdigest(), 16)
            idx = h % self.dimension
            sign = 1.0 if (h >> 8) % 2 == 0 else -1.0
            vec[idx] += sign
        norm = math.sqrt(sum(v * v for v in vec)) or 1.0
        return [v / norm for v in vec]


class SentenceTransformerEmbedder(EmbeddingProvider):
    def __init__(self, model_name: str):
        # Import perezoso para no exigir torch en entornos que usan otro proveedor.
        from sentence_transformers import SentenceTransformer

        self.model_name = model_name
        self._model = SentenceTransformer(model_name)
        self.dimension = int(self._model.get_sentence_embedding_dimension())
        # Los modelos E5 esperan prefijos "passage:"/"query:".
        self._is_e5 = "e5" in model_name.lower()

    def embed_texts(self, texts: List[str]) -> List[List[float]]:
        inputs = [f"passage: {t}" for t in texts] if self._is_e5 else texts
        emb = self._model.encode(inputs, normalize_embeddings=True, convert_to_numpy=True)
        return emb.tolist()

    def embed_query(self, text: str) -> List[float]:
        inp = f"query: {text}" if self._is_e5 else text
        emb = self._model.encode([inp], normalize_embeddings=True, convert_to_numpy=True)
        return emb[0].tolist()


class MistralEmbedder(EmbeddingProvider):
    def __init__(self, api_key: str, model: str = "mistral-embed"):
        from mistralai import Mistral

        self._client = Mistral(api_key=api_key)
        self._model = model
        self.dimension = 1024  # dimensión de mistral-embed

    def embed_texts(self, texts: List[str]) -> List[List[float]]:
        resp = self._client.embeddings.create(model=self._model, inputs=texts)
        return [d.embedding for d in resp.data]


def _simple_tokenize(text: str) -> List[str]:
    out, cur = [], []
    for ch in text.lower():
        if ch.isalnum():
            cur.append(ch)
        elif cur:
            out.append("".join(cur))
            cur = []
    if cur:
        out.append("".join(cur))
    return out


def build_embedder(settings: Settings) -> EmbeddingProvider:
    provider = settings.embedding_provider.lower()
    if provider == "hash":
        return HashEmbedder(dimension=settings.embedding_dim)
    if provider == "mistral":
        if not settings.mistral_api_key:
            raise RuntimeError("EMBEDDING_PROVIDER=mistral requiere MISTRAL_API_KEY")
        return MistralEmbedder(settings.mistral_api_key)
    # Por defecto: sentence-transformers (local, open source).
    return SentenceTransformerEmbedder(settings.embedding_model)
