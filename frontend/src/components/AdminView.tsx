import { useCallback, useEffect, useState } from "react";
import { FileStack, Boxes, CheckCircle2, HardDrive, RefreshCw, Trash2, RotateCw } from "lucide-react";
import { api } from "../api/client";
import type { DocumentItem, Stats } from "../api/types";
import { formatBytes, formatDate } from "../lib/format";
import { StatusBadge } from "./StatusBadge";

export function AdminView({ institutionId }: { institutionId: string }) {
  const [stats, setStats] = useState<Stats | null>(null);
  const [docs, setDocs] = useState<DocumentItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [s, d] = await Promise.all([
      api.stats(institutionId),
      api.listDocuments(institutionId),
    ]);
    setStats(s);
    setDocs(d);
    setLoading(false);
  }, [institutionId]);

  useEffect(() => {
    setLoading(true);
    load();
  }, [load]);

  useEffect(() => {
    const pending = docs.some((d) => d.status === "pending" || d.status === "processing");
    if (!pending) return;
    const t = setInterval(load, 1500);
    return () => clearInterval(t);
  }, [docs, load]);

  async function onDelete(id: string, name: string) {
    if (!confirm(`¿Eliminar "${name}"? Esta acción no se puede deshacer.`)) return;
    setBusyId(id);
    try {
      await api.deleteDocument(id);
      await load();
    } finally {
      setBusyId(null);
    }
  }

  async function onReindex(id: string) {
    setBusyId(id);
    try {
      await api.reindexDocument(id);
      await load();
    } finally {
      setBusyId(null);
    }
  }

  const cards = [
    { label: "Documentos", value: stats?.document_count ?? 0, icon: FileStack, color: "text-brand-600 bg-brand-50" },
    { label: "Indexados", value: stats?.indexed_documents ?? 0, icon: CheckCircle2, color: "text-emerald-600 bg-emerald-50" },
    { label: "Fragmentos", value: stats?.chunk_count ?? 0, icon: Boxes, color: "text-violet-600 bg-violet-50" },
    { label: "Almacenamiento", value: formatBytes(stats?.total_size_bytes ?? 0), icon: HardDrive, color: "text-amber-600 bg-amber-50" },
  ];

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-5xl px-8 py-8">
        <header className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-navy-900">Panel administrativo</h1>
            <p className="text-sm text-slate-500">Gestión de documentos y estadísticas</p>
          </div>
          <button onClick={load} className="btn-ghost">
            <RefreshCw size={16} /> Actualizar
          </button>
        </header>

        {/* Tarjetas de estadísticas */}
        <div className="mb-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {cards.map((c) => (
            <div key={c.label} className="card p-5">
              <div className={`grid h-10 w-10 place-items-center rounded-xl ${c.color}`}>
                <c.icon size={18} />
              </div>
              <p className="mt-3 text-2xl font-extrabold text-navy-900">
                {loading ? "—" : c.value}
              </p>
              <p className="text-xs font-medium text-slate-500">{c.label}</p>
            </div>
          ))}
        </div>

        {/* Tabla de gestión */}
        <div className="card overflow-hidden">
          <div className="border-b border-slate-200 px-5 py-3.5">
            <h2 className="text-sm font-bold text-navy-800">Documentos</h2>
          </div>
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50/60 text-xs uppercase tracking-wide text-slate-500">
                <th className="px-5 py-3 font-semibold">Documento</th>
                <th className="px-5 py-3 font-semibold">Estado</th>
                <th className="px-5 py-3 font-semibold">Cargado</th>
                <th className="px-5 py-3 text-right font-semibold">Acciones</th>
              </tr>
            </thead>
            <tbody>
              {!loading && docs.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-5 py-12 text-center text-slate-400">
                    No hay documentos en este espacio.
                  </td>
                </tr>
              )}
              {docs.map((d) => (
                <tr key={d.id} className="border-b border-slate-100 last:border-0 hover:bg-slate-50/60">
                  <td className="px-5 py-3.5">
                    <span className="block truncate font-medium text-navy-800" title={d.filename}>
                      {d.filename}
                    </span>
                    <span className="text-xs text-slate-400">{formatBytes(d.size_bytes)} · {d.chunk_count} fragmentos</span>
                  </td>
                  <td className="px-5 py-3.5">
                    <StatusBadge status={d.status} />
                  </td>
                  <td className="px-5 py-3.5 text-slate-500">{formatDate(d.uploaded_at)}</td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center justify-end gap-1">
                      <button
                        onClick={() => onReindex(d.id)}
                        disabled={busyId === d.id}
                        className="rounded-lg p-2 text-slate-400 transition hover:bg-brand-50 hover:text-brand-600 disabled:opacity-40"
                        title="Reindexar"
                      >
                        <RotateCw size={16} className={busyId === d.id ? "animate-spin" : ""} />
                      </button>
                      <button
                        onClick={() => onDelete(d.id, d.filename)}
                        disabled={busyId === d.id}
                        className="rounded-lg p-2 text-slate-400 transition hover:bg-rose-50 hover:text-rose-600 disabled:opacity-40"
                        title="Eliminar"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
