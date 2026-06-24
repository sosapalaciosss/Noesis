#!/bin/bash
# ===========================================================================
#  Noesis — Iniciar con un clic (macOS)
#  Haz doble clic en este archivo desde Finder para encender Noesis.
#  La primera vez instala todo automáticamente; las siguientes solo arranca.
# ===========================================================================

set -u

# Ir a la carpeta donde está este script (raíz del proyecto).
cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"

# Colores para mensajes legibles.
B="\033[1;34m"; G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; N="\033[0m"

say()  { echo -e "${B}▶ $1${N}"; }
ok()   { echo -e "${G}✔ $1${N}"; }
warn() { echo -e "${Y}! $1${N}"; }
err()  { echo -e "${R}✘ $1${N}"; }

echo ""
echo -e "${B}===========================================${N}"
echo -e "${B}   NOESIS · Conocimiento Institucional${N}"
echo -e "${B}===========================================${N}"
echo ""

# --- 1) Verificar requisitos ----------------------------------------------
PYTHON=""
for c in python3.11 python3; do
  if command -v "$c" >/dev/null 2>&1; then PYTHON="$c"; break; fi
done
if [ -z "$PYTHON" ]; then
  err "No se encontró Python 3. Instálalo desde https://www.python.org/downloads/macos/"
  echo "Pulsa una tecla para cerrar."; read -r -n 1; exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  err "No se encontró Node.js. Instálalo desde https://nodejs.org/ (versión LTS)."
  echo "Pulsa una tecla para cerrar."; read -r -n 1; exit 1
fi
ok "Python ($PYTHON) y Node.js detectados."

# --- 2) Preparar el backend (primera vez instala dependencias) ------------
say "Preparando el backend…"
cd "$ROOT/backend" || exit 1
if [ ! -d ".venv" ]; then
  warn "Primera ejecución: creando entorno e instalando dependencias (tarda unos minutos)…"
  "$PYTHON" -m venv .venv || { err "No se pudo crear el entorno de Python."; read -r -n 1; exit 1; }
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install --quiet --upgrade pip
  pip install -r requirements.txt || { err "Falló la instalación de dependencias de Python."; read -r -n 1; exit 1; }
  ok "Dependencias del backend instaladas."
else
  # shellcheck disable=SC1091
  source .venv/bin/activate
  ok "Entorno del backend listo."
fi

# Cargar MISTRAL_API_KEY si existe un archivo .env en la raíz.
if [ -f "$ROOT/.env" ]; then
  # shellcheck disable=SC1090
  set -a; source "$ROOT/.env"; set +a
fi

# --- 3) Preparar el frontend (primera vez instala dependencias) -----------
say "Preparando el frontend…"
cd "$ROOT/frontend" || exit 1
if [ ! -d "node_modules" ]; then
  warn "Primera ejecución: instalando dependencias web (tarda un par de minutos)…"
  npm install || { err "Falló la instalación de dependencias del frontend."; read -r -n 1; exit 1; }
  ok "Dependencias del frontend instaladas."
else
  ok "Dependencias del frontend listas."
fi

# --- 4) Arrancar el backend -----------------------------------------------
say "Encendiendo el backend…"
cd "$ROOT/backend" || exit 1
export QDRANT_PATH="${QDRANT_PATH:-./data/qdrant}"
export EMBEDDING_PROVIDER="${EMBEDDING_PROVIDER:-sentence_transformers}"
export DATABASE_URL="${DATABASE_URL:-sqlite:///./data/noesis.db}"
export UPLOAD_DIR="${UPLOAD_DIR:-./data/uploads}"

if [ -n "${MISTRAL_API_KEY:-}" ]; then
  ok "Mistral configurado: las respuestas las redactará el modelo."
else
  warn "Sin MISTRAL_API_KEY: modo extractivo (muestra fragmentos). Opcional: añade tu clave en un archivo .env."
fi

python -m uvicorn app.main:app --port 8000 --log-level warning &
BACKEND_PID=$!

# Esperar a que el backend responda (la 1ª vez descarga el modelo de IA).
say "Esperando a que el backend esté listo (la primera vez descarga el modelo de IA, puede tardar)…"
for i in $(seq 1 120); do
  if curl -s --max-time 3 http://localhost:8000/api/health >/dev/null 2>&1; then break; fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    err "El backend se detuvo inesperadamente. Revisa los mensajes de arriba."
    read -r -n 1; exit 1
  fi
  sleep 3
done
ok "Backend en marcha → http://localhost:8000"

# --- 5) Arrancar el frontend ----------------------------------------------
say "Encendiendo la interfaz web…"
cd "$ROOT/frontend" || exit 1
npm run dev >/tmp/noesis_frontend.log 2>&1 &
FRONTEND_PID=$!

for i in $(seq 1 30); do
  if curl -s --max-time 3 http://localhost:5173 >/dev/null 2>&1; then break; fi
  sleep 1
done
ok "Interfaz web en marcha → http://localhost:5173"

# --- 6) Abrir el navegador -------------------------------------------------
sleep 1
open "http://localhost:5173" 2>/dev/null

echo ""
echo -e "${G}===========================================${N}"
echo -e "${G}  ✔ Noesis está funcionando${N}"
echo -e "${G}===========================================${N}"
echo -e "  Web:  ${B}http://localhost:5173${N}"
echo -e "  API:  ${B}http://localhost:8000/docs${N}"
echo ""
echo -e "${Y}  Para APAGAR Noesis: pulsa Ctrl + C aquí, o cierra esta ventana.${N}"
echo ""

# --- 7) Apagado limpio -----------------------------------------------------
cleanup() {
  echo ""
  say "Apagando Noesis…"
  kill "$FRONTEND_PID" 2>/dev/null
  kill "$BACKEND_PID" 2>/dev/null
  ok "Noesis apagado. Ya puedes cerrar esta ventana."
  exit 0
}
trap cleanup INT TERM

# Mantener el script vivo mientras corran los servicios.
wait "$BACKEND_PID"
