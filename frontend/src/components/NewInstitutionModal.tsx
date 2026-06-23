import { useState } from "react";
import { X, Building2 } from "lucide-react";
import { api } from "../api/client";
import type { Institution } from "../api/types";

interface Props {
  onClose: () => void;
  onCreated: (inst: Institution) => void;
}

function slugify(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 60);
}

export function NewInstitutionModal({ onClose, onCreated }: Props) {
  const [name, setName] = useState("");
  const [id, setId] = useState("");
  const [description, setDescription] = useState("");
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const effectiveId = touched ? id : slugify(name);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const inst = await api.createInstitution({
        id: effectiveId,
        name: name.trim(),
        description: description.trim(),
      });
      onCreated(inst);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-navy-950/40 p-4 backdrop-blur-sm">
      <div className="card w-full max-w-md animate-fade-up p-6 shadow-panel">
        <div className="mb-5 flex items-start justify-between">
          <div className="flex items-center gap-3">
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-brand-50 text-brand-600">
              <Building2 size={18} />
            </span>
            <div>
              <h2 className="text-base font-bold text-navy-900">Nueva institución</h2>
              <p className="text-xs text-slate-500">Crea un espacio de conocimiento aislado</p>
            </div>
          </div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={submit} className="space-y-4">
          <Field label="Nombre">
            <input
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ministerio de Hacienda"
              className="input"
              required
            />
          </Field>
          <Field label="Identificador (slug)">
            <input
              value={effectiveId}
              onChange={(e) => {
                setTouched(true);
                setId(slugify(e.target.value));
              }}
              placeholder="ministerio_hacienda"
              className="input font-mono text-xs"
              required
            />
          </Field>
          <Field label="Descripción (opcional)">
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              placeholder="Breve descripción de la entidad"
              className="input resize-none"
            />
          </Field>

          {error && <p className="text-xs font-medium text-rose-600">{error}</p>}

          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={onClose} className="btn-ghost">
              Cancelar
            </button>
            <button type="submit" disabled={busy || !name.trim() || !effectiveId} className="btn-primary">
              {busy ? "Creando…" : "Crear institución"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-semibold text-slate-600">{label}</span>
      {children}
    </label>
  );
}
