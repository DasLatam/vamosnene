#!/usr/bin/env bash
set -euo pipefail

[ -d "web" ] && [ -d "api" ] || { echo "ERROR: ejecutá en la raíz del repo (deben existir ./web y ./api)"; exit 1; }

echo "==> (1) Brand assets"
mkdir -p web/public/brand web/src/layouts web/src/pages/guias

cat > web/public/brand/logo.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="54" viewBox="0 0 220 54">
  <defs>
    <linearGradient id="flag" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#67B7FF"/>
      <stop offset="0.50" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#67B7FF"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="54" height="54" rx="18" fill="url(#flag)"/>
  <circle cx="16" cy="16" r="7" fill="#ffcc33"/>
  <text x="27" y="38" text-anchor="middle" font-size="22" font-family="system-ui" font-weight="900" fill="#0b1220">43</text>
  <text x="70" y="28" font-size="20" font-family="system-ui" font-weight="950" fill="#0b1220">Vamos Nene...!!!</text>
  <text x="70" y="44" font-size="12" font-family="system-ui" font-weight="700" fill="rgba(11,18,32,.70)">F1 en castellano · foco Colapinto</text>
</svg>
SVG

cat > web/public/favicon.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#67B7FF"/>
      <stop offset="0.50" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#67B7FF"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="28" fill="url(#g)"/>
  <circle cx="34" cy="34" r="12" fill="#ffcc33" opacity="0.92"/>
  <text x="64" y="86" text-anchor="middle" font-size="58" font-family="system-ui" font-weight="950" fill="#0b1220">43</text>
</svg>
SVG

cat > web/public/og.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#67B7FF"/>
      <stop offset="0.55" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#67B7FF"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <circle cx="220" cy="160" r="50" fill="#ffcc33" opacity="0.95"/>
  <text x="220" y="360" text-anchor="middle" font-size="170" font-family="system-ui" font-weight="950" fill="#0b1220">43</text>
  <text x="360" y="260" font-size="72" font-family="system-ui" font-weight="950" fill="#0b1220">Vamos Nene...!!!</text>
  <text x="360" y="340" font-size="34" font-family="system-ui" font-weight="800" fill="rgba(11,18,32,.75)">Dashboard + noticias + calendario F1 en castellano</text>
  <text x="360" y="400" font-size="28" font-family="system-ui" font-weight="700" fill="rgba(11,18,32,.70)">Identidad ARG · foco Colapinto · horarios Argentina</text>
</svg>
SVG

echo "==> (2) Global CSS (Portal claro) + Dashboard oscuro estilo F1"
cat > web/public/app.css <<'CSS'
:root{
  --arg-sky:#67B7FF;
  --arg-sky2:#9ad3ff;
  --arg-white:#ffffff;
  --sun:#ffcc33;

  --alpine-blue:#0ea5e9;
  --alpine-pink:#ff4fd8;

  --text:#0b1220;
  --muted:rgba(11,18,32,.72);
  --border:rgba(11,18,32,.12);
  --panel:#ffffff;
  --bg:#f5fbff;

  --radius:18px;
  --shadow:0 14px 40px rgba(11,18,32,.10);

  --mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  --sans: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, sans-serif;
}

*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0;
  font-family:var(--sans);
  color:var(--text);
  background:
    radial-gradient(900px 520px at 15% -10%, rgba(103,183,255,.55), transparent 70%),
    radial-gradient(800px 520px at 92% -10%, rgba(255,79,216,.12), transparent 65%),
    linear-gradient(180deg, var(--bg), #ffffff 70%);
}

a{color:inherit;text-decoration:none}
a:hover{text-decoration:underline}

.container{max-width:1120px;margin:0 auto;padding:18px}
h1{margin:10px 0 6px;font-size:34px;letter-spacing:.2px}
h2{margin:14px 0 8px;font-size:22px}
p{margin:8px 0}

