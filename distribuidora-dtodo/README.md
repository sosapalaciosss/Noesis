# Distribuidora D Todo · Landing page

Sitio estático (HTML + CSS + JS puro, sin dependencias ni compilación) listo para publicar.

```
distribuidora-dtodo/
├── index.html          ← la página
├── assets/app.js       ← selector de clientes y cotizador por WhatsApp
├── favicon.svg
├── apple-touch-icon.png
├── og-image.jpg        ← imagen al compartir el link (WhatsApp, Facebook…)
├── robots.txt
├── sitemap.xml
├── 404.html
└── .htaccess           ← solo se usa en hosting Apache/cPanel
```

## Paso 1 · Poner tu dominio (obligatorio)

Reemplaza `TU-DOMINIO.com` por tu dominio real (por ejemplo `dtodo.com.sv`) en
`index.html`, `robots.txt` y `sitemap.xml`. Desde esta carpeta:

```bash
# macOS
grep -rl "TU-DOMINIO.com" . | xargs sed -i '' 's/TU-DOMINIO\.com/dtodo.com.sv/g'
# Linux
grep -rl "TU-DOMINIO.com" . | xargs sed -i 's/TU-DOMINIO\.com/dtodo.com.sv/g'
```

(o usa "Buscar y reemplazar" en VS Code sobre la carpeta).

## Paso 2 · Publicar (elige una opción)

### Opción A · Netlify (gratis, la más fácil)
1. Entra a https://app.netlify.com/drop y arrastra la carpeta `distribuidora-dtodo`.
2. *Domain management → Add a domain* → escribe tu dominio.
3. En el panel DNS de donde compraste el dominio, crea los registros que Netlify te indique
   (normalmente `A @ 75.2.60.5` y `CNAME www <tu-sitio>.netlify.app`).
4. El certificado HTTPS se activa solo en unos minutos.

### Opción B · Vercel (gratis)
1. https://vercel.com/new → importa el repositorio y en *Root Directory* elige `distribuidora-dtodo`
   (Framework: *Other*, sin comando de build).
2. *Settings → Domains* → agrega tu dominio y copia los registros DNS que te muestre.

### Opción C · GitHub Pages (gratis)
1. Sube el contenido de esta carpeta a la raíz de un repositorio.
2. *Settings → Pages* → *Deploy from a branch* → `main` / `root`.
3. En *Custom domain* escribe tu dominio y activa *Enforce HTTPS*.
4. DNS: `A @` → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   y `CNAME www` → `<tu-usuario>.github.io`.

### Opción D · Hosting con cPanel (Hostinger, Namecheap, GoDaddy…)
1. Abre el *Administrador de archivos* → carpeta `public_html`.
2. Sube **todo el contenido** de esta carpeta (incluido `.htaccess`, que es un archivo oculto).
3. Activa el SSL gratuito (AutoSSL / Let's Encrypt). El `.htaccess` ya redirige a HTTPS.

## Paso 3 · Después de publicar
- Prueba los botones de WhatsApp desde tu celular.
- Registra el sitio en Google Search Console (https://search.google.com/search-console)
  y envía `https://tudominio/sitemap.xml`.
- Crea tu Perfil de Empresa en Google (https://business.google.com) y pon el link del sitio.
- Comprueba cómo se ve al compartir el link: https://developers.facebook.com/tools/debug/

## Cambios frecuentes
- **Número de WhatsApp**: busca `50370274503` en `index.html` y `assets/app.js` y reemplázalo
  (formato internacional sin `+` ni espacios). El número visible es `+503 7027 4503`.
- **Fotos**: se cargan desde Unsplash (uso libre). Para usar fotos propias, guárdalas en
  `assets/` y cambia el `src="..."` de cada `<img>` en `index.html` (y en `assets/app.js`
  para las del selector de clientes).

## Probar en tu computadora
```bash
cd distribuidora-dtodo
python3 -m http.server 8000
# abre http://localhost:8000
```
