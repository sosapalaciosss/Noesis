# 🚚 Plataforma de Trazabilidad Logística

Aplicación web sencilla para rastrear envíos de camiones. MVP funcional con tres
vistas y una demo de ubicación en vivo.

## ¿Qué incluye?

- **Vista del Conductor** (`/conductor.html`): pantalla para celular con botones
  grandes para registrar el avance del viaje y compartir la ubicación en vivo.
- **Vista del Cliente** (`/cliente.html`): seguimiento público de solo lectura por
  código (ej. `TRK-1001`), con línea de tiempo y mapa.
- **Panel del Dueño** (`/panel.html`): tablero con todos los viajes, su estado y
  alertas automáticas cuando un viaje lleva demasiado tiempo sin cambios.

## Tecnología

- **Backend:** Node.js + Express
- **Base de datos:** SQLite (archivo local `datos.db`, los datos no se pierden)
- **Frontend:** HTML, CSS y JavaScript simples (sin frameworks)
- **Mapa:** Leaflet + OpenStreetMap (gratuito)

## Cómo ejecutarlo

Requisito: tener instalado [Node.js](https://nodejs.org).

```bash
npm install      # instala las dependencias (solo la primera vez)
npm run seed     # carga 3 viajes de prueba (solo la primera vez)
npm start        # enciende el servidor
```

Luego abrir en el navegador: **http://localhost:3000**

## Notas

- La función de **compartir ubicación** funciona en `localhost` o con conexión
  segura (HTTPS). Para usarla en la calle desde un teléfono hay que publicar la
  app en internet con HTTPS.
- El tiempo para marcar un viaje como "atascado" se ajusta con la variable de
  entorno `UMBRAL_ALERTA_MIN` (por defecto: 60 minutos).
