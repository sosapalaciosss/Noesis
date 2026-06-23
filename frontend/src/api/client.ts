import type {
  ChatResponse,
  DocumentItem,
  Health,
  Institution,
  Stats,
} from "./types";

// En desarrollo Vite redirige /api al backend; en producción se sirve junto.
const BASE = import.meta.env.VITE_API_URL || "";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json", ...(init?.headers || {}) },
    ...init,
  });
  if (!res.ok) {
    let detail = `Error ${res.status}`;
    try {
      const body = await res.json();
      detail = body.detail || detail;
    } catch {
      /* sin cuerpo JSON */
    }
    throw new Error(detail);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

const q = (instId: string) => `institution_id=${encodeURIComponent(instId)}`;

export const api = {
  health: () => request<Health>("/api/health"),

  // Instituciones
  listInstitutions: () => request<Institution[]>("/api/institutions"),
  createInstitution: (payload: { id: string; name: string; description?: string }) =>
    request<Institution>("/api/institutions", {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  // Documentos
  listDocuments: (instId: string) =>
    request<DocumentItem[]>(`/api/documents?${q(instId)}`),

  uploadDocument: async (instId: string, file: File): Promise<DocumentItem> => {
    const form = new FormData();
    form.append("file", file);
    const res = await fetch(`${BASE}/api/documents?${q(instId)}`, {
      method: "POST",
      body: form,
    });
    if (!res.ok) {
      let detail = `Error ${res.status}`;
      try {
        detail = (await res.json()).detail || detail;
      } catch {
        /* */
      }
      throw new Error(detail);
    }
    return res.json();
  },

  // Chat
  chat: (instId: string, question: string) =>
    request<ChatResponse>(`/api/chat?${q(instId)}`, {
      method: "POST",
      body: JSON.stringify({ question }),
    }),

  // Admin
  stats: (instId: string) => request<Stats>(`/api/admin/stats?${q(instId)}`),
  deleteDocument: (docId: string) =>
    request<void>(`/api/admin/documents/${docId}`, { method: "DELETE" }),
  reindexDocument: (docId: string) =>
    request<DocumentItem>(`/api/admin/documents/${docId}/reindex`, {
      method: "POST",
    }),
};
