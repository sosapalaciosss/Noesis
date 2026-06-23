import { FileText, Quote } from "lucide-react";
import type { SourceChunk } from "../api/types";

interface Props {
  sources: SourceChunk[];
  loading: boolean;
}

export function SourcesPanel({ sources, loading }: Props) {
  return (
    <aside className="hidden w-80 flex-shrink-0 flex-col border-l border-slate-200 bg-white xl:flex">
      <div className="border-b border-slate-200 px-5 py-4">
        <h2 className="flex items-center gap-2 text-sm font-bold text-navy-800">
          <Quote size={16} className="text-brand-600" />
          Fuentes citadas
        </h2>
        <p className="mt-0.5 text-xs text-slate-500">
          Fragmentos utilizados para la respuesta
        </p>
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-4">
        {loading && (
          <div className="space-y-3">
            {[0, 1, 2].map((i) => (
              <div key={i} className="animate-pulse rounded-xl border border-slate-100 p-4">
                <div className="mb-2 h-3 w-1/2 rounded bg-slate-200" />
                <div className="h-3 w-full rounded bg-slate-100" />
                <div className="mt-1.5 h-3 w-4/5 rounded bg-slate-100" />
              </div>
            ))}
          </div>
        )}

        {!loading && sources.length === 0 && (
          <div className="mt-10 flex flex-col items-center px-4 text-center">
            <div className="grid h-12 w-12 place-items-center rounded-full bg-slate-100">
              <FileText size={20} className="text-slate-400" />
            </div>
            <p className="mt-3 text-sm text-slate-500">
              Las fuentes aparecerán aquí cuando hagas una pregunta.
            </p>
          </div>
        )}

        <div className="space-y-3">
          {sources.map((s, idx) => (
            <article
              key={`${s.document_id}-${s.chunk_index}`}
              className="animate-fade-up rounded-xl border border-slate-200 bg-slate-50/50 p-4 transition hover:border-brand-300 hover:shadow-soft"
            >
              <div className="mb-2 flex items-center justify-between gap-2">
                <span className="flex min-w-0 items-center gap-1.5 text-xs font-semibold text-navy-800">
                  <span className="grid h-5 w-5 flex-shrink-0 place-items-center rounded-md bg-brand-600 text-[10px] font-bold text-white">
                    {idx + 1}
                  </span>
                  <span className="truncate" title={s.filename}>
                    {s.filename}
                  </span>
                </span>
                <span className="flex-shrink-0 rounded-full bg-white px-2 py-0.5 text-[10px] font-medium text-slate-500 ring-1 ring-slate-200">
                  {(s.score * 100).toFixed(0)}%
                </span>
              </div>
              <p className="text-xs leading-relaxed text-slate-600 line-clamp-6">
                {s.text}
              </p>
            </article>
          ))}
        </div>
      </div>
    </aside>
  );
}