.topbar{
  position:sticky;top:0;z-index:50;
  backdrop-filter: blur(10px);
  background: rgba(245,251,255,.78);
  border-bottom:1px solid var(--border);
}
.topbarInner{
  max-width:1120px;margin:0 auto;padding:12px 18px;
  display:flex;align-items:center;justify-content:space-between;gap:14px;
}
.brand{display:flex;align-items:center;gap:12px}
.brand a{display:flex;align-items:center;gap:12px}
.brand img{height:38px}
.nav{display:flex;flex-wrap:wrap;gap:10px;justify-content:flex-end}
.nav a{
  padding:8px 12px;border-radius:999px;border:1px solid transparent;
  color:rgba(11,18,32,.88);font-weight:850;
}
.nav a:hover{background:rgba(103,183,255,.12);border-color:rgba(103,183,255,.30);text-decoration:none}
.nav a.active{background:rgba(103,183,255,.18);border-color:rgba(103,183,255,.55)}

.card{
  background:var(--panel);
  border:1px solid var(--border);
  border-radius:var(--radius);
  box-shadow:var(--shadow);
  padding:16px;
  margin:14px 0;
}

.grid{display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(280px,1fr))}
.row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}

.badge{
  display:inline-flex;align-items:center;gap:8px;
  padding:6px 12px;border-radius:999px;
  border:1px solid var(--border);
  background:rgba(255,255,255,.72);
  font-weight:850;font-size:12px;
}
.badge .dot{width:8px;height:8px;border-radius:99px;background:var(--sun);box-shadow:0 0 0 4px rgba(255,204,51,.18)}
.muted{color:var(--muted)}
.kpi{font-family:var(--mono);font-weight:900}

.btn{
  display:inline-flex;align-items:center;justify-content:center;gap:10px;
  padding:10px 14px;border-radius:14px;border:1px solid var(--border);
  background:rgba(255,255,255,.8);
  box-shadow:0 10px 24px rgba(11,18,32,.10);
  font-weight:900;
}
.btn:hover{background:rgba(103,183,255,.12);text-decoration:none}
.btn.primary{
  border-color:rgba(103,183,255,.55);
  background:linear-gradient(180deg, rgba(103,183,255,.25), rgba(255,255,255,.92));
}
.btn.alpine{
  border-color:rgba(11,18,32,.12);
  background:linear-gradient(90deg, rgba(14,165,233,.85), rgba(255,79,216,.65));
  color:#071019;
}

.hr{height:1px;background:var(--border);margin:12px 0}

/* ===== DASHBOARD (modo F1) ===== */
.dashboard body{} /* (clase en <body> desde layout) */

