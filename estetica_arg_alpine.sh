#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d "web" ]]; then
  echo "ERROR: ejecutá desde la raíz del repo (donde existe ./web)"
  exit 1
fi

echo "==> 1) Favicon 43 (Argentina + Sol)"
mkdir -p web/public
cat > web/public/favicon.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <defs>
    <linearGradient id="flag" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#74ACDF"/>
      <stop offset="0.34" stop-color="#74ACDF"/>
      <stop offset="0.34" stop-color="#ffffff"/>
      <stop offset="0.67" stop-color="#ffffff"/>
      <stop offset="0.67" stop-color="#74ACDF"/>
      <stop offset="1" stop-color="#74ACDF"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="26" fill="#070b18"/>
  <rect x="10" y="10" width="108" height="108" rx="22" fill="url(#flag)" opacity="0.96"/>
  <!-- sol -->
  <circle cx="92" cy="38" r="11" fill="#f6c343"/>
  <g fill="#f6c343" opacity="0.95">
    <path d="M92 18l2 10h-4z"/>
    <path d="M92 58l2-10h-4z"/>
    <path d="M72 38l10 2v-4z"/>
    <path d="M112 38l-10 2v-4z"/>
  </g>
  <text x="30" y="90" font-family="system-ui, -apple-system, Segoe UI, Roboto" font-weight="950" font-size="56" fill="#070b18">43</text>
</svg>
SVG

echo "==> 2) Base layout: bandera + celeste/blanco + sol + acentos Alpine"
mkdir -p web/src/layouts

cat > web/src/layouts/Base.astro <<'ASTRO'
---
const {
  title = "Vamos Nene...!!!",
  description = "F1 en castellano: calendario, clima, noticias (Colapinto) y contexto en vivo.",
} = Astro.props;

