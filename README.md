# Noesis · Capa de Conocimiento Institucional

> Plataforma de conocimiento institucional basada en **RAG** (Retrieval-Augmented
> Generation), diseñada para convertirse en la capa de conocimiento del Estado
> salvadoreño. El MVP se enfoca en una institución, con una arquitectura
> **multi-institución** preparada para escalar a múltiples entidades gubernamentales.

<p align="center">
  <em>Mistral · Qdrant · sentence-transformers · FastAPI · React</em>
</p>

---

## ✨ Características

| Módulo | Descripción |
|---|---|
| **Ingesta documental** | Subida de PDF, DOCX, TXT y MD. Procesamiento automático: extracción de texto, división inteligente en *chunks*, embeddings e indexación. |
| **Biblioteca documental** | Lista de documentos con fecha de carga, tamaño, número de fragmentos y estado de indexación en tiempo real. |
| **Chat institucional** | Preguntas en lenguaje natural respondidas con RAG, con **citas visibles**, documentos fuente y fragmentos utilizados. |
| **Panel administrativo** | Ver, eliminar y reindexar documentos; estadísticas básicas del espacio de conocimiento. |
| **Multi-institución** | Cada institución posee su propio espacio de conocimiento aislado (multi-tenancy por filtrado en Qdrant). |

---

## 🏗️ Arquitectura

```
┌──────────────┐      ┌──────────────────────────┐      ┌─────────────┐
│   Frontend   │  →   │         Backend          │  →   │   Qdrant    │
│ React + Vite │ HTTP │  FastAPI (Python)        │      │  (vectores) │
│  Tailwind    │ ←    │  ┌────────────────────┐  │      └─────────────┘
└──────────────┘      │  │ Ingesta / Parsing  │  │
                      │  │ Chunking           │  │      ┌─────────────┐
                      │  │ Embeddings         │  │  →   │   SQLite    │
                      │  │ RAG + Mistral      │  │      │ (metadatos) │
                      │  └────────────────────┘  │      └─────────────┘
                      └──────────────────────────┘
                                  │
                                  ▼
                          ┌───────────────┐
                          │  Mistral API  │  (modelo principal)
                          └───────────────┘
```

### Selección de tecnologías open source

Tras evaluar las opciones disponibles, se seleccionaron:

