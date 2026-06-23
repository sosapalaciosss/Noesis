from app.core.chunking import chunk_text


def test_empty_text_returns_no_chunks():
    assert chunk_text("") == []
    assert chunk_text("   \n\n  ") == []


def test_short_text_single_chunk():
    chunks = chunk_text("Noesis es la capa de conocimiento del Estado.", chunk_size=900)
    assert len(chunks) == 1
    assert "Noesis" in chunks[0]


def test_long_text_is_split():
    text = "\n\n".join(f"Párrafo número {i}. " * 20 for i in range(40))
    chunks = chunk_text(text, chunk_size=500, chunk_overlap=80)
    assert len(chunks) > 1
    # Ningún chunk debe exceder de forma exagerada el tamaño objetivo.
    assert all(len(c) <= 500 + 200 for c in chunks)


def test_overlap_preserves_context():
    text = "\n\n".join(f"Oracion distinta {i} con contenido relevante." for i in range(30))
    chunks = chunk_text(text, chunk_size=200, chunk_overlap=60)
    assert len(chunks) >= 2


def test_oversized_single_unit_is_windowed():
    text = "palabra " * 400  # ~3200 chars sin fronteras de párrafo
    chunks = chunk_text(text, chunk_size=300, chunk_overlap=50)
    assert len(chunks) > 1
