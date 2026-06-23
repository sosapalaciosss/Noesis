import { MessageSquare, Library, LayoutDashboard, Building2, ChevronDown } from "lucide-react";
import { Logo } from "./Logo";
import type { Institution } from "../api/types";

export type View = "chat" | "library" | "admin";

const NAV: { key: View; label: string; icon: typeof MessageSquare; hint: string }[] = [
  { key: "chat", label: "Chat institucional", icon: MessageSquare, hint: "Pregunta en lenguaje natural" },
  { key: "library", label: "Biblioteca", icon: Library, hint: "Documentos cargados" },
  { key: "admin", label: "Administración", icon: LayoutDashboard, hint: "Gestión y estadísticas" },
];

interface Props {
  view: View;
  onChangeView: (v: View) => void;
  institutions: Institution[];
  activeInstitution: string;
  onChangeInstitution: (id: string) => void;
  onCreateInstitution: () => void;
  usesLlm: boolean;
}

export function Sidebar({
  view,
  onChangeView,
  institutions,
  activeInstitution,
  onChangeInstitution,
  onCreateInstitution,
  usesLlm,
}: Props) {
  const active = institutions.find((i) => i.id === activeInstitution);

  return (
    <aside className="flex h-full w-72 flex-shrink-0 flex-col bg-gradient-to-b from-navy-900 to-navy-950 text-white">
      <div className="px-6 pt-7 pb-6">
        <Logo />
      </div>

      {/* Selector de institución */}
      <div className="px-4">
        <label className="mb-2 block px-2 text-[11px] font-semibold uppercase tracking-wider text-brand-200/60">
          Espacio de conocimiento
        </label>
        <div className="relative">
          <Building2
            size={16}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-brand-200/70"
          />
          <select
            value={activeInstitution}
            onChange={(e) => onChangeInstitution(e.target.value)}
            className="w-full appearance-none rounded-xl border border-white/10 bg-white/5 py-2.5 pl-9 pr-9 text-sm font-medium text-white outline-none transition focus:border-brand-400 focus:bg-white/10"
          >
            {institutions.map((i) => (
              <option key={i.id} value={i.id} className="text-slate-900">
                {i.name}
              </option>
            ))}
          </select>
          <ChevronDown
            size={16}
            className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-brand-200/70"
          />
        </div>
        <button
          onClick={onCreateInstitution}
          className="mt-2 w-full rounded-lg px-2 py-1.5 text-left text-xs font-medium text-brand-200/70 transition hover:text-white"
        >
          + Nueva institución
        </button>
      </div>

      <div className="mx-4 my-5 h-px bg-white/10" />

      {/* Navegación */}
      <nav className="flex-1 space-y-1 px-4">
        {NAV.map(({ key, label, icon: Icon, hint }) => (
          <button
            key={key}
            onClick={() => onChangeView(key)}
            className={`nav-item w-full text-left ${view === key ? "nav-item-active" : ""}`}
          >
            <Icon size={18} className="flex-shrink-0" />
            <span className="flex flex-col">
              <span>{label}</span>
              <span className="text-[11px] font-normal text-brand-200/50">{hint}</span>
            </span>
          </button>
        ))}
      </nav>

      {/* Pie: estado del modelo */}
      <div className="px-6 pb-6 pt-4">
        <div className="rounded-xl border border-white/10 bg-white/5 px-3.5 py-3">
          <div className="flex items-center gap-2">
            <span
              className={`h-2 w-2 rounded-full ${usesLlm ? "bg-emerald-400" : "bg-amber-400"}`}
            />
            <span className="text-xs font-medium text-white/90">
              {usesLlm ? "Mistral conectado" : "Modo extractivo"}
            </span>
          </div>
          <p className="mt-1 text-[11px] leading-snug text-brand-200/50">
            {active ? `${active.document_count} documento(s) en este espacio` : ""}
          </p>
        </div>
      </div>
    </aside>
  );
}
