import { useRef, useState } from "react";
import { UploadCloud, Loader2 } from "lucide-react";
import { api } from "../api/client";

interface Props {
  institutionId: string;
  onUploaded: () => void;
}

const ACCEPT = ".pdf,.docx,.txt,.md";

export function UploadZone({ institutionId, onUploaded }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    setBusy(true);
    setError(null);
    try {
      for (const file of Array.from(files)) {
        await api.uploadDocument(institutionId, file);
      }
      onUploaded();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <div>
      <div
        onClick={() => !busy && inputRef.current?.click()}
        onDragOver={(e) => {
          e.preventDefault();
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          handleFiles(e.dataTransfer.files);
        }}
        className={`flex cursor-pointer flex-col items-center justify-center rounded-2xl border-2 border-dashed px-6 py-10 text-center transition ${
          dragOver
            ? "border-brand-400 bg-brand-50"
            : "border-slate-300 bg-slate-50/50 hover:border-brand-300 hover:bg-brand-50/40"
        }`}
      >
        <div className="grid h-12 w-12 place-items-center rounded-full bg-brand-100 text-brand-700">
          {busy ? <Loader2 size={22} className="animate-spin" /> : <UploadCloud size={22} />}
        </div>
        <p className="mt-3 text-sm font-semibold text-navy-800">
          {busy ? "Subiendo y procesando…" : "Arrastra documentos aquí o haz clic para subir"}
        </p>
        <p className="mt-1 text-xs text-slate-500">
          PDF, DOCX, TXT o MD · se procesan e indexan automáticamente
        </p>
      </div>
      {error && <p className="mt-2 text-xs font-medium text-rose-600">{error}</p>}
      <input
        ref={inputRef}
        type="file"
        accept={ACCEPT}
        multiple
        className="hidden"
        onChange={(e) => handleFiles(e.target.files)}
      />
    </div>
  );
}
