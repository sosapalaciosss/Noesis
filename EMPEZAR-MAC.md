# 🍎 Cómo ejecutar Noesis en macOS (sin Docker)

Guía paso a paso para correr Noesis localmente en tu Mac. No necesitas saber
programar: solo copiar y pegar comandos.

Abrirás **dos ventanas de Terminal**: una para el *backend* (el cerebro) y otra
para el *frontend* (la página web). Las dos deben quedar abiertas mientras uses
la aplicación.

> **Abrir la Terminal:** presiona `Cmd + Espacio`, escribe `Terminal` y Enter.

---

## Paso 1 · Instalar lo necesario (solo la primera vez)

### 1.1 Homebrew (gestor de instalaciones de Mac)
Pega esto en la Terminal y sigue las indicaciones:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 1.2 Python y Node.js
```bash
brew install python@3.11 node git
```

---

## Paso 2 · Descargar el proyecto (solo la primera vez)
```bash
cd ~/Desktop
git clone https://github.com/sosapalaciosss/Noesis.git
cd Noesis
git checkout claude/funny-mendel-x78rvq
```
Esto crea una carpeta **Noesis** en tu Escritorio.

---

## Paso 3 · Encender el BACKEND (ventana 1)

En tu primera ventana de Terminal:
```bash
cd ~/Desktop/Noesis/backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
> La instalación tarda unos minutos la primera vez (descarga el modelo de IA).

Ahora enciéndelo (guarda los datos en disco, sin necesidad de servidor):
```bash
export QDRANT_PATH=./data/qdrant
export EMBEDDING_PROVIDER=sentence_transformers
uvicorn app.main:app --port 8000
```
Cuando veas `Application startup complete`, ¡el backend está listo!
**Deja esta ventana abierta.**

---

## Paso 4 · Encender el FRONTEND (ventana 2)

Abre una **segunda** ventana de Terminal (`Cmd + N`) y pega:
```bash
cd ~/Desktop/Noesis/frontend
npm install
npm run dev
```
Verás una dirección como `http://localhost:5173`. **Deja esta ventana abierta.**

---

## Paso 5 · Usar Noesis

Abre tu navegador y entra a:

### 👉 http://localhost:5173

1. Ve a **Biblioteca** → arrastra un PDF, Word (.docx) o TXT para subirlo.
2. Espera a que el estado diga **"Indexado"** (unos segundos).
3. Ve a **Chat institucional** y pregunta sobre el documento. Verás las fuentes
   citadas a la derecha.

---

## (Opcional) Respuestas con IA Mistral

Sin configurar nada, Noesis responde mostrando los fragmentos más relevantes
("modo extractivo"). Para respuestas redactadas con lenguaje natural:

1. Crea una API key gratuita en https://console.mistral.ai
2. En la **ventana 1** (backend), detén el servidor con `Ctrl + C` y ejecuta:
   ```bash
   export MISTRAL_API_KEY=pega_aqui_tu_clave
   uvicorn app.main:app --port 8000
   ```

---

## Apagar y volver a encender

- **Apagar:** en cada ventana presiona `Ctrl + C`.
- **Volver a encender (días después):** repite solo los pasos 3 y 4, pero
  *sin* reinstalar. Es decir:

  Ventana 1 (backend):
  ```bash
  cd ~/Desktop/Noesis/backend
  source .venv/bin/activate
  export QDRANT_PATH=./data/qdrant
  uvicorn app.main:app --port 8000
  ```
  Ventana 2 (frontend):
  ```bash
  cd ~/Desktop/Noesis/frontend
  npm run dev
  ```
  Tus documentos siguen guardados. 🎉

---

## Problemas comunes

| Problema | Solución |
|---|---|
| `command not found: brew` | Cierra y vuelve a abrir la Terminal tras instalar Homebrew. |
| `command not found: python3.11` | Ejecuta `brew install python@3.11`. |
| La web carga pero el chat falla | Revisa que la **ventana 1 (backend)** siga abierta y sin errores. |
| "Address already in use" (puerto ocupado) | Ya hay un Noesis corriendo, o usa otro puerto: `uvicorn app.main:app --port 8001`. |
