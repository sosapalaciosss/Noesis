import math

from app.core.embeddings import HashEmbedder


def test_hash_embedder_dimension_and_norm():
    emb = HashEmbedder(dimension=128)
    vecs = emb.embed_texts(["hola mundo", "noesis conocimiento"])
    assert len(vecs) == 2
    for v in vecs:
        assert len(v) == 128
        norm = math.sqrt(sum(x * x for x in v))
        assert abs(norm - 1.0) < 1e-6


def test_hash_embedder_is_deterministic():
    emb = HashEmbedder(dimension=64)
    a = emb.embed_query("texto de prueba")
    b = emb.embed_query("texto de prueba")
    assert a == b


def test_similar_texts_more_similar_than_unrelated():
    emb = HashEmbedder(dimension=512)

    def cos(x, y):
        return sum(a * b for a, b in zip(x, y))

    base = emb.embed_query("presupuesto del ministerio de hacienda")
    similar = emb.embed_query("presupuesto del ministerio de hacienda anual")
    unrelated = emb.embed_query("recetas de cocina italiana tradicional")
    assert cos(base, similar) > cos(base, unrelated)
