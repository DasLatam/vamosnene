#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "web/src/layouts/Base.astro" ]]; then
  echo "ERROR: no encuentro web/src/layouts/Base.astro. Ejecutá desde la raíz del repo."
  exit 1
fi

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
    <meta name="color-scheme" content="light" />

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
        /* Argentina */
        --ar: #74ACDF;
        --ar2:#5aa7df;
        --white:#ffffff;
        --sun:#f6c343;

        /* Alpine accents */
        --alpine-blue:#1fa3ff;
        --alpine-pink:#ff5ab3;

        /* Light theme base */
        --bg: #f5fbff;
        --panel: rgba(255,255,255,.88);
        --panel2: rgba(255,255,255,.72);
        --border: rgba(7,16,24,.14);
        --text: rgba(7,16,24,.92);
        --muted: rgba(7,16,24,.64);

        /* Actions */
        --primary: var(--ar);
        --primaryText: rgba(7,16,24,.92);
        --secondary: rgba(7,16,24,.06);
        --secondaryText: rgba(7,16,24,.86);

        --shadow: 0 18px 44px rgba(7,16,24,.10);

        color-scheme: light;
      }

      *{ box-sizing:border-box; }
      body{
        margin:0;
        font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Noto Sans", sans-serif;
        line-height:1.5;
        color: var(--text);
        background:
          radial-gradient(900px 520px at 10% 0%, rgba(116,172,223,.32), transparent 58%),
          radial-gradient(900px 520px at 92% 0%, rgba(255,90,179,.18), transparent 60%),
          radial-gradient(900px 520px at 70% 10%, rgba(31,163,255,.16), transparent 62%),
          linear-gradient(180deg, rgba(116,172,223,.18), transparent 42%),
          var(--bg);
      }

      a{ color: inherit; }
      .wrap{ max-width: 1120px; margin: 0 auto; padding: 18px; }

      header{
        position: sticky; top:0;
        z-index: 10;
        background: rgba(255,255,255,.86);
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
        opacity: .98;
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
        box-shadow: 0 0 0 4px rgba(116,172,223,.18);
      }
      .brandTitle{ display:flex; flex-direction:column; gap:2px; }
      .brandTitle strong{ letter-spacing:.2px; font-weight: 950; }
      .brandTitle small{ color: var(--muted); font-size:12px; }

      nav{ display:flex; flex-wrap:wrap; gap: 10px; align-items:center; justify-content:flex-end; }
      nav a{
        text-decoration:none;
        opacity:.95;
        font-weight: 900;
        padding: 7px 10px;
        border-radius: 12px;
      }
      nav a:hover{
        opacity:1;
        background: rgba(116,172,223,.18);
      }

      .btn{
        display:inline-flex; align-items:center; justify-content:center;
        padding:10px 12px; border-radius: 14px;
        border: 1px solid var(--border);
        background: var(--secondary);
        text-decoration:none;
        font-weight: 950;
        color: var(--secondaryText);
      }
      .btn.primary{
        background: var(--primary);
        color: var(--primaryText);
        border-color: rgba(7,16,24,.10);
        box-shadow: 0 12px 28px rgba(116,172,223,.26);
      }
      .btn.alpine{
        background: linear-gradient(90deg, rgba(31,163,255,.92), rgba(255,90,179,.72));
        color: rgba(7,16,24,.92);
        border-color: rgba(7,16,24,.10);
        box-shadow: 0 12px 28px rgba(255,90,179,.12);
      }

      .hero{ padding: 14px 0 0; }
      .heroCard{
        border-radius: 20px;
        background:
          linear-gradient(90deg, rgba(116,172,223,.26), rgba(255,255,255,.78));
        border: 1px solid rgba(7,16,24,.10);
        padding: 16px;
        box-shadow: var(--shadow);
      }
      .hero h1{ margin:0 0 6px; font-size: 28px; letter-spacing:.2px; }
      .muted{ color: var(--muted); }

      main{ padding: 14px 0 24px; }

      .card{
        border: 1px solid rgba(7,16,24,.12);
        border-radius: 18px;
        padding: 16px;
        background: var(--panel);
        margin: 14px 0;
        box-shadow: var(--shadow);
      }

      .grid{ display:grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; }
      .row{ display:flex; gap:10px; flex-wrap:wrap; align-items:center; }

      .pill{
        display:inline-flex; align-items:center; gap:8px;
        padding: 6px 10px;
        border-radius: 999px;
        border:1px solid rgba(116,172,223,.45);
        color: rgba(7,16,24,.78);
        font-size: 12px;
        font-weight: 900;
        background: rgba(116,172,223,.18);
      }
      .pill .dot{
        width: 8px; height: 8px; border-radius: 999px;
        background: var(--sun);
        box-shadow: 0 0 0 4px rgba(246,195,67,.22);
      }

      .noteBox{
        border-left: 4px solid var(--ar);
        padding: 12px 12px;
        border-radius: 14px;
        background: rgba(116,172,223,.16);
      }

      footer{ border-top: 1px solid var(--border); padding: 18px 0 28px; color: var(--muted); }
      img{ max-width:100%; height:auto; }
      input,button,select{ font:inherit; }
      code{ color: rgba(7,16,24,.78); background: rgba(116,172,223,.18); padding: 2px 6px; border-radius: 8px; }

      .siteMapGrid{
        display:grid;
        grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        gap: 14px;
        margin-top: 12px;
      }
      .siteMapGrid a{ text-decoration:none; opacity:.95; }
      .siteMapGrid a:hover{ text-decoration: underline; text-underline-offset: 3px; opacity:1; }

      h2{ margin: 10px 0 6px; font-size: 24px; letter-spacing:.2px; }
      h3{ margin: 8px 0 6px; font-size: 18px; }

      .sunBadge{
        display:inline-flex; align-items:center; gap:8px;
        padding: 6px 10px; border-radius: 999px;
        background: rgba(246,195,67,.22);
        border: 1px solid rgba(246,195,67,.34);
        color: rgba(7,16,24,.82);
        font-weight: 950;
        font-size: 12px;
      }
      .sunBadge::before{
        content:"";
        width: 10px; height: 10px; border-radius: 999px;
        background: var(--sun);
        box-shadow: 0 0 0 5px rgba(246,195,67,.18);
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

echo "OK: tema claro aplicado en web/src/layouts/Base.astro"
