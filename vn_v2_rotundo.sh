#!/usr/bin/env bash
set -euo pipefail

[ -d "web/src" ] || { echo "ERROR: ejecutá en la raíz del repo (debe existir web/src)"; exit 1; }

ts="$(date +%s)"
backup(){ [ -f "$1" ] && cp "$1" "$1.bak.$ts" || true; }

echo "==> (1) Assets + CSS V2 (Argentina + F1)"
mkdir -p web/public/assets web/src/layouts web/src/pages web/src/pages/guias web/src/pages/calendario

cat > web/public/assets/hero-vn.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="420" viewBox="0 0 1200 420">
  <defs>
    <linearGradient id="sky" x1="0" x2="1">
      <stop offset="0" stop-color="#67B7FF"/><stop offset="1" stop-color="#A9DDFF"/>
    </linearGradient>
    <linearGradient id="alp" x1="0" x2="1">
      <stop offset="0" stop-color="#1fa3ff"/><stop offset="1" stop-color="#ff4fd8"/>
    </linearGradient>
    <pattern id="chk" width="28" height="28" patternUnits="userSpaceOnUse">
      <rect width="14" height="14" fill="#0b1220"/><rect x="14" y="14" width="14" height="14" fill="#0b1220"/>
      <rect x="14" width="14" height="14" fill="#ffffff"/><rect y="14" width="14" height="14" fill="#ffffff"/>
    </pattern>
  </defs>

  <rect width="1200" height="420" rx="28" fill="#ffffff"/>
  <rect x="22" y="22" width="1156" height="376" rx="22" fill="url(#sky)" opacity="0.55"/>
  <rect x="22" y="62" width="1156" height="12" fill="#ffffff" opacity="0.95"/>
  <rect x="22" y="74" width="1156" height="12" fill="#67B7FF" opacity="0.95"/>

  <!-- sol -->
  <circle cx="1020" cy="112" r="30" fill="#ffcc33"/>
  <g fill="#ffcc33" opacity="0.9">
    <path d="M1020 58l6 24h-12z"/><path d="M1020 166l6-24h-12z"/>
    <path d="M966 112l24 6v-12z"/><path d="M1074 112l-24 6v-12z"/>
  </g>

  <!-- tablero oscuro tipo broadcast -->
  <rect x="60" y="120" width="430" height="240" rx="18" fill="#0b1220"/>
  <rect x="60" y="120" width="430" height="18" fill="url(#alp)" opacity="0.9"/>
  <rect x="88" y="160" width="374" height="36" rx="10" fill="rgba(255,255,255,0.08)"/>
  <rect x="88" y="212" width="374" height="36" rx="10" fill="rgba(255,255,255,0.08)"/>
  <rect x="88" y="264" width="374" height="36" rx="10" fill="rgba(255,255,255,0.08)"/>
  <rect x="88" y="316" width="240" height="36" rx="10" fill="rgba(103,183,255,0.25)"/>

  <!-- checkered corner -->
  <rect x="840" y="240" width="300" height="140" rx="18" fill="url(#chk)" opacity="0.25"/>
  <rect x="840" y="240" width="300" height="12" fill="url(#alp)" opacity="0.8"/>

  <text x="90" y="192" font-family="system-ui,Segoe UI,Roboto" font-weight="800" font-size="22" fill="rgba(255,255,255,0.88)">Hoy / Próximo</text>
  <text x="90" y="244" font-family="system-ui,Segoe UI,Roboto" font-weight="800" font-size="22" fill="rgba(255,255,255,0.88)">Dónde verlo (ARG)</text>
  <text x="90" y="296" font-family="system-ui,Segoe UI,Roboto" font-weight="800" font-size="22" fill="rgba(255,255,255,0.88)">Clima + horarios</text>
  <text x="90" y="348" font-family="system-ui,Segoe UI,Roboto" font-weight="900" font-size="22" fill="#ffffff">VIVO</text>

  <text x="740" y="170" font-family="system-ui,Segoe UI,Roboto" font-weight="950" font-size="62" fill="#0b1220">43</text>
  <text x="740" y="214" font-family="system-ui,Segoe UI,Roboto" font-weight="800" font-size="22" fill="rgba(11,18,32,0.75)">Vamos Nene...!!!</text>
  <text x="740" y="246" font-family="system-ui,Segoe UI,Roboto" font-weight="700" font-size="16" fill="rgba(11,18,32,0.7)">Centro argentino de F1 · foco Colapinto</text>
</svg>
SVG

cat > web/public/favicon.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" rx="28" fill="#67B7FF"/>
  <rect y="42" width="128" height="44" fill="#ffffff" opacity="0.95"/>
  <circle cx="96" cy="34" r="12" fill="#ffcc33"/>
  <text x="64" y="88" text-anchor="middle" font-family="system-ui,Segoe UI,Roboto" font-weight="950" font-size="56" fill="#0b1220">43</text>
</svg>
SVG

