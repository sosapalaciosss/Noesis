"""Rutas de gestión de instituciones (multi-institución)."""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException

from ..context import AppContext
from ..models.schemas import InstitutionCreate, InstitutionOut
from .deps import context

router = APIRouter(prefix="/api/institutions", tags=["institutions"])

_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{1,62}$")


def _to_out(ctx: AppContext, inst) -> InstitutionOut:
    return InstitutionOut(
        id=inst.id,
        name=inst.name,
        description=inst.description,
        document_count=ctx.store.count_documents(inst.id),
        created_at=inst.created_at,
    )


@router.get("", response_model=list[InstitutionOut])
def list_institutions(ctx: AppContext = Depends(context)):
    return [_to_out(ctx, i) for i in ctx.store.list_institutions()]


@router.post("", response_model=InstitutionOut, status_code=201)
def create_institution(payload: InstitutionCreate, ctx: AppContext = Depends(context)):
    if not _SLUG_RE.match(payload.id):
        raise HTTPException(
            status_code=422,
            detail="El id debe ser un slug en minúsculas (letras, números, - o _).",
        )
    try:
        inst = ctx.store.create_institution(payload.id, payload.name, payload.description)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return _to_out(ctx, inst)