const apiBase = import.meta.env.PUBLIC_API_BASE || "";
const url = Astro.url;
const origin = url.origin;
const canonical = url.toString();
const ogImage = `${origin}/og.svg`;
---
<!doctype html>
<html lang="es-AR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonical} />

    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <meta name="theme-color" content="#74ACDF" />

    <!-- OpenGraph / Twitter -->
    <meta property="og:locale" content="es_AR" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="Vamos Nene...!!!" />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:url" content={canonical} />
    <meta property="og:image" content={ogImage} />
    <meta name="twitter:card" content="summary_large_image" />

    <script type="application/ld+json">
      {JSON.stringify({
        "@context": "https://schema.org",
        "@type": "WebSite",
        name: "Vamos Nene...!!!",
        url: origin,
        inLanguage: "es-AR",
        description,
      })}
    </script>

    <style>
      :root{
        /* Base */
        --bg:#050816;
        --panel: rgba(255,255,255,.06);
        --panel2: rgba(255,255,255,.04);
        --border: rgba(255,255,255,.14);
        --text: rgba(255,255,255,.92);
        --muted: rgba(255,255,255,.72);

        /* Argentina */
        --ar: #74ACDF;
        --ar2:#5aa7df;
        --white:#ffffff;
        --sun:#f6c343;

        /* Alpine accents */
        --alpine-blue:#1fa3ff;
        --alpine-pink:#ff5ab3;

        /* Actions */
        --primary: var(--ar);
        --primaryText:#06101b;
        --secondary: rgba(255,255,255,.08);
        --secondaryText: var(--text);

        color-scheme: dark;
      }

      *{ box-sizing:border-box; }
      body{
        margin:0;
        font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Noto Sans", sans-serif;
        line-height:1.5;
        color: var(--text);
        background:
          radial-gradient(900px 520px at 12% 0%, rgba(116,172,223,.22), transparent 60%),
          radial-gradient(900px 520px at 88% 0%, rgba(255,90,179,.14), transparent 58%),
          radial-gradient(900px 520px at 70% 10%, rgba(31,163,255,.14), transparent 62%),
          linear-gradient(180deg, rgba(116,172,223,.08), transparent 36%),
          var(--bg);
      }

      a{ color: inherit; }
      .wrap{ max-width: 1120px; margin: 0 auto; padding: 18px; }

      header{
        position: sticky; top:0;
        z-index: 10;
        background: rgba(5,8,22,.82);
        backdrop-filter: blur(10px);
        border-bottom: 1px solid var(--border);
      }

      /* franja bandera */
      .flagbar{
        height: 10px;
        background: linear-gradient(to bottom,
          var(--ar) 0 33%,
          var(--white) 33% 66%,
          var(--ar) 66% 100%
        );
        opacity: .95;
      }

      .topbar{ display:flex; align-items:center; justify-content:space-between; gap: 14px; padding-top: 14px; }
      .brandLink{ text-decoration:none; display:flex; align-items:center; gap: 10px; }
      .brandMark{
        width: 38px; height: 38px;
        border-radius: 14px;
        border: 1px solid var(--border);
        background:
          radial-gradient(14px 14px at 70% 30%, rgba(246,195,67,.95), rgba(246,195,67,0) 60%),
          linear-gradient(to bottom, var(--ar) 0 33%, #ffffff 33% 66%, var(--ar) 66% 100%);
        box-shadow: 0 0 0 4px rgba(116,172,223,.10);
      }
      .brandTitle{ display:flex; flex-direction:column; gap:2px; }
      .brandTitle strong{ letter-spacing:.2px; font-weight: 950; }
      .brandTitle small{ color: var(--muted); font-size:12px; }

      nav{ display:flex; flex-wrap:wrap; gap: 10px; align-items:center; justify-content:flex-end; }
      nav a{ text-decoration:none; opacity:.92; font-weight: 800; padding: 6px 8px; border-radius: 10px; }
      nav a:hover{ opacity:1; background: rgba(255,255,255,.06); }

      .btn{
        display:inline-flex; align-items:center; justify-content:center;
        padding:10px 12px; border-radius: 14px;
        border: 1px solid var(--border);
        background: var(--secondary);
        text-decoration:none;
        font-weight: 900;
        color: var(--secondaryText);
      }
      .btn.primary{
        background: var(--primary);
        color: var(--primaryText);
        border-color: rgba(0,0,0,.22);
        box-shadow: 0 10px 28px rgba(116,172,223,.22);
      }
      .btn.alpine{
        background: linear-gradient(90deg, rgba(31,163,255,.95), rgba(255,90,179,.75));
        color: #071019;
        border-color: rgba(0,0,0,.22);
      }

      .hero{ padding: 14px 0 0; }
      .heroCard{
        border-radius: 20px;
        background:
          linear-gradient(90deg, rgba(116,172,223,.18), rgba(255,255,255,.06));
        border: 1px solid var(--border);
        padding: 16px;
      }
      .hero h1{ margin:0 0 6px; font-size: 28px; letter-spacing:.2px; }
      .muted{ color: var(--muted); }

      main{ padding: 14px 0 24px; }

      .card{
        border: 1px solid var(--border);
        border-radius: 18px;
        padding: 16px;
        background: var(--panel);
        margin: 14px 0;
        box-shadow: 0 16px 44px rgba(0,0,0,.24);
      }

      .grid{ display:grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; }
      .row{ display:flex; gap:10px; flex-wrap:wrap; align-items:center; }

      .pill{
        display:inline-flex; align-items:center; gap:8px;
        padding: 6px 10px;
        border-radius: 999px;
        border:1px solid rgba(116,172,223,.35);
        color: rgba(255,255,255,.82);
        font-size: 12px;
        font-weight: 800;
        background: rgba(116,172,223,.12);
      }
      .pill .dot{
        width: 8px; height: 8px; border-radius: 999px;
        background: var(--sun);
        box-shadow: 0 0 0 4px rgba(246,195,67,.18);
      }

      .noteBox{
        border-left: 4px solid var(--ar);
        padding: 12px 12px;
        border-radius: 14px;
        background: rgba(116,172,223,.10);
      }

      footer{ border-top: 1px solid var(--border); padding: 18px 0 28px; color: var(--muted); }
      img{ max-width:100%; height:auto; }
      input,button,select{ font:inherit; }
      code{ color: rgba(116,172,223,.95); }

      .siteMapGrid{
        display:grid;
        grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        gap: 14px;
        margin-top: 12px;
      }
      .siteMapGrid a{ text-decoration:none; opacity:.95; }
      .siteMapGrid a:hover{ text-decoration: underline; text-underline-offset: 3px; opacity:1; }

      /* headings */
      h2{ margin: 10px 0 6px; font-size: 24px; letter-spacing:.2px; }
      h3{ margin: 8px 0 6px; font-size: 18px; }

      /* small badge "sol" */
      .sunBadge{
        display:inline-flex; align-items:center; gap:8px;
        padding: 6px 10px; border-radius: 999px;
        background: rgba(246,195,67,.14);
        border: 1px solid rgba(246,195,67,.28);
        color: rgba(255,255,255,.86);
        font-weight: 900;
        font-size: 12px;
      }
      .sunBadge::before{
        content:"";
        width: 10px; height: 10px; border-radius: 999px;
        background: var(--sun);
        box-shadow: 0 0 0 5px rgba(246,195,67,.16);
      }
    </style>
  </head>

  <body>
    <header>
      <div class="flagbar"></div>
      <div class="wrap topbar">
        <a class="brandLink" href="/" aria-label="Inicio">
          <div class="brandMark" aria-hidden="true"></div>
          <div class="brandTitle">
            <strong>Vamos Nene...!!!</strong>
            <small>F1 en castellano · foco Colapinto · horarios ARG</small>
          </div>
        </a>

        <nav>
          <a href="/vivo">Vivo</a>
          <a href="/calendario/2026">Calendario</a>
          <a href="/noticias">Noticias</a>
          <a href="/tienda">Tienda</a>
          <a href="/suscribirme">Suscribirme</a>
          <a class="btn alpine" href="/suscribirme">Recibir avisos</a>
        </nav>
      </div>
    </header>

    <div class="wrap hero">
      <div class="heroCard">
        <div class="row" style="justify-content:space-between">
          <div>
            <h1>Celeste y blanco. Todo lo importante de F1.</h1>
            <div class="muted">Calendario · clima · noticias con contexto (Colapinto)</div>
          </div>
          <span class="sunBadge">Sol de Mayo</span>
        </div>

        <div class="row" style="margin-top:12px">
          <span class="pill"><span class="dot"></span> #43</span>
          <span class="pill"><span class="dot"></span> Horarios ARG</span>
          <span class="pill"><span class="dot"></span> Clima del circuito</span>
          <span class="pill"><span class="dot"></span> Alpine accents</span>
        </div>
      </div>
    </div>

    <main class="wrap">
      <slot />
    </main>

    <footer>
      <div class="wrap">
        <div class="noteBox">
          <strong>Nota:</strong> no somos un sitio oficial ni afiliado a Formula 1. Fuentes acreditadas en cada nota.
        </div>

        <div class="siteMapGrid">
          <div>
            <strong>Secciones</strong><br/>
            <a href="/vivo">Vivo</a><br/>
            <a href="/calendario/2026">Calendario 2026</a><br/>
            <a href="/noticias">Noticias</a><br/>
            <a href="/tienda">Tienda</a><br/>
            <a href="/suscribirme">Suscribirme</a>
          </div>
          <div>
            <strong>Guías</strong><br/>
            <a href="/guias/como-ver-f1-en-argentina">Cómo ver F1 en Argentina</a><br/>
            <a href="/guias/colapinto-biografia">Colapinto: bio y contexto</a><br/>
            <a href="/guias/glosario-f1">Glosario F1</a><br/>
            <a href="/guias/horarios-argentina">Horarios Argentina</a><br/>
            <a href="/guias/testing-bahrain">Cómo leer el testing</a>
          </div>
          <div>
            <strong>Legal</strong><br/>
            <a href="/privacy">Privacidad</a><br/>
            <a href="/terms">Términos</a><br/>
            <a href="/about">Sobre</a><br/>
            <a href="/contact">Contacto</a><br/>
            <a href="/sitemap.xml">Sitemap</a>
          </div>
        </div>

        <div style="margin-top:14px">© {new Date().getFullYear()} Vamos Nene...!!!</div>
        <div class="muted" style="margin-top:6px">API: <code>{apiBase || "(no configurada)"}</code></div>
      </div>
    </footer>
  </body>
</html>
ASTRO

echo "OK: estética aplicada (Base.astro + favicon)."
echo "Siguiente: commit + push para que Cloudflare Pages publique."
