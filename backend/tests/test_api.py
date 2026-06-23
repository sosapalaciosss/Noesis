import io
import time


def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["uses_llm"] is False


def test_default_institution_exists(client):
    r = client.get("/api/institutions")
    assert r.status_code == 200
    ids = [i["id"] for i in r.json()]
    assert "default" in ids


def test_create_institution_validation(client):
    # slug inválido
    r = client.post("/api/institutions", json={"id": "Mayúsculas!", "name": "X"})
    assert r.status_code == 422

    r = client.post(
        "/api/institutions", json={"id": "min_salud", "name": "Ministerio de Salud"}
    )
    assert r.status_code == 201

    # duplicado
    r = client.post("/api/institutions", json={"id": "min_salud", "name": "Dup"})
    assert r.status_code == 409


def _wait_indexed(client, doc_id, timeout=10):
    for _ in range(timeout * 5):
        r = client.get(f"/api/documents/{doc_id}")
        if r.json()["status"] in ("indexed", "failed"):
            return r.json()
        time.sleep(0.2)
    return client.get(f"/api/documents/{doc_id}").json()


def test_upload_chat_flow(client):
    content = (
        "Noesis es la plataforma de conocimiento institucional. "
        "El objetivo es centralizar la información del Estado salvadoreño."
    ).encode("utf-8")
    files = {"file": ("noesis.txt", io.BytesIO(content), "text/plain")}
    r = client.post("/api/documents", files=files)
    assert r.status_code == 201, r.text
    doc_id = r.json()["id"]

    doc = _wait_indexed(client, doc_id)
    assert doc["status"] == "indexed"
    assert doc["chunk_count"] >= 1

    # Biblioteca
    r = client.get("/api/documents")
    assert any(d["id"] == doc_id for d in r.json())

    # Chat
    r = client.post("/api/chat", json={"question": "¿Qué es Noesis?"})
    assert r.status_code == 200
    body = r.json()
    assert len(body["sources"]) >= 1

    # Stats
    r = client.get("/api/admin/stats")
    assert r.status_code == 200
    assert r.json()["indexed_documents"] >= 1

    # Eliminar
    r = client.delete(f"/api/admin/documents/{doc_id}")
    assert r.status_code == 204
    r = client.get(f"/api/documents/{doc_id}")
    assert r.status_code == 404


def test_unsupported_format_rejected(client):
    files = {"file": ("malware.exe", io.BytesIO(b"binario"), "application/octet-stream")}
    r = client.post("/api/documents", files=files)
    assert r.status_code == 422
