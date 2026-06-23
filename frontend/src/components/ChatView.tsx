import { useEffect, useRef, useState } from "react";
import { SendHorizonal, Sparkles, FileText } from "lucide-react";
import ReactMarkdown from "react-markdown";
import { api } from "../api/client";
import type { SourceChunk } from "../api/types";
import { SourcesPanel } from "./SourcesPanel";

interface Message {
  role: "user" | "assistant";
  content: string;
  sources?: SourceChunk[];
  usedLlm?: boolean;
}

const SUGGESTIONS = [
  "¿Cuál es el objetivo principal de la institución?",
  "Resume los documentos disponibles.",
  "¿Qué procedimientos se describen en los documentos?",
];

export function ChatView({ institutionId }: { institutionId: string }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [activeSources, setActiveSources] = useState<SourceChunk[]>([]);
  const scrollRef = useRef<HTMLDivElement>(null);

  // Reinicia la conversación al cambiar de institución.
  useEffect(() => {
    setMessages([]);
    setActiveSources([]);
  }, [institutionId]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, loading]);

  async function send(question: string) {
    const q = question.trim();
    if (!q || loading) return;
    setInput("");
    setMessages((m) => [...m, { role: "user", content: q }]);
    setLoading(true);
    setActiveSources([]);
    try {
      const res = await api.chat(institutionId, q);
      setMessages((m) => [
        ...m,
        { role: "assistant", content: res.answer, sources: res.sources, usedLlm: res.used_llm },
      ]);
      setActiveSources(res.sources);
    } catch (e) {
      setMessages((m) => [
        ...m,
        { role: "assistant", content: `⚠️ ${(e as Error).message}` },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex h-full min-w-0 flex-1">
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Encabezado */}
        <header className="flex items-center justify-between border-b border-slate-200 bg-white/80 px-8 py-4 backdrop-blur">
          <div>
            <h1 className="text-base font-bold text-navy-900">Chat institucional</h1>
            <p className="text-xs text-slate-500">
              Respuestas fundamentadas en los documentos cargados (RAG)
            </p>
          </div>
        </header>

        {/* Historial */}
        <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-6 sm:px-8">
          <div className="mx-auto max-w-3xl space-y-6">
            {messages.length === 0 && !loading && (
              <Welcome onPick={send} />
            )}

            {messages.map((m, i) => (
              <MessageBubble key={i} message={m} />
            ))}

            {loading && <TypingBubble />}
          </div>
        </div>

        {/* Entrada */}
        <div className="border-t border-slate-200 bg-white px-4 py-4 sm:px-8">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              send(input);
            }}
            className="mx-auto flex max-w-3xl items-end gap-3"
          >
            <div className="relative flex-1">
              <textarea
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    send(input);
                  }
                }}
                rows={1}
                placeholder="Escribe tu pregunta…"
                className="max-h-40 w-full resize-none rounded-2xl border border-slate-300 bg-slate-50 px-4 py-3 pr-12 text-sm text-slate-800 outline-none transition focus:border-brand-400 focus:bg-white focus:ring-4 focus:ring-brand-100"
              />
            </div>
            <button type="submit" disabled={loading || !input.trim()} className="btn-primary h-12 w-12 !px-0">
              <SendHorizonal size={18} />
            </button>
          </form>
          <p className="mx-auto mt-2 max-w-3xl text-center text-[11px] text-slate-400">
            Noesis puede cometer errores. Verifica la información con las fuentes citadas.
          </p>
        </div>
      </div>

      <SourcesPanel sources={activeSources} loading={loading} />
    </div>
  );
}

function Welcome({ onPick }: { onPick: (q: string) => void }) {
  return (
    <div className="animate-fade-up py-8 text-center">
      <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-gradient-to-br from-brand-500 to-brand-700 shadow-lg shadow-brand-900/20">
        <Sparkles className="text-white" size={26} />
      </div>
      <h2 className="mt-5 text-xl font-bold text-navy-900">
        ¿En qué puedo ayudarte hoy?
      </h2>
      <p className="mx-auto mt-2 max-w-md text-sm text-slate-500">
        Pregunta en lenguaje natural sobre los documentos de esta institución.
        Cada respuesta incluye sus fuentes verificables.
      </p>
      <div className="mx-auto mt-8 grid max-w-2xl gap-3 sm:grid-cols-3">
        {SUGGESTIONS.map((s) => (
          <button
            key={s}
            onClick={() => onPick(s)}
            className="card flex flex-col gap-2 p-4 text-left transition hover:-translate-y-0.5 hover:border-brand-300 hover:shadow-panel"
          >
            <FileText size={16} className="text-brand-600" />
            <span className="text-sm font-medium text-slate-700">{s}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function MessageBubble({ message }: { message: Message }) {
  const isUser = message.role === "user";
  return (
    <div className={`flex animate-fade-up gap-3 ${isUser ? "justify-end" : "justify-start"}`}>
      {!isUser && (
        <div className="mt-0.5 grid h-8 w-8 flex-shrink-0 place-items-center rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 text-white">
          <Sparkles size={15} />
        </div>
      )}
      <div
        className={
          isUser
            ? "max-w-[80%] rounded-2xl rounded-br-md bg-brand-600 px-4 py-3 text-sm text-white shadow-soft"
            : "max-w-[85%] rounded-2xl rounded-bl-md border border-slate-200 bg-white px-5 py-4 text-sm text-slate-700 shadow-soft"
        }
      >
        {isUser ? (
          message.content
        ) : (
          <div className="prose-chat">
            <ReactMarkdown>{message.content}</ReactMarkdown>
            {message.sources && message.sources.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-1.5 border-t border-slate-100 pt-3">
                {message.sources.map((s, idx) => (
                  <span
                    key={`${s.document_id}-${s.chunk_index}`}
                    title={s.filename}
                    className="inline-flex items-center gap-1 rounded-full bg-brand-50 px-2 py-0.5 text-[11px] font-medium text-brand-700 ring-1 ring-brand-100"
                  >
                    <span className="font-bold">[{idx + 1}]</span>
                    <span className="max-w-[140px] truncate">{s.filename}</span>
                  </span>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function TypingBubble() {
  return (
    <div className="flex animate-fade-up gap-3">
      <div className="mt-0.5 grid h-8 w-8 flex-shrink-0 place-items-center rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 text-white">
        <Sparkles size={15} />
      </div>
      <div className="rounded-2xl rounded-bl-md border border-slate-200 bg-white px-5 py-4 shadow-soft">
        <div className="flex items-center gap-1.5">
          <span className="typing-dot h-2 w-2 rounded-full bg-brand-400" />
          <span className="typing-dot h-2 w-2 rounded-full bg-brand-400" />
          <span className="typing-dot h-2 w-2 rounded-full bg-brand-400" />
        </div>
      </div>
    </div>
  );
}
