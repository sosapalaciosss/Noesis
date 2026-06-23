"""Integración con el modelo Mistral con un respaldo extractivo.

Si hay `MISTRAL_API_KEY`, se genera la respuesta con Mistral. En caso
contrario, se devuelve una respuesta extractiva construida a partir de los
fragmentos recuperados, de modo que la plataforma siga siendo funcional sin
credenciales (útil para demos locales y pruebas).
"""
from __future__ import annotations

from typing import List, Tuple

SYSTEM_PROMPT = (
    "Eres Noesis, el asistente de conocimiento institucional del Estado "
    "salvadoreño. Respondes únicamente con base en los fragmentos de contexto "
    "proporcionados. Si la respuesta no está en el contexto, indícalo con "
    "claridad y no inventes información. Cita las fuentes usando la notación "
    "[n] que aparece junto a cada fragmento. Responde en español, de forma "
    "clara, formal y concisa."
)


def build_context_block(sources: List[dict]) -> str:
    blocks = []
    for i, s in enumerate(sources, start=1):
        blocks.append(f"[{i}] (Documento: {s['filename']})\n{s['text']}")
    return "\n\n".join(blocks)


class MistralLLM:
    def __init__(self, api_key: str, model: str):
        from mistralai import Mistral

        self._client = Mistral(api_key=api_key)
        self._model = model

    def generate(self, question: str, sources: List[dict]) -> str:
        context = build_context_block(sources)
        user_msg = (
            f"Contexto:\n{context}\n\n"
            f"Pregunta: {question}\n\n"
            "Responde citando las fuentes con [n]."
        )
        resp = self._client.chat.complete(
            model=self._model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_msg},
            ],
            temperature=0.2,
        )
        return resp.choices[0].message.content.strip()


class FallbackLLM:
    """Respuesta extractiva sin LLM externo."""

    def generate(self, question: str, sources: List[dict]) -> str:
        if not sources:
            return (
                "No se encontró información relevante en los documentos indexados "
                "para responder a esta pregunta."
            )
        lines = [
            "Con base en los documentos institucionales, los fragmentos más "
            "relevantes encontrados son:",
            "",
        ]
        for i, s in enumerate(sources, start=1):
            snippet = s["text"].strip().replace("\n", " ")
            if len(snippet) > 320:
                snippet = snippet[:320].rsplit(" ", 1)[0] + "…"
            lines.append(f"[{i}] {snippet}")
        lines.append("")
        lines.append(
            "(Respuesta generada en modo extractivo. Configure MISTRAL_API_KEY "
            "para obtener respuestas redactadas por el modelo Mistral.)"
        )
        return "\n".join(lines)


def build_llm(api_key: str, model: str) -> Tuple[object, bool]:
    """Devuelve (instancia_llm, usa_llm_real)."""
    if api_key:
        try:
            return MistralLLM(api_key=api_key, model=model), True
        except Exception:
            return FallbackLLM(), False
    return FallbackLLM(), False
