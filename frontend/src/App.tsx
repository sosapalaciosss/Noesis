import { useEffect, useState } from "react";
import { Sidebar, type View } from "./components/Sidebar";
import { ChatView } from "./components/ChatView";
import { LibraryView } from "./components/LibraryView";
import { AdminView } from "./components/AdminView";
import { NewInstitutionModal } from "./components/NewInstitutionModal";
import { api } from "./api/client";
import type { Institution } from "./api/types";

export default function App() {
  const [view, setView] = useState<View>("chat");
  const [institutions, setInstitutions] = useState<Institution[]>([]);
  const [activeInstitution, setActiveInstitution] = useState<string>("");
  const [usesLlm, setUsesLlm] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [ready, setReady] = useState(false);

  async function refreshInstitutions(): Promise<Institution[]> {
    const list = await api.listInstitutions();
    setInstitutions(list);
    return list;
  }

  useEffect(() => {
    (async () => {
      try {
        const [list, health] = await Promise.all([
          refreshInstitutions(),
          api.health().catch(() => null),
        ]);
        if (health) setUsesLlm(health.uses_llm);
        if (list.length > 0) setActiveInstitution(list[0].id);
      } finally {
        setReady(true);
      }
    })();
  }, []);

  if (!ready) {
    return (
      <div className="grid h-screen place-items-center bg-navy-950 text-white">
        <div className="flex flex-col items-center gap-3">
          <div className="h-8 w-8 animate-spin rounded-full border-2 border-white/20 border-t-white" />
          <p className="text-sm text-brand-200/70">Iniciando Noesis…</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50">
      <Sidebar
        view={view}
        onChangeView={setView}
        institutions={institutions}
        activeInstitution={activeInstitution}
        onChangeInstitution={setActiveInstitution}
        onCreateInstitution={() => setShowModal(true)}
        usesLlm={usesLlm}
      />

      <main className="flex min-w-0 flex-1 flex-col">
        {activeInstitution && view === "chat" && (
          <ChatView institutionId={activeInstitution} />
        )}
        {activeInstitution && view === "library" && (
          <LibraryView key={activeInstitution} institutionId={activeInstitution} />
        )}
        {activeInstitution && view === "admin" && (
          <AdminView key={activeInstitution} institutionId={activeInstitution} />
        )}
      </main>

      {showModal && (
        <NewInstitutionModal
          onClose={() => setShowModal(false)}
          onCreated={async (inst) => {
            await refreshInstitutions();
            setActiveInstitution(inst.id);
            setShowModal(false);
            setView("library");
          }}
        />
      )}
    </div>
  );
}