- **Base vectorial → [Qdrant](https://qdrant.tech)**: moderna, open source, escrita en
  Rust, con *multi-tenancy* nativa mediante índices de payload. Soporta modo
  embebido en memoria para desarrollo/pruebas sin servicio externo.
- **Embeddings → [sentence-transformers](https://www.sbert.net)** con el modelo
  `intfloat/multilingual-e5-small`: open source, **multilingüe** (excelente para
  español), ligero y de alta calidad. Intercambiable por `mistral-embed`.
- **RAG**: pipeline propio y ligero (recuperación → *prompt* con citas →
  generación), sin acoplarse a un framework pesado, manteniendo control total.
- **LLM → [Mistral](https://mistral.ai)** vía el SDK oficial `mistralai`
  (`mistral-large-latest`). Si no hay API key, se usa un **modo extractivo**
  de respaldo para que la plataforma funcione sin credenciales.
- **API → [FastAPI](https://fastapi.tiangolo.com)**: asíncrono, moderno,
  documentación OpenAPI automática.
- **Frontend → React + Vite + TypeScript + TailwindCSS**: estética premium,
  institucional, minimalista y basada en azules profundos.

---

## 🚀 Puesta en marcha

### Opción A — Docker (recomendada)

Requiere Docker y Docker Compose.

```bash
git clone <repo> && cd Noesis
cp .env.example .env          # opcional: añade tu MISTRAL_API_KEY
docker compose up --build
```

- Frontend: <http://localhost:8080>
- API + documentación: <http://localhost:8000/docs>
- Qdrant: <http://localhost:6333/dashboard>

> Sin `MISTRAL_API_KEY`, el chat responde en **modo extractivo** (devuelve los
> fragmentos más relevantes). Añade la clave en `.env` para respuestas
> redactadas por Mistral.

### Opción B — Desarrollo local

**Backend**

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Modo sin dependencias externas (Qdrant en memoria, embeddings 'hash'):
export QDRANT_URL="" EMBEDDING_PROVIDER=hash
uvicorn app.main:app --reload --port 8000
```

Para el stack completo, levanta Qdrant aparte y usa el embedder local:

```bash
docker run -p 6333:6333 qdrant/qdrant:v1.12.4
export QDRANT_URL=http://localhost:6333 EMBEDDING_PROVIDER=sentence_transformers
uvicorn app.main:app --reload --port 8000
```

**Frontend**

```bash
cd frontend
npm install
npm run dev      # http://localhost:5173 (proxy /api → :8000)
```

---

## 🧪 Pruebas

La suite usa el embedder determinista `hash` y Qdrant en memoria, por lo que
corre sin descargar modelos ni levantar servicios:

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-test.txt
pytest -q
```

Cobertura: chunking, embeddings, ingesta + RAG, aislamiento multi-institución,
y el flujo HTTP completo de la API (subida → indexado → chat → estadísticas →
eliminación).

```bash
cd frontend && npm run build   # type-check + build de producción
```

---

## ⚙️ Configuración (variables de entorno)

| Variable | Por defecto | Descripción |
|---|---|---|
| `MISTRAL_API_KEY` | *(vacío)* | API key de Mistral. Vacío ⇒ modo extractivo. |
| `MISTRAL_MODEL` | `mistral-large-latest` | Modelo de chat de Mistral. |
| `EMBEDDING_PROVIDER` | `sentence_transformers` | `sentence_transformers` \| `mistral` \| `hash`. |
| `EMBEDDING_MODEL` | `intfloat/multilingual-e5-small` | Modelo de embeddings local. |
| `QDRANT_URL` | `http://localhost:6333` | Vacío ⇒ Qdrant embebido en memoria. |
| `QDRANT_COLLECTION` | `noesis_chunks` | Colección compartida (multi-tenant). |
| `DATABASE_URL` | `sqlite:///./data/noesis.db` | Metadatos. |
| `CHUNK_SIZE` / `CHUNK_OVERLAP` | `900` / `150` | Parámetros de fragmentación. |
| `RAG_TOP_K` | `5` | Fragmentos recuperados por consulta. |

Ver [`.env.example`](.env.example) para la lista completa.

---

## 📡 API principal

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/health` | Estado del sistema y del modelo. |
| `GET` / `POST` | `/api/institutions` | Listar / crear instituciones. |
| `GET` / `POST` | `/api/documents` | Biblioteca / subir documento. |
| `GET` | `/api/documents/{id}` | Detalle de un documento. |
| `POST` | `/api/chat` | Pregunta RAG (responde con citas). |
| `GET` | `/api/admin/stats` | Estadísticas del espacio. |
| `DELETE` | `/api/admin/documents/{id}` | Eliminar documento. |
| `POST` | `/api/admin/documents/{id}/reindex` | Reindexar documento. |

Todas las rutas con datos aceptan `?institution_id=<slug>` (por defecto, la
institución demo). Documentación interactiva en `/docs`.

---

## 🔭 Escalabilidad multi-institución

- **Aislamiento**: cada fragmento se almacena en Qdrant con un payload
  `institution_id` indexado; toda búsqueda filtra por institución, garantizando
  que el conocimiento de una entidad nunca se filtre a otra.
- **Crecimiento**: el patrón de colección única + filtrado por tenant es el
  recomendado por Qdrant para miles de tenants. Migrar a colecciones dedicadas
  por institución es directo si una entidad lo requiere.
- **Extensible**: autenticación/roles por institución, colas de procesamiento
  (Celery/RQ) y almacenamiento de objetos (S3/MinIO) son los siguientes pasos
  naturales hacia producción.

---

## 📂 Estructura

```
Noesis/
├── docker-compose.yml
├── backend/
│   ├── app/
│   │   ├── api/          # Rutas FastAPI (instituciones, documentos, chat, admin)
│   │   ├── core/         # chunking, embeddings, vector_store, llm
│   │   ├── services/     # parsing, ingesta, rag
│   │   ├── db/           # persistencia de metadatos (SQLAlchemy)
│   │   ├── context.py    # contenedor de dependencias
│   │   └── main.py       # aplicación FastAPI
│   └── tests/            # suite pytest
└── frontend/
    └── src/
        ├── api/          # cliente + tipos
        └── components/   # Sidebar, ChatView, SourcesPanel, Library, Admin…
```

---

## 📝 Licencia

MVP de demostración. Construido con software open source.
