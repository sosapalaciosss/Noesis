"""Capa de persistencia de metadatos (SQLite vía SQLAlchemy).

Guarda instituciones y documentos. Los vectores viven en Qdrant; aquí solo
se almacena lo necesario para la biblioteca documental y el panel admin.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import (
    Integer,
    String,
    Text,
    DateTime,
    ForeignKey,
    create_engine,
    func,
)
from sqlalchemy.orm import (
    DeclarativeBase,
    Mapped,
    mapped_column,
    relationship,
    sessionmaker,
    Session,
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Institution(Base):
    __tablename__ = "institutions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    documents: Mapped[List["Document"]] = relationship(
        back_populates="institution", cascade="all, delete-orphan"
    )


class Document(Base):
    __tablename__ = "documents"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    institution_id: Mapped[str] = mapped_column(
        ForeignKey("institutions.id", ondelete="CASCADE"), index=True
    )
    filename: Mapped[str] = mapped_column(String(512), nullable=False)
    content_type: Mapped[str] = mapped_column(String(128), default="")
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    chunk_count: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    storage_path: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    institution: Mapped[Institution] = relationship(back_populates="documents")


class MetadataStore:
    """Pequeño repositorio que envuelve el acceso a la base de metadatos."""

    def __init__(self, database_url: str):
        connect_args = {}
        if database_url.startswith("sqlite"):
            connect_args = {"check_same_thread": False}
            # Asegura que el directorio del archivo exista.
            path = database_url.replace("sqlite:///", "")
            if path and path not in (":memory:",):
                os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        self.engine = create_engine(database_url, connect_args=connect_args, future=True)
        self._Session = sessionmaker(bind=self.engine, expire_on_commit=False, future=True)
        Base.metadata.create_all(self.engine)

    def session(self) -> Session:
        return self._Session()

    # --- Instituciones ----------------------------------------------------- #
    def ensure_institution(self, inst_id: str, name: str, description: str = "") -> Institution:
        with self.session() as s:
            inst = s.get(Institution, inst_id)
            if inst is None:
                inst = Institution(id=inst_id, name=name, description=description)
                s.add(inst)
                s.commit()
                s.refresh(inst)
            return inst

    def create_institution(self, inst_id: str, name: str, description: str = "") -> Institution:
        with self.session() as s:
            if s.get(Institution, inst_id) is not None:
                raise ValueError(f"La institución '{inst_id}' ya existe")
            inst = Institution(id=inst_id, name=name, description=description)
            s.add(inst)
            s.commit()
            s.refresh(inst)
            return inst

    def list_institutions(self) -> List[Institution]:
        with self.session() as s:
            return list(s.query(Institution).order_by(Institution.created_at).all())

    def get_institution(self, inst_id: str) -> Optional[Institution]:
        with self.session() as s:
            return s.get(Institution, inst_id)

    def count_documents(self, inst_id: str) -> int:
        with self.session() as s:
            return (
                s.query(func.count(Document.id))
                .filter(Document.institution_id == inst_id)
                .scalar()
                or 0
            )

    # --- Documentos -------------------------------------------------------- #
    def create_document(self, **kwargs) -> Document:
        with self.session() as s:
            doc = Document(**kwargs)
            s.add(doc)
            s.commit()
            s.refresh(doc)
            return doc

    def update_document(self, doc_id: str, **fields) -> Optional[Document]:
        with self.session() as s:
            doc = s.get(Document, doc_id)
            if doc is None:
                return None
            for k, v in fields.items():
                setattr(doc, k, v)
            s.commit()
            s.refresh(doc)
            return doc

    def get_document(self, doc_id: str) -> Optional[Document]:
        with self.session() as s:
            return s.get(Document, doc_id)

    def list_documents(self, inst_id: str) -> List[Document]:
        with self.session() as s:
            return list(
                s.query(Document)
                .filter(Document.institution_id == inst_id)
                .order_by(Document.uploaded_at.desc())
                .all()
            )

    def delete_document(self, doc_id: str) -> bool:
        with self.session() as s:
            doc = s.get(Document, doc_id)
            if doc is None:
                return False
            s.delete(doc)
            s.commit()
            return True
