import { useEffect, useState, useCallback } from "react";
import { FileText, RefreshCw } from "lucide-react";
import { api } from "../api/client";
import type { DocumentItem } from "../api/types";
import { formatBytes, formatDate } from "../lib/format";
import { StatusBadge } from "./StatusBadge";
import { UploadZone } from "./UploadZone";

export function LibraryView({ institutionId }: { institutionId: string }) {
  const [docs, setDocs] = useState<DocumentItem[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      setDocs(await api.listDocuments(institutionId));
    } finally {
      setLoading(false);
    }
  }, [institutionId]);

  useEffect(() => {
    setLoading(true);
    load();
  }, [load]);

  // Sondea mientras haya documentos en proceso.
  useEffect(() => {
    const pending = docs.some((d) => d.status === "pending" || d.status === "processing");
    if (!pending) return;
    const t = setInterval(load, 1500);
    return () => clearInterval(t);
  }, [docs, load]);

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-5xl px-8 py-8">
        <header className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-navy-900">Biblioteca documental</h1>
            <p className="text-sm text-slate-500">
              Documentos cargados en este espacio de conocimiento
            </p>
          </div>
          <button onClick={load} className="btn-ghost" title="Actualizar">
            <RefreshCw size={16} /> Actualizar
          </button>
        </header>

        <div className="mb-8">
          <UploadZone institutionId={institutionId} onUploaded={load} />
        </div>

        <div className="card overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50/60 text-xs uppercase tracking-wide text-slate-500">
                <th className="px-5 py-3 font-semibold">Documento</th>
                <th className="px-5 py-3 font-semibold">Tamaño</th>
                <th className="px-5 py-3 font-semibold">Fragmentos</th>
                <th className="px-5 py-3 font-semibold">Estado</th>
                <th className="px-5 py-3 font-semibold">Cargado</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td colSpan={5} className="px-5 py-10 text-center text-slate-400">
                    Cargando…
                  </td>
                </tr>
              )}
              {!loading && docs.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-5 py-12 text-center text-slate-400">
                    Aún no hay documentos. Sube el primero para comenzar.
                  </td>
                </tr>
              )}
              {docs.map((d) => (
                <tr
                  key={d.id}
                  className="border-b border-slate-100 last:border-0 transition hover:bg-slate-50/60"
                >
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-3">
                      <span className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-lg bg-brand-50 text-brand-600">
                        <FileText size={16} />
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate font-medium text-navy-800" title={d.filename}>
                          {d.filename}
                        </span>
                        {d.error && (
                          <span className="block truncate text-xs text-rose-500" title={d.error}>
                            {d.error}
                          </span>
                        )}
                      </span>
                    </div>
                  </td>
                  <td className="px-5 py-3.5 text-slate-600">{formatBytes(d.size_bytes)}</td>
                  <td className="px-5 py-3.5 text-slate-600">{d.chunk_count}</td>
                  <td className="px-5 py-3.5">
                    <StatusBadge status={d.status} />
                  </td>
                  <td className="px-5 py-3.5 text-slate-500">{formatDate(d.uploaded_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
