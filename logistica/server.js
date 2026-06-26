/**
 * Servidor principal de la Plataforma de Trazabilidad Logistica.
 * Motor: Node.js + Express. Base de datos: SQLite.
 */
const path = require('path');
const express = require('express');
const { db, init, TRIP_STATES } = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// Asegura que las tablas existan al arrancar.
init();

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// --- Utilidades ---

function obtenerTrip(idOcodigo) {
  return db
    .prepare('SELECT * FROM trips WHERE id = ? OR codigo = ?')
    .get(idOcodigo, idOcodigo);
}

function obtenerEventos(tripId) {
  return db
    .prepare('SELECT * FROM events WHERE trip_id = ? ORDER BY creado_en ASC, id ASC')
    .all(tripId);
}

// --- API ---

// Comprobacion de salud: confirma que el servidor responde.
app.get('/api/salud', (req, res) => {
  const total = db.prepare('SELECT COUNT(*) AS n FROM trips').get().n;
  res.json({ ok: true, mensaje: 'Servidor en linea', viajes: total });
});

// Lista de estados posibles (en orden).
app.get('/api/estados', (req, res) => {
  res.json({ estados: TRIP_STATES });
});

// Todos los viajes (para el panel del dueno).
app.get('/api/viajes', (req, res) => {
  const viajes = db.prepare('SELECT * FROM trips ORDER BY actualizado_en DESC').all();
  res.json({ viajes });
});

// Un viaje con su historial (por id o por codigo de seguimiento).
app.get('/api/viajes/:idOcodigo', (req, res) => {
  const trip = obtenerTrip(req.params.idOcodigo);
  if (!trip) return res.status(404).json({ error: 'Viaje no encontrado' });
  res.json({ viaje: trip, eventos: obtenerEventos(trip.id) });
});

app.listen(PORT, () => {
  console.log(`\n  Plataforma de Trazabilidad Logistica`);
  console.log(`  Servidor en linea: http://localhost:${PORT}`);
  console.log(`  Comprobacion:      http://localhost:${PORT}/api/salud\n`);
});
