"""Dependencias compartidas de la API."""
from __future__ import annotations

from fastapi import Depends, HTTPException, Query

from ..context import AppContext, get_context


def context() -> AppContext:
    return get_context()


def institution_id(
    institution_id: str = Query(
        default=None, description="Identificador de la institución (espacio de conocimiento)"
    ),
    ctx: AppContext = Depends(context),
) -> str:
    inst_id = institution_id or ctx.settings.default_institution_id
    if ctx.store.get_institution(inst_id) is None:
        raise HTTPException(status_code=404, detail=f"Institución '{inst_id}' no encontrada")
    return inst_id
