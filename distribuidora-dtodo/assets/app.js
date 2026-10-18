(function () {
  'use strict';

  // Número de WhatsApp de pedidos (formato internacional, sin "+" ni espacios).
  var WA = 'https://wa.me/50370274503?text=';
  var IMG = function (id) { return 'https://images.unsplash.com/' + id + '?w=1200&q=80&auto=format&fit=crop'; };

  var SEGMENTS = {
    pan: { label: 'Panaderías y pupuserías', tag: 'Panificación',
      title: 'Todo lo que tu horno y tu comal necesitan.', image: IMG('photo-1555507036-ab1f4038808a'),
      desc: 'Harinas de trigo y arroz de alto rendimiento, huevos frescos de granja con yema firme y aceites para panificación. Un pedido cubre tu semana.',
      products: ['Harina de Trigo El Panadero 50 lb', 'Harina de Arroz Tío Pepe 25 lb', 'Huevos de granja', 'Aceite vegetal'],
      cta: 'Cotizar para mi panadería', msg: 'Hola D Todo, tengo una panadería/pupusería y quiero cotizar harinas, huevos y aceite.' },
    rest: { label: 'Restaurantes, pollerías y comedores', tag: 'Cocina profesional',
      title: 'Pollo fresco directo de nuestra granja.', image: IMG('photo-1414235077428-338989a2e8c0'),
      desc: 'Pollo y gallina fresca directa de nuestra granja y aceite para fritura profunda. Calidad constante para que tu menú salga igual todos los días.',
      products: ['Pollo fresco', 'Gallina', 'Huevos de granja', 'Aceite para fritura'],
      cta: 'Cotizar para mi restaurante', msg: 'Hola D Todo, tengo un restaurante/pollería/comedor y quiero cotizar pollo, gallina y aceite.' },
    may: { label: 'Mayoristas y tiendas de abasto', tag: 'Reventa',
      title: 'Precios por volumen para maximizar tu margen.', image: IMG('photo-1542838132-92c53300491e'),
      desc: 'Precios especiales por volumen en quintales, fardos y cajas para maximizar tu margen de ganancia. Compra al productor y revende con ventaja.',
      products: ['Quintales de harina', 'Fardos', 'Cajas de huevo', 'Bidones de aceite'],
      cta: 'Cotizar precio mayorista', msg: 'Hola D Todo, tengo un negocio mayorista/tienda de abasto y quiero precios especiales por volumen.' },
    hot: { label: 'Hoteles y catering', tag: 'Servicio de eventos',
      title: 'Volumen garantizado, entrega puntual.', image: IMG('photo-1555244162-803834f70033'),
      desc: 'Abastecimiento puntual, volumen garantizado y trazabilidad de cada producto. Planifica eventos y temporadas altas sin riesgo de faltantes.',
      products: ['Huevos clasificados', 'Pollo y gallina', 'Harinas', 'Aceites'],
      cta: 'Cotizar para mi hotel o catering', msg: 'Hola D Todo, tengo un hotel/servicio de catering y quiero cotizar abastecimiento por volumen.' }
  };
  var ITEMS = ['Huevos', 'Pollo / Gallina', 'Harinas', 'Aceite'];

  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

  // ---------- Selector de tipo de cliente ----------
  var panel = $('#seg-panel');
  function selectSegment(id) {
    var seg = SEGMENTS[id];
    if (!seg || !panel) return;
    $$('[data-seg]').forEach(function (btn) {
      var on = btn.getAttribute('data-seg') === id;
      btn.classList.toggle('is-on', on);
      btn.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    var img = $('[data-seg-img]', panel);
    img.src = seg.image;
    img.alt = seg.label;
    $('[data-seg-tag]', panel).textContent = seg.tag;
    $('[data-seg-title]', panel).textContent = seg.title;
    $('[data-seg-desc]', panel).textContent = seg.desc;
    $('[data-seg-cta]', panel).textContent = seg.cta;
    $('[data-seg-wa]', panel).href = WA + encodeURIComponent(seg.msg);
    var list = $('[data-seg-products]', panel);
    list.innerHTML = '';
    seg.products.forEach(function (p) {
      var s = document.createElement('span');
      s.className = 'dt-chip';
      s.textContent = p;
      list.appendChild(s);
    });
  }
  $$('[data-seg]').forEach(function (btn) {
    btn.addEventListener('click', function () { selectSegment(btn.getAttribute('data-seg')); });
  });

  // ---------- Cotizador ----------
  var state = { biz: 'Panadería', items: ['Harinas', 'Huevos'], vol: '10 – 50' };
  var nameInput = $('#q-name');
  var zoneInput = $('#q-zone');

  function renderQuote() {
    $$('[data-biz]').forEach(function (b) {
      var on = b.getAttribute('data-biz') === state.biz;
      b.classList.toggle('is-on', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    $$('[data-item]').forEach(function (b) {
      var on = state.items.indexOf(b.getAttribute('data-item')) !== -1;
      b.classList.toggle('is-on', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    $$('[data-vol]').forEach(function (b) {
      var on = b.getAttribute('data-vol') === state.vol;
      b.classList.toggle('is-on', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });

    var name = nameInput.value.trim();
    var zone = zoneInput.value.trim();
    var ordered = ITEMS.filter(function (i) { return state.items.indexOf(i) !== -1; });
    var lines = [
      'Hola Distribuidora D Todo, quiero cotizar precios especiales.',
      'Negocio: ' + state.biz + (name ? ' – ' + name : ''),
      zone ? 'Zona: ' + zone : null,
      'Insumos: ' + (ordered.length ? ordered.join(', ') : 'Por definir'),
      'Volumen estimado: ' + state.vol + ' unidades por semana'
    ].filter(Boolean);
    var message = lines.join('\n');

    $('#q-preview').textContent = message;
    $('#q-send').href = WA + encodeURIComponent(message);
    $('#q-warn').hidden = ordered.length !== 0;
  }

  $$('[data-biz]').forEach(function (b) {
    b.addEventListener('click', function () { state.biz = b.getAttribute('data-biz'); renderQuote(); });
  });
  $$('[data-item]').forEach(function (b) {
    b.addEventListener('click', function () {
      var it = b.getAttribute('data-item');
      var i = state.items.indexOf(it);
      if (i === -1) state.items.push(it); else state.items.splice(i, 1);
      renderQuote();
    });
  });
  $$('[data-vol]').forEach(function (b) {
    b.addEventListener('click', function () { state.vol = b.getAttribute('data-vol'); renderQuote(); });
  });
  if (nameInput && zoneInput) {
    nameInput.addEventListener('input', renderQuote);
    zoneInput.addEventListener('input', renderQuote);
    renderQuote();
  }

  // Año del pie de página
  var y = $('#year');
  if (y) y.textContent = new Date().getFullYear();
})();
