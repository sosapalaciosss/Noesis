import { CheckCircle2, Clock, Loader2, AlertTriangle } from "lucide-react";
import type { DocumentStatus } from "../api/types";
import { statusLabels } from "../lib/format";

const styles: Record<DocumentStatus, string> = {
  indexed: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
  processing: "bg-amber-50 text-amber-700 ring-amber-600/20",
  pending: "bg-slate-100 text-slate-600 ring-slate-500/20",
  failed: "bg-rose-50 text-rose-700 ring-rose-600/20",
};

export function StatusBadge({ status }: { status: DocumentStatus }) {
  const Icon =
    status === "indexed"
      ? CheckCircle2
      : status === "processing"
        ? Loader2
        : status === "failed"
          ? AlertTriangle
          : Clock;
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset ${styles[status]}`}
    >
      <Icon
        size={13}
        className={status === "processing" ? "animate-spin" : ""}
      />
      {statusLabels[status] ?? status}
    </span>
  );
}