.dashboard{
  background:
    radial-gradient(900px 520px at 20% 0%, rgba(14,165,233,.18), transparent 60%),
    radial-gradient(900px 520px at 85% 0%, rgba(255,79,216,.12), transparent 60%),
    linear-gradient(180deg, #070b18, #050816 65%);
  color: rgba(255,255,255,.92);
}
.dashboard .topbar{background:rgba(7,11,24,.72);border-bottom:1px solid rgba(255,255,255,.10)}
.dashboard .nav a{color:rgba(255,255,255,.86)}
.dashboard .nav a:hover{background:rgba(255,255,255,.08);border-color:rgba(255,255,255,.14)}
.dashboard .nav a.active{background:rgba(255,255,255,.10);border-color:rgba(255,255,255,.18)}
.dashboard .card{background:rgba(255,255,255,.06);border-color:rgba(255,255,255,.12);box-shadow:0 16px 44px rgba(0,0,0,.30)}
.dashboard .badge{background:rgba(255,255,255,.06);border-color:rgba(255,255,255,.14);color:rgba(255,255,255,.88)}
.dashboard .muted{color:rgba(255,255,255,.70)}
.dashboard .btn{background:rgba(255,255,255,.10);border-color:rgba(255,255,255,.14);color:rgba(255,255,255,.92)}
.dashboard .btn:hover{background:rgba(255,255,255,.14)}
.dashboard .btn.primary{background:linear-gradient(180deg, rgba(103,183,255,.25), rgba(255,255,255,.10));border-color:rgba(103,183,255,.35)}
.dashboard .hr{background:rgba(255,255,255,.10)}

.dashLayout{
  display:grid;gap:14px;
  grid-template-columns: 300px 1fr 360px;
}
@media (max-width: 1100px){ .dashLayout{grid-template-columns:1fr} }

.sideList{
  display:flex;flex-direction:column;gap:10px;
}
.driverRow{
  display:flex;align-items:center;justify-content:space-between;gap:10px;
  padding:10px 12px;border-radius:14px;
  border:1px solid rgba(255,255,255,.12);
  background:rgba(255,255,255,.06);
}
.driverTag{font-family:var(--mono);font-weight:950;font-size:12px}
.driverName{font-weight:900}
.small{font-size:12px}
.trackBox{
  border-radius:18px;
  border:1px solid rgba(255,255,255,.12);
  background:linear-gradient(180deg, rgba(0,0,0,.30), rgba(0,0,0,.18));
  overflow:hidden;
}
.trackTop{
  display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between;
  padding:12px 14px;border-bottom:1px solid rgba(255,255,255,.10);
}
.trackCanvasWrap{padding:12px}
CSS

echo "==> (3) Base layout (portal + dashboard class switch)"
cat > web/src/layouts/Base.astro <<'ASTRO'
---
const {
  title = "Vamos Nene...!!!",
  description = "F1 en castellano para Argentina: vivo, calendario, noticias y guías. Foco Colapinto.",
  layout = "portal", // "portal" | "dashboard"
} = Astro.props;

const apiBase = import.meta.env.PUBLIC_API_BASE || "";
const here = Astro.url.pathname;

const nav = [
  { href: "/", label: "Hoy" },
  { href: "/vivo", label: "Vivo" },
  { href: "/calendario/2026", label: "Calendario" },
  { href: "/noticias", label: "Noticias" },
  { href: "/guias/como-ver-f1-en-argentina", label: "Guías" },
  { href: "/tienda", label: "Tienda" },
];

const bodyClass = layout === "dashboard" ? "dashboard" : "";
---
<!doctype html>
<html lang="es-AR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={Astro.url.toString()} />

    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <meta name="theme-color" content="#67B7FF" />
    <link rel="stylesheet" href="/app.css" />

    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:type" content="website" />
    <meta property="og:image" content={new URL("/og.svg", Astro.url).toString()} />
  </head>
  <body class={bodyClass}>
    <header class="topbar">
      <div class="topbarInner">
        <div class="brand">
          <a href="/" aria-label="Ir al inicio">
            <img src="/brand/logo.svg" alt="Vamos Nene...!!!" />
          </a>
        </div>

        <nav class="nav">
          {nav.map((i) => (
            <a class={"navlink " + (here === i.href ? "active" : "")} href={i.href}>{i.label}</a>
          ))}
          <a class="btn alpine" href="/suscribirme">Recibir avisos</a>
        </nav>
      </div>
    </header>

    <main class="container">
      <slot />
    </main>

    <footer class="container" style="padding-top:10px;padding-bottom:28px">
      <div class="card">
        <div class="row" style="justify-content:space-between">
          <div>
            <strong>Mapa del sitio</strong>
            <div class="row" style="margin-top:10px">
              <a class="badge" href="/">Hoy</a>
              <a class="badge" href="/vivo">Vivo</a>
              <a class="badge" href="/calendario/2026">Calendario</a>
              <a class="badge" href="/noticias">Noticias</a>
              <a class="badge" href="/guias/como-ver-f1-en-argentina">Guías</a>
              <a class="badge" href="/tienda">Tienda</a>
              <a class="badge" href="/suscribirme">Suscribirme</a>
              <a class="badge" href="/about">Sobre</a>
              <a class="badge" href="/contact">Contacto</a>
              <a class="badge" href="/privacy">Privacidad</a>
              <a class="badge" href="/terms">Términos</a>
              <a class="badge" href="/sitemap.xml">Sitemap</a>
            </div>
          </div>
          <div class="badge">API: <span class="kpi">{apiBase}</span></div>
        </div>
        <div class="hr"></div>
        <p class="muted">
          Nota: no somos un sitio oficial ni afiliado a Formula 1. Fuentes acreditadas en cada nota.
        </p>
      </div>
    </footer>
  </body>
</html>
ASTRO

echo "==> (4) Home: que se entienda + contenido (Hoy / Próximo / Guías / CTA)"
cat > web/src/pages/index.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";

const api = import.meta.env.PUBLIC_API_BASE;

let now: any = null;
let events: any = null;
let news: any = null;

async function safeJson(url: string) {
  try {
    const r = await fetch(url, { headers: { "accept": "application/json" } });
    if (!r.ok) return null;
    return await r.json();
  } catch { return null; }
}

if (api) {
  now = await safeJson(`${api}/api/now`);
  events = await safeJson(`${api}/api/events`);
  news = await safeJson(`${api}/api/news`);
}

function fmtAR(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"full", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}

const headline = now?.current
  ? `EN VIVO: ${now.current.event_name} — ${now.current.session_name}`
  : (now?.next ? `Próximo: ${now.next.event_name} — ${now.next.session_name}` : "Calendario, noticias y guías (Colapinto)");

const topNews = Array.isArray(news?.items) ? news.items.slice(0, 6) : [];
const nextEvents = Array.isArray(events?.events) ? events.events.slice(0, 6) : [];
---
<Base title={`Vamos Nene...!!! — ${headline}`} description="Dashboard y portal F1 para Argentina. Hoy: qué pasa, qué viene y cómo verlo.">
  <div class="card" style="background:linear-gradient(90deg, rgba(103,183,255,.22), rgba(255,255,255,.92));">
    <div class="row" style="justify-content:space-between">
      <div>
        <h1 style="margin:0">Vamos Nene...!!!</h1>
        <p class="muted" style="margin:6px 0 0">
          <strong>Qué hay acá:</strong> <span class="kpi">Vivo</span> (dashboard), <span class="kpi">calendario</span> (horarios ARG), <span class="kpi">noticias</span> (Colapinto) y <span class="kpi">guías</span>.
        </p>
      </div>
      <div class="row">
        <span class="badge"><span class="dot"></span> Identidad ARG · #43</span>
        <a class="btn primary" href="/vivo">Abrir Dashboard Vivo</a>
      </div>
    </div>

    <div class="hr"></div>

    <div class="grid">
      <div class="card" style="box-shadow:none">
        <h2 style="margin-top:0">Estado</h2>
        <div class="badge">{now?.current ? "EN VIVO" : (now?.next ? "PRÓXIMO" : "SIN DATOS")}</div>
        <p class="muted" style="margin-top:10px"><strong>Ahora:</strong> {now?.current ? `${now.current.event_name} — ${now.current.session_name}` : "—"}</p>
        <p class="muted"><strong>Horario ARG:</strong> {now?.current ? `${fmtAR(now.current.start_time)} → ${fmtAR(now.current.end_time)}` : "—"}</p>
        <p class="muted"><strong>Próximo:</strong> {now?.next ? `${now.next.event_name} — ${now.next.session_name} · ${fmtAR(now.next.start_time)}` : "—"}</p>
        <div class="row" style="margin-top:10px">
          <a class="btn" href="/calendario/2026">Ver calendario 2026</a>
          <a class="btn alpine" href="/suscribirme">Avisos 72hs antes</a>
        </div>
      </div>

      <div class="card" style="box-shadow:none">
        <h2 style="margin-top:0">Guía rápida (Argentina)</h2>
        <p class="muted">
          Entrás, ves <strong>qué se corre hoy</strong>, a qué hora en ARG, <strong>dónde verlo</strong> y el clima del circuito.
        </p>
        <div class="row">
          <a class="badge" href="/guias/como-ver-f1-en-argentina">Cómo ver F1 en Argentina</a>
          <a class="badge" href="/guias/colapinto-biografia">Colapinto: bio + historia</a>
          <a class="badge" href="/guias/glosario-f1">Glosario F1</a>
        </div>
      </div>

      <div class="card" style="grid-column:1 / -1; box-shadow:none">
        <h2 style="margin-top:0">Últimas (Colapinto) — con contexto</h2>
        {topNews.length ? (
          <div class="grid">
            {topNews.map((n:any) => (
              <div class="card" style="margin:0; box-shadow:none">
                <div class="badge">Fuente: {n.source || "—"}</div>
                <p style="margin:10px 0 0; font-weight:950">{n.title || "—"}</p>
                <p class="muted" style="margin:8px 0 0">{n.summary || "Sin resumen aún."}</p>
                <div class="row" style="margin-top:10px">
                  {n.url ? <a class="btn" href={n.url} target="_blank" rel="noreferrer">Leer fuente</a> : null}
                  <a class="btn primary" href="/noticias">Ver todas</a>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p class="muted">Todavía no hay noticias cacheadas. Ejecutá el sync del Worker o esperá al cron.</p>
        )}
      </div>

      <div class="card" style="grid-column:1 / -1; box-shadow:none">
        <h2 style="margin-top:0">Próximos Grandes Premios</h2>
        {nextEvents.length ? (
          <div class="grid">
            {nextEvents.map((e:any) => (
              <div class="card" style="margin:0; box-shadow:none">
                <div class="badge">{e.country || "GP"} · {e.circuit_name || "Circuito"}</div>
                <p style="margin:10px 0 0; font-weight:950">{e.event_name || e.name || "—"}</p>
                <p class="muted" style="margin:6px 0 0">Fecha: {e.date || "—"}</p>
                <div class="row" style="margin-top:10px">
                  <a class="btn" href="/calendario/2026">Ver horarios ARG</a>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p class="muted">Sin eventos aún. (Se completa con el sync/calendario)</p>
        )}
      </div>
    </div>
  </div>
</Base>
ASTRO

echo "==> (5) Vivo: dashboard tipo F1 (retención)"
cat > web/src/pages/vivo.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";

const api = import.meta.env.PUBLIC_API_BASE;

let now: any = null;
let news: any = null;

async function safeJson(url: string) {
  try {
    const r = await fetch(url, { headers: { "accept": "application/json" } });
    if (!r.ok) return null;
    return await r.json();
  } catch { return null; }
}

if (api) {
  now = await safeJson(`${api}/api/now`);
  news = await safeJson(`${api}/api/news`);
}

function fmtAR(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"medium", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}

const items = Array.isArray(news?.items) ? news.items.slice(0, 10) : [];
---
<Base layout="dashboard" title="Vivo — Dashboard F1 (ARG) · Vamos Nene...!!!" description="Dashboard estilo F1: estado, horarios ARG, ticker y mapa (beta).">
  <h1 style="margin-top:6px">Dashboard Vivo</h1>
  <p class="muted" style="margin-top:6px">
    Si entrás acá es para saber <strong>qué está pasando</strong>, <strong>a qué hora</strong> y <strong>qué mirar</strong>. Modo “panel” tipo F1.
  </p>

  <div class="dashLayout">
    <!-- LEFT: leaderboard placeholder (para retención visual) -->
    <div class="card">
      <div class="row" style="justify-content:space-between">
        <strong>Tabla (beta)</strong>
        <span class="badge"><span class="dot"></span> Testing / GP</span>
      </div>
      <p class="muted small" style="margin-top:10px">
        En plan gratis, sin feed oficial de posiciones en tiempo real. Igual dejamos el layout listo.
      </p>

      <div class="sideList" style="margin-top:10px">
        {["NOR","VER","LEC","RUS","HAM","PIA","ALO","SAI","PER","COL"].map((c,i)=>(
          <div class="driverRow">
            <div class="row" style="gap:10px">
              <span class="driverTag">{String(i+1).padStart(2,"0")}</span>
              <div>
                <div class="driverName">{c}</div>
                <div class="muted small">stint —</div>
              </div>
            </div>
            <div class="muted small kpi">—</div>
          </div>
        ))}
      </div>
    </div>

    <!-- CENTER: track -->
    <div class="trackBox">
      <div class="trackTop">
        <div class="row">
          <span class="badge">{now?.current ? "EN VIVO" : (now?.next ? "PRÓXIMO" : "SIN DATOS")}</span>
          <span class="badge">Horario ARG: <span class="kpi">{now?.current ? fmtAR(now.current.start_time) : (now?.next ? fmtAR(now.next.start_time) : "—")}</span></span>
        </div>
        <div class="row">
          <a class="btn" href="/calendario/2026">Calendario</a>
          <a class="btn primary" href="/noticias">Noticias</a>
        </div>
      </div>

      <div class="trackCanvasWrap">
        <canvas id="track" width="980" height="520" style="width:100%;height:auto;display:block"></canvas>
      </div>

      <div class="muted small" style="padding:0 14px 14px">
        Mapa (beta): visual tipo F1. Si tu API expone posiciones (ej: OpenF1 con token), acá se anima “en vivo”.
      </div>
    </div>

    <!-- RIGHT: panels -->
    <div>
      <div class="card">
        <strong>Contexto de la jornada</strong>
        <div class="hr"></div>
        <p class="muted"><strong>Ahora:</strong> {now?.current ? `${now.current.event_name} — ${now.current.session_name}` : "—"}</p>
        <p class="muted"><strong>Ventana:</strong> {now?.current ? `${fmtAR(now.current.start_time)} → ${fmtAR(now.current.end_time)}` : "—"}</p>
        <p class="muted"><strong>Próximo:</strong> {now?.next ? `${now.next.event_name} — ${now.next.session_name} · ${fmtAR(now.next.start_time)}` : "—"}</p>
        <div class="row" style="margin-top:10px">
          <a class="btn alpine" href="/suscribirme">Avisos 72hs antes</a>
        </div>
      </div>

      <div class="card">
        <strong>Ticker (Colapinto)</strong>
        <div class="hr"></div>
        {items.length ? (
          <div style="display:flex;flex-direction:column;gap:10px">
            {items.map((n:any)=>(
              <div style="padding:10px 12px;border-radius:14px;border:1px solid rgba(255,255,255,.12);background:rgba(255,255,255,.06)">
                <div class="muted small">{n.source || "Fuente"}</div>
                <div style="font-weight:950;margin-top:6px">{n.title || "—"}</div>
              </div>
            ))}
          </div>
        ) : (
          <p class="muted">Sin noticias cacheadas aún.</p>
        )}
      </div>

      <div class="card">
        <strong>Dónde verlo (ARG)</strong>
        <div class="hr"></div>
        <p class="muted small">
          MVP: bloque informativo. Próximo paso: tabla por proveedor (Flow/DGO/Telecentro/Movistar/Disney+) por sesión.
        </p>
        <ul class="muted small">
          <li>TV: ESPN / Fox Sports (según derechos vigentes)</li>
          <li>Streaming: Disney+ (según derechos vigentes)</li>
        </ul>
      </div>
    </div>
  </div>

  <script type="module">
    // Track placeholder: estilo F1 (pista + glow). Si mañana tenés posiciones reales, acá se reemplaza por fetch+animación.
    const c = document.getElementById("track");
    const ctx = c.getContext("2d");

    function draw(){
      const W = c.width, H = c.height;
      ctx.clearRect(0,0,W,H);

      // fondo
      ctx.fillStyle = "rgba(0,0,0,0)";
      ctx.fillRect(0,0,W,H);

      // pista fake (loop)
      const pts = [];
      for(let t=0;t<Math.PI*2;t+=0.02){
        const x = W/2 + Math.cos(t)*330 + Math.cos(t*3)*50;
        const y = H/2 + Math.sin(t)*180 + Math.sin(t*2)*40;
        pts.push([x,y]);
      }

      // glow
      ctx.lineWidth = 18;
      ctx.strokeStyle = "rgba(255,255,255,0.10)";
      ctx.lineJoin = "round";
      ctx.lineCap = "round";
      ctx.beginPath();
      pts.forEach(([x,y],i)=> i?ctx.lineTo(x,y):ctx.moveTo(x,y));
      ctx.closePath();
      ctx.stroke();

      // track
      ctx.lineWidth = 7;
      ctx.strokeStyle = "rgba(255,255,255,0.75)";
      ctx.beginPath();
      pts.forEach(([x,y],i)=> i?ctx.lineTo(x,y):ctx.moveTo(x,y));
      ctx.closePath();
      ctx.stroke();

      // marker #43
      const p = pts[Math.floor(pts.length*0.72)];
      ctx.beginPath();
      ctx.fillStyle = "rgba(103,183,255,0.28)";
      ctx.arc(p[0],p[1], 18, 0, Math.PI*2);
      ctx.fill();

      ctx.beginPath();
      ctx.fillStyle = "rgba(255,255,255,0.92)";
      ctx.arc(p[0],p[1], 6, 0, Math.PI*2);
      ctx.fill();

      ctx.font = "900 16px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace";
      ctx.fillStyle = "rgba(255,255,255,0.85)";
      ctx.fillText("43", p[0]+12, p[1]-10);
    }

    draw();
    addEventListener("resize", draw);
  </script>
</Base>
ASTRO

echo "==> (6) Noticias: se entiende y se lee"
cat > web/src/pages/noticias.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

let news: any = null;

async function safeJson(url: string) {
  try {
    const r = await fetch(url, { headers: { "accept": "application/json" } });
    if (!r.ok) return null;
    return await r.json();
  } catch { return null; }
}

if (api) news = await safeJson(`${api}/api/news`);

const items = Array.isArray(news?.items) ? news.items : [];
---
<Base title="Noticias (Colapinto) — Vamos Nene...!!!" description="Noticias sobre Colapinto con fuentes acreditadas y contexto.">
  <h1>Noticias</h1>
  <p class="muted">
    Qué ves acá: <strong>notas sobre Colapinto</strong> (o relacionadas) con <strong>fuente acreditada</strong> + resumen.
  </p>

  <div class="card">
    <div class="row" style="justify-content:space-between">
      <span class="badge"><span class="dot"></span> Fuentes por RSS / agregadores</span>
      <a class="btn primary" href="/vivo">Volver al Dashboard</a>
    </div>
  </div>

  {items.length ? (
    <div class="grid">
      {items.slice(0, 24).map((n:any)=>(
        <article class="card" style="margin:0">
          <div class="row" style="justify-content:space-between">
            <span class="badge">Fuente: {n.source || "—"}</span>
            <span class="badge">{n.published_at || "—"}</span>
          </div>
          <h2 style="margin:10px 0 6px;font-size:18px">{n.title || "—"}</h2>
          <p class="muted">{n.summary || "Sin resumen aún."}</p>
          {n.editorial_note ? (
            <div class="card" style="margin:10px 0 0; box-shadow:none; border-color:rgba(11,18,32,.10); background:rgba(103,183,255,.12)">
              <strong>Notas de la Redacción</strong>
              <p class="muted" style="margin-top:6px">{n.editorial_note}</p>
            </div>
          ) : null}
          <div class="row" style="margin-top:10px">
            {n.url ? <a class="btn" href={n.url} target="_blank" rel="noreferrer">Leer fuente</a> : null}
          </div>
        </article>
      ))}
    </div>
  ) : (
    <div class="card">
      <p class="muted">Todavía no hay noticias cacheadas. Ejecutá el sync admin del Worker o esperá al cron.</p>
    </div>
  )}
</Base>
ASTRO

echo "==> (7) Guías evergreen (SEO + contenido real)"
cat > web/src/pages/guias/como-ver-f1-en-argentina.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Cómo ver F1 en Argentina (2026) — Vamos Nene...!!!" description="Guía práctica: opciones de TV/streaming, horarios y tips para seguir F1 en Argentina.">
  <h1>Cómo ver F1 en Argentina (2026)</h1>
  <p class="muted">
    Esta guía existe para que el sitio sea útil incluso cuando no hay carrera. Eso aumenta retención + SEO.
  </p>

  <div class="card">
    <h2 style="margin-top:0">Opciones típicas</h2>
    <ul class="muted">
      <li><strong>TV</strong>: ESPN / Fox Sports (según derechos vigentes).</li>
      <li><strong>Streaming</strong>: Disney+ (según derechos vigentes).</li>
      <li><strong>Tip</strong>: siempre confirmá el canal para cada sesión: prácticas / quali / carrera.</li>
    </ul>
  </div>

  <div class="card">
    <h2 style="margin-top:0">Horarios Argentina</h2>
    <p class="muted">
      En el sitio mostramos todo en <strong>America/Argentina/Buenos_Aires</strong>.
      Para cada GP: viernes (prácticas), sábado (práctica/quali) y domingo (carrera).
    </p>
    <a class="btn primary" href="/calendario/2026">Abrir calendario</a>
  </div>

  <div class="card">
    <h2 style="margin-top:0">Checklist “día de carrera”</h2>
    <ul class="muted">
      <li>Entrá a <a href="/vivo">Vivo</a> y mirá “Ahora / Próximo”.</li>
      <li>Clima del circuito: afecta estrategia, gomas y safety car.</li>
      <li>Leé 2–3 noticias del día para contexto (setup, upgrades, penalizaciones).</li>
    </ul>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/colapinto-biografia.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Colapinto — Bio e historia (ARG) — Vamos Nene...!!!" description="Biografía breve y contexto: por qué Colapinto importa y cómo seguir su temporada.">
  <h1>Colapinto: bio e historia</h1>
  <p class="muted">
    Página “evergreen”: te trae tráfico orgánico todo el año y le da identidad ARG al proyecto.
  </p>

  <div class="card">
    <h2 style="margin-top:0">Por qué este sitio existe</h2>
    <p class="muted">
      Porque un fan argentino quiere: <strong>horarios en ARG</strong>, <strong>contexto</strong>, <strong>qué mirar</strong> y un dashboard simple.
    </p>
    <div class="row">
      <a class="btn primary" href="/vivo">Abrir Vivo</a>
      <a class="btn" href="/noticias">Ver noticias</a>
    </div>
  </div>

  <div class="card">
    <h2 style="margin-top:0">Timeline (placeholder)</h2>
    <p class="muted">
      Acá vamos a generar automáticamente una línea de tiempo con hitos (karting → F4 → F3/F2 → F1).
      (Se completa cuando conectemos fuentes confiables con datos.)
    </p>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/glosario-f1.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Glosario F1 (en castellano) — Vamos Nene...!!!" description="Términos clave: stint, undercut, DRS, parc fermé, etc.">
  <h1>Glosario F1 (castellano)</h1>
  <div class="card">
    <ul class="muted">
      <li><strong>Stint</strong>: tramo de vueltas con el mismo compuesto de neumático.</li>
      <li><strong>Undercut</strong>: parar antes para ganar tiempo con gomas nuevas.</li>
      <li><strong>Overcut</strong>: extender el stint y parar después.</li>
      <li><strong>Parc fermé</strong>: restricciones de cambios importantes post quali.</li>
      <li><strong>DRS</strong>: alerón trasero móvil para facilitar sobrepasos.</li>
    </ul>
  </div>
</Base>
ASTRO

echo "==> (8) robots + sitemap"
mkdir -p web/public
cat > web/public/robots.txt <<'TXT'
User-agent: *
Allow: /
Sitemap: /sitemap.xml
TXT

cat > web/src/pages/sitemap.xml.ts <<'TS'
export const prerender = false;

const STATIC = [
  "/",
  "/vivo",
  "/calendario/2026",
  "/noticias",
  "/tienda",
  "/suscribirme",
  "/about",
  "/contact",
  "/privacy",
  "/terms",
  "/guias/como-ver-f1-en-argentina",
  "/guias/colapinto-biografia",
  "/guias/glosario-f1",
];

function esc(s: string) {
  return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
}

export async function GET({ request }: { request: Request }) {
  const origin = new URL(request.url).origin;
  const urls = STATIC.map(p => `  <url><loc>${esc(origin + p)}</loc></url>`).join("\n");
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>`;
  return new Response(xml, {
    headers: {
      "content-type": "application/xml; charset=utf-8",
      "cache-control": "public, max-age=300"
    }
  });
}
TS

echo
echo "✅ Rediseño v2 aplicado (portal + dashboard)."
echo "Ahora hacé:"
echo "  git add -A"
echo "  git commit -m \"redesign v2: portal + dashboard + identidad ARG/F1\""
echo "  git push"
echo
echo "Cloudflare Pages redeploy automático. Luego probá:"
echo "  /      (portal claro, explica todo)"
echo "  /vivo  (dashboard oscuro tipo F1)"
echo "  /noticias"
echo "  /guias/..."
echo "  /sitemap.xml"