cat > web/public/vn.css <<'CSS'
:root{
  --bg:#f6fbff;
  --ink:#0b1220;
  --muted:rgba(11,18,32,.70);
  --line:rgba(11,18,32,.12);

  --sky:#67B7FF;
  --sky2:#A9DDFF;
  --sun:#ffcc33;

  --alpB:#1fa3ff;
  --alpP:#ff4fd8;

  --r:18px;
  --sh:0 14px 40px rgba(11,18,32,.10);
  --sh2:0 10px 26px rgba(11,18,32,.12);

  --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
  color:var(--ink);
  background:
    radial-gradient(900px 500px at 18% -10%, rgba(103,183,255,.55), transparent 70%),
    radial-gradient(800px 480px at 92% -20%, rgba(255,79,216,.12), transparent 60%),
    linear-gradient(180deg, var(--bg), #ffffff 70%);
}

a{color:inherit}
a:hover{text-decoration:underline; text-underline-offset:3px}

.container{max-width:1120px;margin:0 auto;padding:18px}

.top{
  position:sticky;top:0;z-index:30;
  backdrop-filter: blur(10px);
  background: rgba(246,251,255,.85);
  border-bottom:1px solid var(--line);
}
.flag{
  height:10px;
  background: linear-gradient(to bottom, var(--sky) 0 33%, #fff 33% 66%, var(--sky) 66% 100%);
}
.head{
  display:flex;align-items:center;justify-content:space-between;gap:14px;
  padding:12px 18px;
}
.brand{display:flex;align-items:center;gap:12px;text-decoration:none}
.badge43{
  width:40px;height:40px;border-radius:14px;
  border:1px solid var(--line);
  background:
    radial-gradient(14px 14px at 75% 25%, rgba(255,204,51,.95), rgba(255,204,51,0) 62%),
    linear-gradient(to bottom, var(--sky) 0 33%, #fff 33% 66%, var(--sky) 66% 100%);
  box-shadow: 0 0 0 6px rgba(103,183,255,.16);
}
.brand strong{font-weight:950;letter-spacing:.2px}
.brand small{display:block;color:var(--muted);font-size:12px;margin-top:2px}

.nav{display:flex;flex-wrap:wrap;gap:10px;justify-content:flex-end}
.nav a{
  text-decoration:none;
  padding:8px 10px;border-radius:999px;
  border:1px solid transparent;
  color:rgba(11,18,32,.86);
  font-weight:800;
}
.nav a:hover{border-color:rgba(103,183,255,.45);background:rgba(103,183,255,.12)}
.cta{
  border-color:rgba(255,79,216,.28)!important;
  background: linear-gradient(90deg, rgba(31,163,255,.30), rgba(255,79,216,.18));
}

.hero{
  border:1px solid var(--line);
  border-radius: 26px;
  background:#fff;
  box-shadow: var(--sh);
  overflow:hidden;
}
.hero img{display:block;width:100%;height:auto}
.heroBody{padding:14px 16px}
.h1{font-size:34px;line-height:1.12;margin:0}
.sub{color:var(--muted);margin:8px 0 0}
.kpis{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}
.kpi{
  display:inline-flex;align-items:center;gap:10px;
  padding:8px 12px;border-radius:999px;
  border:1px solid var(--line);
  background: rgba(255,255,255,.75);
  font-weight:900;
}
.dot{width:10px;height:10px;border-radius:999px;background:var(--sun);box-shadow:0 0 0 6px rgba(255,204,51,.18)}

.grid{display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));margin-top:14px}

.card{
  border:1px solid var(--line);
  border-radius: var(--r);
  background:#fff;
  box-shadow: var(--sh2);
  padding:14px;
}
.card h2{margin:0 0 8px;font-size:22px}
.muted{color:var(--muted)}
.mono{font-family:var(--mono)}
.btns{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}
.btn{
  display:inline-flex;align-items:center;justify-content:center;gap:10px;
  padding:10px 14px;border-radius:14px;
  border:1px solid var(--line);
  background: rgba(255,255,255,.85);
  box-shadow: var(--sh2);
  text-decoration:none;
  font-weight:950;
}
.btn.primary{border-color:rgba(103,183,255,.55);background:rgba(103,183,255,.18)}
.btn.alpine{border-color:rgba(255,79,216,.24);background:linear-gradient(90deg,rgba(31,163,255,.20),rgba(255,79,216,.16))}

.hr{height:1px;background:var(--line);margin:12px 0}

.dash{
  border-radius: 22px;
  overflow:hidden;
  border:1px solid rgba(0,0,0,.10);
  box-shadow: 0 16px 46px rgba(0,0,0,.18);
  background: linear-gradient(180deg,#0b1220,#070a14);
  color: rgba(255,255,255,.90);
}
.dashTop{
  display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;
  padding:12px 14px;
  border-bottom:1px solid rgba(255,255,255,.10);
  background: linear-gradient(90deg, rgba(31,163,255,.16), rgba(255,79,216,.12));
}
.pillD{
  display:inline-flex;gap:8px;align-items:center;
  padding:6px 10px;border-radius:999px;
  border:1px solid rgba(255,255,255,.14);
  background: rgba(255,255,255,.06);
  font-size:12px;font-weight:900;
}
.dashBody{display:grid;grid-template-columns:320px 1fr 320px;gap:0}
@media (max-width: 980px){ .dashBody{grid-template-columns:1fr} }
.dashCol{padding:12px;border-right:1px solid rgba(255,255,255,.08)}
.dashCol:last-child{border-right:none}
.list{display:flex;flex-direction:column;gap:10px}
.rowD{
  display:flex;justify-content:space-between;gap:10px;align-items:center;
  padding:10px 10px;border-radius:14px;
  border:1px solid rgba(255,255,255,.10);
  background: rgba(255,255,255,.06);
}
.tag{font-family:var(--mono);font-weight:950}
.bigTime{font-family:var(--mono);font-weight:950;font-size:30px}

.footer{
  margin-top:26px;border-top:1px solid var(--line);
  background: rgba(255,255,255,.70);
}
.footerIn{max-width:1120px;margin:0 auto;padding:18px;display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(260px,1fr))}
.footerIn a{display:inline-block;margin:6px 10px 0 0;padding:6px 10px;border:1px solid var(--line);border-radius:999px;background:#fff;text-decoration:none}
.footerIn a:hover{background:rgba(103,183,255,.12);text-decoration:none}
CSS

# robots con sitemap
cat > web/public/robots.txt <<'TXT'
User-agent: *
Allow: /
Sitemap: /sitemap.xml
TXT

echo "==> (2) Layout V2"
backup web/src/layouts/Base.astro
cat > web/src/layouts/Base.astro <<'ASTRO'
---
const {
  title = "Vamos Nene...!!!",
  description = "Centro argentino de F1: qué pasa hoy, horarios ARG, dónde verlo y noticias (foco Colapinto).",
} = Astro.props;

const here = Astro.url.pathname;
const apiBase = import.meta.env.PUBLIC_API_BASE || "";
const nav = [
  ["/vivo","Vivo"],
  ["/calendario/2026","Calendario 2026"],
  ["/noticias","Noticias"],
  ["/colapinto","Colapinto"],
  ["/tienda","Tienda"],
  ["/suscribirme","Suscribirme"],
];
---
<!doctype html>
<html lang="es-AR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={Astro.url.toString()} />
    <meta name="theme-color" content="#67B7FF" />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <link rel="stylesheet" href="/vn.css" />
  </head>
  <body>
    <header class="top">
      <div class="flag"></div>
      <div class="head">
        <a class="brand" href="/">
          <span class="badge43" aria-hidden="true"></span>
          <span>
            <strong>Vamos Nene...!!!</strong>
            <small>F1 en castellano (ARG) · foco Colapinto · #43</small>
          </span>
        </a>

        <nav class="nav">
          {nav.map(([href,label]) => (
            <a class={String(here).startsWith(href) ? "cta" : ""} href={href}>{label}</a>
          ))}
        </nav>
      </div>
    </header>

    <main class="container">
      <slot />
    </main>

    <footer class="footer">
      <div class="footerIn">
        <div>
          <strong>Mapa del sitio</strong><div class="hr"></div>
          <a href="/">Inicio</a>
          <a href="/vivo">Vivo</a>
          <a href="/calendario/2026">Calendario 2026</a>
          <a href="/noticias">Noticias</a>
          <a href="/colapinto">Colapinto</a>
          <a href="/guias/como-ver-f1-en-argentina">Cómo ver F1 (ARG)</a>
          <a href="/guias/glosario-f1">Glosario F1</a>
          <a href="/tienda">Tienda</a>
          <a href="/suscribirme">Suscribirme</a>
          <a href="/privacy">Privacidad</a>
          <a href="/terms">Términos</a>
          <a href="/about">Sobre</a>
          <a href="/contact">Contacto</a>
          <a href="/sitemap.xml">Sitemap</a>
        </div>

        <div>
          <strong>Qué es esto</strong><div class="hr"></div>
          <p class="muted" style="margin:0">
            Un “centro argentino” para resolver rápido: <b>qué hay hoy</b>, <b>horarios ARG</b>, <b>dónde verlo</b> y <b>qué significa</b>.
          </p>
          <div class="hr"></div>
          <p class="muted" style="margin:0">
            Nota: no somos un sitio oficial ni afiliado a Formula 1. Fuentes acreditadas en cada nota.
          </p>
        </div>

        <div>
          <strong>Estado</strong><div class="hr"></div>
          <div class="kpi"><span class="dot"></span> API: <span class="mono">{apiBase}</span></div>
          <p class="muted" style="margin-top:10px">© {new Date().getFullYear()} Vamos Nene...!!!</p>
        </div>
      </div>
    </footer>
  </body>
</html>
ASTRO

echo "==> (3) Páginas V2 (contenido real + claridad)"
# HOME
backup web/src/pages/index.astro
cat > web/src/pages/index.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const now = await fetch(`${api}/api/now`).then(r=>r.json()).catch(()=>({}));
const newsAll = await fetch(`${api}/api/news`).then(r=>r.json()).catch(()=>({items:[]}));
const items = Array.isArray(newsAll.items) ? newsAll.items : [];

// filtro “Colapinto” en cualquier parte (title/snippet/tags)
const col = items.filter(it => {
  const s = `${it.title||""} ${it.snippet||""} ${it.tags||""}`.toLowerCase();
  return s.includes("colapinto") || s.includes("franco colapinto");
}).slice(0,6);

function fmtAR(iso){
  if(!iso) return "—";
  const d = new Date(iso); if(isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"full", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}

const current = now?.current || null;
const next = now?.next || null;

const status = current ? "EN VIVO" : (next ? "PRÓXIMO" : "SIN DATOS");
const headline = current ? `${current.event_name}: ${current.session_name}` : (next ? `${next.event_name}: ${next.session_name}` : "Calendario 2026 + noticias");
const when = current ? `${fmtAR(current.start_time)} → ${fmtAR(current.end_time)}` : (next ? `${fmtAR(next.start_time)} (ARG)` : "—");
---
<Base title="Vamos Nene...!!! — Centro argentino de F1" description="Qué pasa hoy en F1, horarios ARG, dónde verlo y noticias (Colapinto).">
  <section class="hero">
    <img src="/assets/hero-vn.svg" alt="Vamos Nene...!!!" loading="eager" />
    <div class="heroBody">
      <h1 class="h1">Centro argentino de F1 (foco Colapinto)</h1>
      <p class="sub">Entrás y en 10 segundos sabés: <b>qué hay hoy</b>, <b>a qué hora (ARG)</b>, <b>dónde verlo</b> y <b>qué significa</b>.</p>
      <div class="kpis">
        <span class="kpi"><span class="dot"></span> {status}</span>
        <span class="kpi"><span class="dot"></span> {headline}</span>
        <span class="kpi"><span class="dot"></span> {when}</span>
      </div>
      <div class="btns">
        <a class="btn primary" href="/vivo">Abrir VIVO</a>
        <a class="btn" href="/calendario/2026">Calendario 2026</a>
        <a class="btn alpine" href="/guias/como-ver-f1-en-argentina">Dónde verlo (ARG)</a>
      </div>
      <p class="muted" style="margin-top:10px">Actualizado: {fmtAR(now?.now)}</p>
    </div>
  </section>

  <section class="grid">
    <div class="card">
      <h2>Hoy / Próximo</h2>
      <p class="muted" style="margin-top:0">Esto es lo que mirás antes de abrir “Vivo”.</p>
      <div class="hr"></div>

      {current ? (
        <>
          <div><b>Ahora:</b> {current.event_name} — {current.session_name}</div>
          <div class="muted">{fmtAR(current.start_time)} → {fmtAR(current.end_time)}</div>
        </>
      ) : (
        <div class="muted">No hay sesión en curso.</div>
      )}

      <div class="hr"></div>

      {next ? (
        <>
          <div><b>Próximo:</b> {next.event_name} — {next.session_name}</div>
          <div class="muted">{fmtAR(next.start_time)} (ARG)</div>
        </>
      ) : (
        <div class="muted">Sin próximo evento cargado.</div>
      )}

      <div class="btns">
        <a class="btn primary" href="/vivo">Ver dashboard</a>
      </div>
    </div>

    <div class="card">
      <h2>Noticias (Colapinto)</h2>
      <p class="muted" style="margin-top:0">Titulares + una nota editorial corta para entender el impacto.</p>
      <div class="hr"></div>

      {col.length ? (
        <ol class="muted" style="margin:0;padding-left:18px">
          {col.map(n => (
            <li style="margin:10px 0">
              <a href="/noticias">{n.title}</a>
              <div class="muted" style="font-size:12px">{n.source_name || n.source_code || ""}</div>
            </li>
          ))}
        </ol>
      ) : (
        <div class="muted">Todavía no hay suficientes noticias filtradas por “Colapinto”.</div>
      )}

      <div class="btns">
        <a class="btn primary" href="/noticias">Ver todas</a>
      </div>
    </div>

    <div class="card">
      <h2>Contenido “Google-friendly” (para AdSense)</h2>
      <p class="muted" style="margin-top:0">Páginas evergreen que generan tráfico orgánico y tiempo de lectura.</p>
      <div class="hr"></div>
      <ul class="muted" style="margin:0;padding-left:18px">
        <li><a href="/colapinto">Colapinto: bio + timeline</a></li>
        <li><a href="/guias/como-ver-f1-en-argentina">Cómo ver F1 en Argentina</a></li>
        <li><a href="/guias/glosario-f1">Glosario F1</a></li>
      </ul>
    </div>
  </section>
</Base>
ASTRO

# VIVO (dashboard 3 paneles tipo f1-dash)
backup web/src/pages/vivo.astro
cat > web/src/pages/vivo.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const now = await fetch(`${api}/api/now`).then(r=>r.json()).catch(()=>({}));
const weather = await fetch(`${api}/api/weather`).then(r=>r.json()).catch(()=>({}));
const newsAll = await fetch(`${api}/api/news`).then(r=>r.json()).catch(()=>({items:[]}));
const items = Array.isArray(newsAll.items) ? newsAll.items : [];

const focus = items.filter(it=>{
  const s = `${it.title||""} ${it.snippet||""} ${it.tags||""}`.toLowerCase();
  return s.includes("colapinto") || s.includes("alpine");
}).slice(0,8);

function fmtAR(iso){
  if(!iso) return "—";
  const d = new Date(iso); if(isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"medium", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
const current = now?.current || null;
const next = now?.next || null;
const live = !!current;
const title = live ? `${current.event_name} — ${current.session_name}` : (next ? `${next.event_name} — ${next.session_name}` : "Vivo");
const updated = fmtAR(now?.now);

const w = weather?.weather;
---
<Base title={`Vivo — ${title}`} description="Dashboard argentino: qué pasa hoy, clima, horarios y contexto.">
  <h1 style="margin: 10px 0 6px">Vivo</h1>
  <p class="muted" style="margin:0">
    Esto es un “pit wall” argentino: <b>estado</b>, <b>horarios ARG</b>, <b>dónde verlo</b>, <b>clima</b> y <b>noticias del día</b>.
  </p>

  <div class="dash" style="margin-top:14px">
    <div class="dashTop">
      <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:center">
        <span class="pillD">{live ? "🟢 EN VIVO" : "🟡 PRÓXIMO"}</span>
        <span class="pillD"><b>{title}</b></span>
        <span class="pillD">Actualizado: <span class="mono">{updated}</span></span>
      </div>
      <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:center">
        <span class="pillD">ARG</span>
        <span class="pillD">#43</span>
      </div>
    </div>

    <div class="dashBody">
      <!-- IZQ: “tabla” -->
      <aside class="dashCol">
        <div class="pillD" style="margin-bottom:10px">Resumen de jornada</div>
        <div class="list">
          <div class="rowD">
            <div>
              <div class="tag">Ahora</div>
              <div style="opacity:.78;font-size:12px">{current ? current.session_name : "—"}</div>
            </div>
            <div class="mono">{current ? fmtAR(current.start_time).split(", ").pop() : "—"}</div>
          </div>

          <div class="rowD">
            <div>
              <div class="tag">Próximo</div>
              <div style="opacity:.78;font-size:12px">{next ? next.session_name : "—"}</div>
            </div>
            <div class="mono">{next ? fmtAR(next.start_time).split(", ").pop() : "—"}</div>
          </div>

          <div class="rowD">
            <div>
              <div class="tag">Dónde verlo</div>
              <div style="opacity:.78;font-size:12px">Guía (ARG)</div>
            </div>
            <a class="pillD" href="/guias/como-ver-f1-en-argentina">Abrir</a>
          </div>

          <div class="rowD">
            <div>
              <div class="tag">Calendario</div>
              <div style="opacity:.78;font-size:12px">Temporada 2026</div>
            </div>
            <a class="pillD" href="/calendario/2026">Ver</a>
          </div>
        </div>
      </aside>

      <!-- CENTRO: “visual” (placeholder listo para track map real cuando haya feed) -->
      <section class="dashCol">
        <div class="pillD" style="margin-bottom:10px">Centro (visual)</div>
        <div class="rowD" style="justify-content:space-between">
          <div>
            <div class="tag">Mapa / Track</div>
            <div style="opacity:.78;font-size:12px">Cuando haya feed, acá va el track map tipo f1-dash</div>
          </div>
          <div class="bigTime">{live ? "LIVE" : "NEXT"}</div>
        </div>
        <div style="margin-top:12px;opacity:.9;font-size:13px">
          <b>Qué vas a ver acá (V2):</b>
          <ul style="margin:8px 0 0;padding-left:18px;opacity:.82">
            <li>Track map + puntos (si hay datos)</li>
            <li>Tabla izquierda con “estado” y foco #43</li>
            <li>Contexto derecha: clima + titulares del día</li>
          </ul>
        </div>
      </section>

      <!-- DER: contexto -->
      <aside class="dashCol">
        <div class="pillD" style="margin-bottom:10px">Contexto</div>

        <div class="rowD">
          <div>
            <div class="tag">Clima</div>
            <div style="opacity:.78;font-size:12px">{weather?.event_slug || "—"}</div>
          </div>
          <div class="mono">{w ? "OK" : "—"}</div>
        </div>

        <div style="margin-top:12px" class="pillD">Titulares (Colapinto/Alpine)</div>
        <div class="list" style="margin-top:10px">
          {focus.length ? focus.slice(0,5).map(n => (
            <a class="rowD" href="/noticias" style="text-decoration:none">
              <div style="min-width:0">
                <div style="font-weight:900;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{n.title}</div>
                <div style="opacity:.72;font-size:12px">{n.source_name || n.source_code || ""}</div>
              </div>
              <span class="pillD">→</span>
            </a>
          )) : (
            <div style="opacity:.78;font-size:12px">Sin suficientes items filtrados.</div>
          )}
        </div>
      </aside>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h2>Qué es “Vivo”</h2>
      <p class="muted" style="margin-top:0">
        Un panel para quedarte: refresca contexto (no sólo links). Próximo paso: track map real cuando haya fuente viable sin USD.
      </p>
      <div class="btns">
        <a class="btn primary" href="/suscribirme">Recibir avisos (72hs antes)</a>
        <a class="btn alpine" href="/noticias">Noticias del día</a>
      </div>
    </div>

    <div class="card">
      <h2>Disclaimer</h2>
      <p class="muted" style="margin-top:0">
        No oficial / no afiliado a F1. Las fuentes se acreditan. El objetivo es informar y contextualizar (ARG + #43).
      </p>
    </div>
  </div>
</Base>
ASTRO

# NOTICIAS (colapinto) — simple, claro
backup web/src/pages/noticias.astro
cat > web/src/pages/noticias.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const newsAll = await fetch(`${api}/api/news`).then(r=>r.json()).catch(()=>({items:[]}));
const items = Array.isArray(newsAll.items) ? newsAll.items : [];

const filtered = items.filter(it=>{
  const s = `${it.title||""} ${it.snippet||""} ${it.tags||""}`.toLowerCase();
  return s.includes("colapinto") || s.includes("franco colapinto");
}).slice(0,30);

function clean(s){
  return String(s||"").replace(/\s+/g," ").trim();
}
---
<Base title="Noticias (Colapinto) — Vamos Nene...!!!" description="Noticias filtradas por Colapinto con nota editorial corta.">
  <h1 style="margin: 10px 0 6px">Noticias (Colapinto)</h1>
  <p class="muted" style="margin:0">
    Qué vas a ver: titulares donde aparece <b>Colapinto</b> (en título o snippet), con <b>Notas de la Redacción</b> automatizadas.
    Fuentes acreditadas en cada item.
  </p>

  <div class="card" style="margin-top:14px">
    <h2 style="margin:0 0 8px">Últimos items</h2>
    <div class="muted" style="margin-bottom:12px">Total filtrados: {filtered.length}</div>

    {filtered.length ? filtered.map(n => (
      <article class="card" style="box-shadow:none;margin:12px 0;background:rgba(103,183,255,.08)">
        <div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start">
          <div style="min-width:0">
            <a href={n.url} target="_blank" rel="noopener noreferrer" style="font-weight:950;text-decoration:none">
              {clean(n.title)}
            </a>
            <div class="muted" style="font-size:12px;margin-top:4px">
              Fuente: <b>{n.source_name || n.source_code || ""}</b>
            </div>
            {n.snippet ? <p class="muted" style="margin:8px 0 0">{clean(n.snippet)}</p> : null}
          </div>
          <span class="kpi"><span class="dot"></span> #43</span>
        </div>

        {n.auto_note ? (
          <div style="margin-top:10px;border:1px dashed rgba(11,18,32,.18);border-radius:14px;padding:10px;background:#fff">
            <div style="font-weight:950">Notas de la Redacción</div>
            <div class="muted" style="margin-top:6px">{clean(n.auto_note)}</div>
          </div>
        ) : null}
      </article>
    )) : (
      <div class="muted">No hay items suficientes aún. Corré el sync admin o esperá el cron.</div>
    )}
  </div>
</Base>
ASTRO

# CALENDARIO 2026
backup web/src/pages/calendario/2026.astro
cat > web/src/pages/calendario/2026.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const ev = await fetch(`${api}/api/events`).then(r=>r.json()).catch(()=>({events:[]}));
const events = Array.isArray(ev.events) ? ev.events : [];

function fmtAR(iso){
  if(!iso) return "—";
  const d = new Date(iso); if(isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"medium", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Calendario 2026 — Vamos Nene...!!!" description="Calendario F1 2026 en español con foco Argentina (#43).">
  <h1 style="margin: 10px 0 6px">Calendario 2026</h1>
  <p class="muted" style="margin:0">
    Qué vas a ver: todos los Grandes Premios con link al detalle (horarios, clima, guía para verlo en ARG).
  </p>

  <div class="card" style="margin-top:14px">
    <h2 style="margin:0 0 8px">Grandes Premios</h2>

    {events.length ? (
      <div class="grid" style="margin-top:12px">
        {events.map(e => (
          <a class="card" href={`/gran-premio/${e.event_slug}`} style="text-decoration:none">
            <div class="kpi"><span class="dot"></span> {e.event_name}</div>
            <div class="muted" style="margin-top:8px">Inicio: {fmtAR(e.start_time)}</div>
            <div class="muted">País: {e.country || "—"} · Circuito: {e.circuit_name || "—"}</div>
            <div class="btns"><span class="btn primary">Abrir detalle</span></div>
          </a>
        ))}
      </div>
    ) : (
      <div class="muted">Sin eventos aún. Corré sync admin.</div>
    )}
  </div>
</Base>
ASTRO

# COLAPINTO (contenido evergreen)
cat > web/src/pages/colapinto.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
---
<Base title="Colapinto — bio y contexto (ARG)" description="Biografía, timeline y contexto argentino para seguir a Colapinto (#43).">
  <h1 style="margin: 10px 0 6px">Colapinto (ARG) · #43</h1>
  <p class="muted" style="margin:0">
    Esta página es “evergreen”: bio, hitos, cómo leer su rendimiento y qué mirar en un fin de semana.
  </p>

  <div class="grid" style="margin-top:14px">
    <div class="card">
      <h2>Bio (resumen)</h2>
      <p class="muted" style="margin-top:0">
        Versión corta para el público general. (V2: agregamos timeline por año y links a fuentes).
      </p>
      <div class="hr"></div>
      <ul class="muted" style="margin:0;padding-left:18px">
        <li>Quién es / por qué importa para Argentina</li>
        <li>Qué mirar: ritmo, consistencia, gestión y contexto</li>
        <li>Relación con el equipo (Alpine) y oportunidades</li>
      </ul>
    </div>

    <div class="card">
      <h2>Cómo leer un fin de semana</h2>
      <p class="muted" style="margin-top:0">
        Lo que el fan argentino necesita para no quedarse sólo con titulares.
      </p>
      <div class="hr"></div>
      <ul class="muted" style="margin:0;padding-left:18px">
        <li>FP: cargas/combustible/compuestos</li>
        <li>Qualy: ventanas de pista + tráfico</li>
        <li>Carrera: estrategia y degradación</li>
      </ul>
    </div>

    <div class="card">
      <h2>Links útiles</h2>
      <div class="btns">
        <a class="btn primary" href="/vivo">Vivo</a>
        <a class="btn" href="/noticias">Noticias</a>
        <a class="btn alpine" href="/guias/glosario-f1">Glosario</a>
      </div>
    </div>
  </div>
</Base>
ASTRO

# GUIAS (contenido para SEO)
cat > web/src/pages/guias/como-ver-f1-en-argentina.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Cómo ver F1 en Argentina — guía" description="Dónde ver F1 en Argentina: opciones típicas, recomendaciones y checklist.">
  <h1 style="margin: 10px 0 6px">Cómo ver F1 en Argentina</h1>
  <p class="muted" style="margin:0">
    Página evergreen para búsquedas: “dónde ver F1 en Argentina”, “a qué hora”, “por dónde”.
  </p>

  <div class="grid" style="margin-top:14px">
    <div class="card">
      <h2>Checklist rápido</h2>
      <ul class="muted" style="margin:0;padding-left:18px">
        <li>Zona horaria: siempre mostramos <b>ARG</b></li>
        <li>Confirmar si hay Sprint</li>
        <li>Canales / apps según tu proveedor</li>
      </ul>
    </div>

    <div class="card">
      <h2>Proveedores (plantilla V2)</h2>
      <p class="muted" style="margin-top:0">
        (V2) Tabla por proveedor: Flow / DGO / Telecentro / Movistar / Disney+ + links oficiales.
      </p>
    </div>

    <div class="card">
      <h2>72hs antes</h2>
      <p class="muted" style="margin-top:0">
        Suscribite y te llega cronograma + pronóstico + dónde verlo.
      </p>
      <div class="btns">
        <a class="btn primary" href="/suscribirme">Suscribirme</a>
      </div>
    </div>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/glosario-f1.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Glosario F1 — Vamos Nene...!!!" description="Glosario simple de F1 en castellano (ARG).">
  <h1 style="margin: 10px 0 6px">Glosario F1</h1>
  <p class="muted" style="margin:0">
    Para que el público general entienda rápido: DRS, undercut, stint, delta, etc.
  </p>

  <div class="card" style="margin-top:14px">
    <h2 style="margin:0 0 8px">Términos</h2>
    <div class="hr"></div>
    <ul class="muted" style="margin:0;padding-left:18px">
      <li><b>Stint</b>: tramo de carrera con un set de neumáticos</li>
      <li><b>Undercut</b>: parar antes para ganar con vuelta rápida</li>
      <li><b>Overcut</b>: estirar para entrar con pista limpia</li>
      <li><b>Delta</b>: referencia de tiempo objetivo (pace)</li>
      <li><b>DRS</b>: reducción de drag en zonas habilitadas</li>
    </ul>
  </div>
</Base>
ASTRO

# SUSCRIBIRME (unifica alerts)
backup web/src/pages/suscribirme.astro
cat > web/src/pages/suscribirme.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;
---
<Base title="Suscribirme — Vamos Nene...!!!" description="Recibir avisos 72hs antes: cronograma ARG, dónde verlo y clima.">
  <h1 style="margin: 10px 0 6px">Suscribirme</h1>
  <p class="muted" style="margin:0">
    Te avisamos <b>72hs antes</b>: cronograma (ARG), dónde verlo y pronóstico. (Gratis)
  </p>

  <div class="grid" style="margin-top:14px">
    <div class="card">
      <h2>Qué vas a recibir</h2>
      <ul class="muted" style="margin:0;padding-left:18px">
        <li>Cronograma del GP en horario ARG</li>
        <li>Links útiles (oficiales) para verlo</li>
        <li>Pronóstico y tips (ropa/horarios)</li>
      </ul>
    </div>

    <div class="card">
      <h2>Suscripción</h2>
      <p class="muted" style="margin-top:0">Se guarda tu email en nuestra base (Cloudflare D1).</p>
      <div class="hr"></div>
      <form id="subForm">
        <label class="muted">Email</label><br/>
        <input id="email" type="email" required placeholder="tu@email.com"
          style="width:100%;padding:12px;border-radius:14px;border:1px solid rgba(11,18,32,.20);margin-top:6px"/>
        <div class="btns">
          <button class="btn primary" type="submit">Suscribirme</button>
        </div>
        <div id="msg" class="muted" style="margin-top:10px"></div>
      </form>
      <script type="module">
        const api = ${JSON.stringify(String(api||""))};
        const form = document.getElementById("subForm");
        const email = document.getElementById("email");
        const msg = document.getElementById("msg");
        form.addEventListener("submit", async (e) => {
          e.preventDefault();
          msg.textContent = "Enviando…";
          const r = await fetch(api + "/api/subscribe", {
            method:"POST",
            headers:{ "content-type":"application/json" },
            body: JSON.stringify({ email: email.value })
          });
          const j = await r.json().catch(()=>({}));
          msg.textContent = j.ok ? "Listo. Te vamos a avisar." : ("Error: " + (j.error || "no se pudo"));
        });
      </script>
    </div>
  </div>
</Base>
ASTRO

# TIENDA (placeholder visual mejor)
backup web/src/pages/tienda.astro
cat > web/src/pages/tienda.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
---
<Base title="Tienda — Vamos Nene...!!!" description="Merch Argentina: 43, celeste/blanco, Vamos Nene...!!!">
  <h1 style="margin: 10px 0 6px">Tienda</h1>
  <p class="muted" style="margin:0">
    Merch con identidad ARG (#43). (V2) Checkout puede ser afiliados / impresión bajo demanda.
  </p>

  <div class="grid" style="margin-top:14px">
    {["Remera","Buzo","Gorra"].map(p => (
      <div class="card">
        <h2 style="margin:0 0 8px">{p} “Vamos Nene…!!!”</h2>
        <div class="kpi"><span class="dot"></span> Celeste/Blanco · #43</div>
        <div class="hr"></div>
        <div class="muted">Talles: S / M / L / XL · Colores: celeste / blanco</div>
        <div class="btns">
          <a class="btn primary" href="/contact">Quiero comprar</a>
          <a class="btn alpine" href="/suscribirme">Avisame stock</a>
        </div>
      </div>
    ))}
  </div>
</Base>
ASTRO

# Redirects desde rutas viejas (si existen)
mkdir -p web/src/pages/news web/src/pages/calendar
cat > web/src/pages/live.astro <<'ASTRO'
---
return Astro.redirect("/vivo", 301);
---
ASTRO
cat > web/src/pages/merch.astro <<'ASTRO'
---
return Astro.redirect("/tienda", 301);
---
ASTRO
cat > web/src/pages/alerts.astro <<'ASTRO'
---
return Astro.redirect("/suscribirme", 301);
---
ASTRO
cat > web/src/pages/news/index.astro <<'ASTRO'
---
return Astro.redirect("/noticias", 301);
---
ASTRO
cat > web/src/pages/calendar/2026.astro <<'ASTRO'
---
return Astro.redirect("/calendario/2026", 301);
---
ASTRO

# Sitemap (simple)
cat > web/src/pages/sitemap.xml.ts <<'TS'
export const prerender = false;

export async function GET({ request }: { request: Request }) {
  const origin = new URL(request.url).origin;
  const paths = [
    "/", "/vivo", "/calendario/2026", "/noticias", "/colapinto",
    "/guias/como-ver-f1-en-argentina", "/guias/glosario-f1",
    "/tienda", "/suscribirme",
    "/privacy", "/terms", "/about", "/contact", "/gran-premio/"
  ];
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${paths.map(p => `  <url><loc>${origin}${p}</loc></url>`).join("\n")}
</urlset>`;
  return new Response(xml, {
    headers: { "content-type":"application/xml; charset=utf-8", "cache-control":"public, max-age=300" }
  });
}
TS

echo "OK. Cambios V2 listos en /web."
echo
echo "Siguiente:"
echo "  git add -A"
echo "  git commit -m \"V2: cambio rotundo (identidad ARG+F1, home/vivo, contenido evergreen)\""
echo "  git push"
echo
echo "Cloudflare Pages redeploya con el push."
