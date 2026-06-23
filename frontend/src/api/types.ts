export interface Institution {
  id: string;
  name: string;
  description: string;
  document_count: number;
  created_at: string;
}

export type DocumentStatus = "pending" | "processing" | "indexed" | "failed";

export interface DocumentItem {
  id: string;
  institution_id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  status: DocumentStatus;
  chunk_count: number;
  error?: string | null;
  uploaded_at: string;
}

export interface SourceChunk {
  document_id: string;
  filename: string;
  chunk_index: number;
  text: string;
  score: number;
}

export interface ChatResponse {
  answer: string;
  sources: SourceChunk[];
  used_llm: boolean;
}

export interface Stats {
  institution_id: string;
  document_count: number;
  indexed_documents: number;
  chunk_count: number;
  total_size_bytes: number;
  status_breakdown: Record<string, number>;
}

export interface Health {
  status: string;
  uses_llm: boolean;
  embedding_provider: string;
  embedding_dim: number;
}
