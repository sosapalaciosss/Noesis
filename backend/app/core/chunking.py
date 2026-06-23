"""División inteligente de texto en fragmentos (chunks).

Estrategia: se respeta en lo posible la frontera de párrafos y oraciones,
acumulando texto hasta `chunk_size` caracteres con un solapamiento
(`chunk_overlap`) que preserva el contexto entre fragmentos contiguos.
"""
from __future__ import annotations

import re
from typing import List

# Separadores ordenados de mayor a menor prioridad semántica.
_PARAGRAPH_RE = re.compile(r"\n\s*\n")
_SENTENCE_RE = re.compile(r"(?<=[\.\?\!;:])\s+")


def _normalize(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    # Colapsa espacios redundantes pero conserva los saltos de párrafo.
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _split_units(text: str) -> List[str]:
    """Divide en párrafos y, si un párrafo es muy largo, en oraciones."""
    units: List[str] = []
    for paragraph in _PARAGRAPH_RE.split(text):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        if len(paragraph) <= 1200:
            units.append(paragraph)
        else:
            units.extend(s.strip() for s in _SENTENCE_RE.split(paragraph) if s.strip())
    return units


def chunk_text(text: str, chunk_size: int = 900, chunk_overlap: int = 150) -> List[str]:
    """Devuelve una lista de fragmentos de texto listos para embeddings."""
    text = _normalize(text)
    if not text:
        return []
    if chunk_overlap >= chunk_size:
        chunk_overlap = chunk_size // 4

    units = _split_units(text)
    chunks: List[str] = []
    current = ""

    for unit in units:
        # Si una sola unidad excede el tamaño, se trocea por ventanas duras.
        if len(unit) > chunk_size:
            if current:
                chunks.append(current.strip())
                current = ""
            for i in range(0, len(unit), chunk_size - chunk_overlap):
                chunks.append(unit[i : i + chunk_size].strip())
            continue

        if not current:
            current = unit
        elif len(current) + len(unit) + 1 <= chunk_size:
            current = f"{current}\n{unit}"
        else:
            chunks.append(current.strip())
            # Solapamiento: arrastra la cola del fragmento anterior.
            tail = current[-chunk_overlap:] if chunk_overlap else ""
            current = f"{tail}\n{unit}".strip() if tail else unit

    if current.strip():
        chunks.append(current.strip())

    return [c for c in chunks if c]
