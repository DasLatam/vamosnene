#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [[ ! -d "web" || ! -d "api" ]]; then
  echo "ERROR: corré esto desde la raíz del repo (debe existir ./web y ./api)."
  exit 1
fi

echo "==> Backup rápido"
mkdir -p .backup
tar -czf ".backup/pre_reboot_$(date +%Y%m%d_%H%M%S).tgz" web/src web/public api/src api/migrations 2>/dev/null || true

echo "==> Assets (ARG + Colapinto + Alpine + Sol)"
mkdir -p web/public/assets

# Wikimedia Commons via Special:FilePath (redirect a archivo real)
curl -L --silent --show-error \
  "https://commons.wikimedia.org/wiki/Special:FilePath/FIA%20F2%20Austria%202024%20Nr.%2012%20Colapinto.jpg?width=1600" \
  -o web/public/assets/colapinto.jpg || true

curl -L --silent --show-error \
  "https://commons.wikimedia.org/wiki/Special:FilePath/BWT%20Alpine%20F1%20Team%20Logo.svg" \
  -o web/public/assets/alpine-logo.svg || true

curl -L --silent --show-error \
  "https://commons.wikimedia.org/wiki/Special:FilePath/Sun_of_May_simplified.svg" \
  -o web/public/assets/sol-de-mayo.svg || true

# Favicon SVG “43” (celeste/blanco + sol)
cat > web/public/favicon.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#74ACDF"/>
      <stop offset="1" stop-color="#FFFFFF"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="56" fill="url(#g)"/>
  <circle cx="200" cy="70" r="28" fill="#F6B100" opacity="0.95"/>
  <g fill="#0B1020" opacity="0.9">
    <text x="50%" y="58%" text-anchor="middle" font-family="system-ui, -apple-system, Segoe UI, Roboto" font-size="110" font-weight="800">43</text>
  </g>
</svg>
SVG

echo "==> Global CSS claro (celeste/blanco + toques Alpine)"
mkdir -p web/src/styles
cat > web/src/styles/global.css <<'CSS'
:root{
  --sky:#74ACDF;
  --sky2:#5AA2DD;
  --white:#FFFFFF;
  --ink:#0B1020;
  --muted:rgba(11,16,32,.68);
  --card:rgba(255,255,255,.92);
  --border:rgba(11,16,32,.12);
  --shadow: 0 10px 30px rgba(11,16,32,.10);
  --alpine:#005AFF;
  --pink:#FF4FD8;
  --sun:#F6B100;
  --radius:18px;
}

*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0;
  color:var(--ink);
  background:
    radial-gradient(1200px 400px at 50% -120px, rgba(116,172,223,.45), transparent 60%),
    linear-gradient(180deg, #EAF6FF 0%, #FFFFFF 55%, #F3F8FF 100%);
  font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, sans-serif;
  line-height:1.5;
}

a{color:var(--alpine); text-decoration:none}
a:hover{text-decoration:underline}
.wrap{max-width:1100px; margin:0 auto; padding:18px}
.muted{color:var(--muted)}
.kicker{letter-spacing:.12em; text-transform:uppercase; font-weight:700; font-size:12px; color:rgba(11,16,32,.55)}
.h1{font-size:42px; line-height:1.05; margin:10px 0 8px}
.h2{font-size:22px; margin:0 0 8px}
.grid{display:grid; gap:14px}
.grid2{grid-template-columns:repeat(2,minmax(0,1fr))}
.grid3{grid-template-columns:repeat(3,minmax(0,1fr))}
@media (max-width:900px){ .grid2,.grid3{grid-template-columns:1fr} }

.card{
  background:var(--card);
  border:1px solid var(--border);
  border-radius:var(--radius);
  box-shadow:var(--shadow);
  padding:16px;
}

.pill{
  display:inline-flex; align-items:center; gap:8px;
  padding:6px 10px; border-radius:999px;
  border:1px solid var(--border);
  background: rgba(255,255,255,.7);
  font-size:12px; color:rgba(11,16,32,.75);
}

.btn{
  display:inline-flex; align-items:center; justify-content:center;
  padding:10px 14px;
  border-radius:14px;
  border:1px solid var(--border);
  background:#fff;
  color:var(--ink);
  font-weight:700;
  box-shadow: 0 6px 18px rgba(11,16,32,.08);
}
.btn:hover{transform: translateY(-1px); text-decoration:none}
.btn.primary{
  border-color: rgba(0,90,255,.22);
  background: linear-gradient(180deg, rgba(116,172,223,.95), rgba(255,255,255,.92));
}
.btn.alpine{
  background: linear-gradient(135deg, rgba(0,90,255,.95), rgba(255,79,216,.80));
  border-color: rgba(0,90,255,.25);
  color:#fff;
}

header.top{
  position:sticky; top:0; z-index:50;
  backdrop-filter: blur(10px);
  background: rgba(255,255,255,.72);
  border-bottom:1px solid rgba(11,16,32,.10);
}
.brand{
  display:flex; align-items:center; gap:10px;
  font-weight:900;
  color:var(--ink);
}
.brand img{width:32px; height:32px}
nav.menu{display:flex; flex-wrap:wrap; gap:10px; align-items:center}
nav.menu a{
  padding:8px 10px;
  border-radius:12px;
  color:rgba(11,16,32,.80);
  border:1px solid transparent;
}
nav.menu a:hover{border-color:rgba(11,16,32,.10); text-decoration:none; background:rgba(255,255,255,.7)}

.hero{
  display:grid; gap:14px; grid-template-columns: 1.3fr .9fr;
  align-items:stretch;
}
@media (max-width:900px){ .hero{grid-template-columns:1fr} }
.heroimg{
  width:100%; height:100%;
  object-fit:cover;
  border-radius:var(--radius);
  border:1px solid var(--border);
}

.footergrid{
  display:grid; gap:12px;
  grid-template-columns: 2fr 1fr 1fr;
}
@media (max-width:900px){ .footergrid{grid-template-columns:1fr} }

.note{
  border-left:4px solid rgba(0,90,255,.35);
  background: rgba(0,90,255,.06);
  padding:10px 12px;
  border-radius:14px;
}
CSS

echo "==> Layout Base.astro (identidad AR + sitemap footer + disclaimer abajo)"
cat > web/src/layouts/Base.astro <<'ASTRO'
---
import "../styles/global.css";

const {
  title = "Vamos Nene — Colapinto Hub",
  description = "Dashboard en castellano: vivo, calendario, clima y noticias sobre Franco Colapinto en F1.",
  canonical = Astro.url.toString()
} = Astro.props;

const apiBase = import.meta.env.PUBLIC_API_BASE;
---
<!doctype html>
<html lang="es-AR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonical} />

    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />

    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:type" content="website" />
    <meta property="og:locale" content="es_AR" />
    <meta property="og:url" content={canonical} />
    <meta property="og:image" content={`${new URL("/assets/colapinto.jpg", Astro.url).toString()}`} />
    <meta name="twitter:card" content="summary_large_image" />

    <!-- AdSense: pegás acá cuando te aprueben -->
    <!-- <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXX" crossorigin="anonymous"></script> -->
  </head>
  <body>
    <header class="top">
      <div class="wrap" style="display:flex; justify-content:space-between; gap:14px; align-items:center;">
        <a class="brand" href="/" aria-label="Ir al inicio">
          <img src="/favicon.svg" alt="43" />
          <span>Vamos Nene</span>
        </a>

        <nav class="menu" aria-label="Secciones">
          <a href="/vivo">Vivo</a>
          <a href="/calendario/2026">Calendario</a>
          <a href="/noticias">Noticias</a>
          <a href="/suscribirme">Suscribirme</a>
          <a href="/tienda">Tienda</a>
        </nav>
      </div>
    </header>

    <main class="wrap">
      <slot />
    </main>

    <footer class="wrap muted" style="padding-top:6px;">
      <div class="card" style="margin-top:18px;">
        <div class="footergrid">
          <div>
            <div class="kicker">Vamos Nene</div>
            <div style="font-weight:900; font-size:18px; color:rgba(11,16,32,.9); margin:6px 0 8px;">
              Hub no-oficial de Colapinto
            </div>
            <div class="note">
              <strong>Nota:</strong> no somos un sitio oficial ni estamos afiliados a Formula 1. Fuentes acreditadas en cada nota.
            </div>
            <div style="margin-top:10px;">
              <span class="pill">API</span>
              <span class="muted" style="font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;">
                {apiBase}
              </span>
            </div>
          </div>

          <div>
            <div class="kicker">Mapa del sitio</div>
            <div style="display:grid; gap:8px; margin-top:10px;">
              <a href="/">Inicio</a>
              <a href="/vivo">Vivo</a>
              <a href="/calendario/2026">Calendario 2026</a>
              <a href="/noticias">Noticias</a>
              <a href="/tienda">Tienda</a>
              <a href="/suscribirme">Suscribirme</a>
            </div>
          </div>

          <div>
            <div class="kicker">Legales</div>
            <div style="display:grid; gap:8px; margin-top:10px;">
              <a href="/privacy">Privacidad</a>
              <a href="/terms">Términos</a>
              <a href="/about">Sobre</a>
              <a href="/contact">Contacto</a>
            </div>
          </div>
        </div>

        <div class="muted" style="margin-top:14px; font-size:12px;">
          © {new Date().getFullYear()} Vamos Nene.
        </div>
      </div>
    </footer>
  </body>
</html>
ASTRO

echo "==> Robots con sitemap"
cat > web/public/robots.txt <<'TXT'
User-agent: *
Allow: /
Sitemap: /sitemap.xml
TXT

echo "==> Home (contenido real + estado ahora/próximo + CTA)"
cat > web/src/pages/index.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";

const api = import.meta.env.PUBLIC_API_BASE;

const [nowRes, newsRes] = await Promise.all([
  fetch(`${api}/api/now`),
  fetch(`${api}/api/news?q=colapinto&limit=8`)
]);

const now = await nowRes.json();
const news = await newsRes.json();

function fmtDT(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"full", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
function fmtTime(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}

const nowIso = now?.now ? String(now.now) : new Date().toISOString();
const ymd = nowIso.slice(0,10);
const isTestingWeek = (ymd >= "2026-02-11" && ymd <= "2026-02-13") || (ymd >= "2026-02-18" && ymd <= "2026-02-20");
const current = now?.current || null;
const next = now?.next || null;
const statusTitle = current ? "En pista ahora" : "Próxima actividad";
const active = current || next;
---
<Base title="Vamos Nene — Colapinto Hub" description="Identidad ARG + dashboard vivo: qué pasó, qué está pasando y qué viene.">
  <section class="hero">
    <div class="card">
      <div class="kicker">Colapinto Hub · Argentina</div>
      <div class="h1">Todo lo de hoy, en un lugar.</div>
      <p class="muted">
        Calendario + clima + noticias + contexto. Hecho para que entres, entiendas en 10 segundos y te quedes.
      </p>

      <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:12px;">
        <a class="btn alpine" href="/vivo">Ir a Vivo</a>
        <a class="btn primary" href="/calendario/2026">Ver calendario 2026</a>
        <a class="btn" href="/suscribirme">Recibir avisos</a>
      </div>

      <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:14px;">
        <span class="pill">Actualizado</span>
        <span class="muted">{fmtDT(nowIso)}</span>
      </div>
    </div>

    <div class="card">
      <img class="heroimg" src="/assets/colapinto.jpg" alt="Franco Colapinto (foto de referencia)" />
      <div class="muted" style="font-size:12px; margin-top:8px;">
        Imagen: Wikimedia Commons (crédito en la fuente original).
      </div>
    </div>
  </section>

  <section class="grid grid2" style="margin-top:14px;">
    <div class="card">
      <div class="kicker">{statusTitle}</div>
      {active ? (
        <>
          <div class="h2" style="margin-top:6px;">{active.event_name}</div>
          <div class="muted">{active.session_name} · {fmtDT(active.start_time)} → {fmtTime(active.end_time)} (ARG)</div>
          <div style="margin-top:10px; display:flex; gap:10px; flex-wrap:wrap;">
            <a class="btn primary" href="/vivo">Abrir dashboard Vivo</a>
            <a class="btn" href={`/gran-premio/${active.event_slug}`}>Detalle</a>
          </div>
        </>
      ) : (
        <div class="muted" style="margin-top:10px;">Aún no hay eventos cargados.</div>
      )}

      {isTestingWeek ? (
        <div class="note" style="margin-top:12px;">
          <strong>Test Baréin (F1 2026):</strong> hoy y mañana el foco es sumar kilómetros y entender ritmo. En Vivo vas a ver horarios ARG, clima y lo último de Colapinto.
        </div>
      ) : null}
    </div>

    <div class="card">
      <div class="kicker">Últimas noticias (Colapinto)</div>
      <div class="muted" style="margin:8px 0 10px;">
        Fuentes automáticas (RSS). Cada nota linkea a su origen.
      </div>

      {news?.items?.length ? (
        <div style="display:grid; gap:10px;">
          {news.items.slice(0,6).map((n) => (
            <div style="display:grid; gap:4px; padding:10px; border:1px solid rgba(11,16,32,.08); border-radius:14px; background:rgba(255,255,255,.70);">
              <div class="muted" style="font-size:12px;">
                {n.source_name}{n.published_at ? ` · ${fmtDT(n.published_at)}` : ""}
              </div>
              <a href="/noticias">{n.title}</a>
              {n.auto_note ? (
                <div class="note" style="margin-top:6px;">
                  <strong>Notas de la Redacción:</strong> {n.auto_note}
                </div>
              ) : null}
            </div>
          ))}
          <a class="btn" href="/noticias">Ver todas</a>
        </div>
      ) : (
        <div class="muted">Todavía no hay noticias. Corré el sync.</div>
      )}
    </div>
  </section>
</Base>
ASTRO

echo "==> Vivo (dashboard claro + qué vas a ver + embed opcional track map)"
cat > web/src/pages/vivo.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const [nowRes, newsRes, weatherRes] = await Promise.all([
  fetch(`${api}/api/now`),
  fetch(`${api}/api/news?q=colapinto&limit=12`),
  fetch(`${api}/api/weather`)
]);

const now = await nowRes.json();
const news = await newsRes.json();
const w = await weatherRes.json();

function fmtDT(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"full", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
function fmtTime(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}

const nowIso = now?.now ? String(now.now) : new Date().toISOString();
const ymd = nowIso.slice(0,10);
const current = now?.current || null;
const next = now?.next || null;

const isTesting1 = (ymd >= "2026-02-11" && ymd <= "2026-02-13");

function pickForecastDays(payload){
  // OpenWeather 5-day / 3h list
  const list = payload?.list || [];
  const byDay = new Map();
  for (const it of list){
    const dt = it.dt ? new Date(it.dt*1000) : null;
    if(!dt) continue;
    const day = dt.toISOString().slice(0,10);
    if(!byDay.has(day)) byDay.set(day, []);
    byDay.get(day).push(it);
  }
  const days = Array.from(byDay.entries()).slice(0,3).map(([day, items]) => {
    const temps = items.map(x => x.main?.temp).filter(x => typeof x === "number");
    const min = temps.length ? Math.min(...temps) : null;
    const max = temps.length ? Math.max(...temps) : null;
    const icon = items.find(x => x.weather?.[0]?.icon)?.weather?.[0]?.icon || null;
    const desc = items.find(x => x.weather?.[0]?.description)?.weather?.[0]?.description || null;
    return { day, min, max, icon, desc };
  });
  return days;
}

const forecast = w?.weather ? pickForecastDays(w.weather) : [];
---
<Base title="Vivo — Vamos Nene" description="Contexto en vivo: qué pasó, qué está pasando, qué viene. Horarios ARG, clima y noticias de Colapinto.">
  <h1 class="h1" style="margin-top:4px;">Vivo</h1>

  <div class="card">
    <div class="kicker">Qué vas a ver acá</div>
    <ul style="margin:10px 0 0; padding-left:18px;">
      <li><strong>Estado:</strong> lo que está pasando ahora / lo próximo (según calendario).</li>
      <li><strong>Horarios en ARG</strong> + <strong>clima</strong> (cuando aplica) del lugar.</li>
      <li><strong>Noticias de Colapinto</strong> (RSS) + <strong>Notas de la Redacción</strong> (auto).</li>
    </ul>
    <div style="margin-top:10px; display:flex; gap:10px; flex-wrap:wrap;">
      <span class="pill">Última actualización</span>
      <span class="muted">{fmtDT(nowIso)}</span>
    </div>
  </div>

  <section class="grid grid2" style="margin-top:14px;">
    <div class="card">
      <div class="kicker">{current ? "En pista ahora" : "Próximo"}</div>

      {(current || next) ? (
        <>
          <div class="h2" style="margin-top:6px;">{(current || next).event_name}</div>
          <div class="muted">{(current || next).session_name} · {fmtDT((current || next).start_time)} → {fmtTime((current || next).end_time)} (ARG)</div>
          <div style="margin-top:10px; display:flex; gap:10px; flex-wrap:wrap;">
            <a class="btn primary" href={`/gran-premio/${(current || next).event_slug}`}>Detalle del evento</a>
            <a class="btn" href="/calendario/2026">Ver calendario</a>
          </div>

          {isTesting1 ? (
            <div class="note" style="margin-top:12px;">
              <strong>Test Baréin (Semana 1):</strong> ayer hubo incidentes y primeras referencias de ritmo.
              Hoy se espera más kilometraje y tandas largas. (Resumen basado en fuentes linkeadas en Noticias).
            </div>
          ) : null}
        </>
      ) : (
        <div class="muted" style="margin-top:10px;">Aún no hay eventos cargados.</div>
      )}
    </div>

    <div class="card">
      <div class="kicker">Clima (zona del evento)</div>
      {w?.event_slug ? (
        <div class="muted" style="margin:8px 0 10px;">Evento: <strong>{w.event_slug}</strong></div>
      ) : null}

      {forecast.length ? (
        <div style="display:grid; gap:10px;">
          {forecast.map((d) => (
            <div style="display:flex; justify-content:space-between; gap:10px; align-items:center; padding:10px; border:1px solid rgba(11,16,32,.08); border-radius:14px; background:rgba(255,255,255,.70);">
              <div>
                <div style="font-weight:900;">
                  {new Intl.DateTimeFormat("es-AR", { weekday:"long", day:"2-digit", month:"short", timeZone:"UTC" }).format(new Date(d.day+"T00:00:00Z"))}
                </div>
                <div class="muted" style="font-size:12px;">{d.desc || "Pronóstico"}</div>
              </div>
              <div style="text-align:right; font-weight:900;">
                {typeof d.max === "number" ? `${Math.round(d.max)}°` : "--"} / {typeof d.min === "number" ? `${Math.round(d.min)}°` : "--"}
              </div>
            </div>
          ))}
          <div class="muted" style="font-size:12px;">
            Nota: OpenWeather da pronóstico corto (≈5 días).
          </div>
        </div>
      ) : (
        <div class="muted" style="margin-top:10px;">
          Todavía no hay pronóstico cacheado para este evento (o faltan coordenadas / está fuera de ventana de 5 días).
        </div>
      )}
    </div>
  </section>

  <section class="card" style="margin-top:14px;">
    <div class="kicker">Dónde verlo (Argentina)</div>
    <div class="muted" style="margin-top:8px;">
      En general: Fox Sports / Disney+ (según disponibilidad de tu operador). Chequeá tu grilla local (Flow / DirecTV / Telecentro).
    </div>
  </section>

  <section class="card" style="margin-top:14px;">
    <div class="kicker">Noticias (Colapinto)</div>
    <div class="muted" style="margin:8px 0 10px;">
      Fuentes RSS con crédito + link. Se filtra por “colapinto” en título/cuerpo.
    </div>

    {news?.items?.length ? (
      <div style="display:grid; gap:12px;">
        {news.items.slice(0,10).map((n) => (
          <div style="display:grid; gap:6px; padding:12px; border:1px solid rgba(11,16,32,.08); border-radius:16px; background:rgba(255,255,255,.70);">
            <div class="muted" style="font-size:12px;">{n.source_name}{n.published_at ? ` · ${fmtDT(n.published_at)}` : ""}</div>
            <div style="font-weight:900; font-size:18px; line-height:1.2;">
              <a href={n.url} rel="nofollow noopener" target="_blank">{n.title}</a>
            </div>

            {n.snippet ? <div class="muted">{n.snippet}</div> : null}

            {n.auto_note ? (
              <div class="note">
                <strong>Notas de la Redacción:</strong> {n.auto_note}
              </div>
            ) : null}
          </div>
        ))}
        <a class="btn" href="/noticias">Abrir listado completo</a>
      </div>
    ) : (
      <div class="muted">No hay noticias aún. Corré el sync admin.</div>
    )}
  </section>

  <section class="card" style="margin-top:14px;">
    <div class="kicker">Mapa en vivo (opcional)</div>
    <div class="muted" style="margin-top:8px;">
      Para “track map” en tiempo real se suele necesitar feed de datos (no siempre libre). Como solución rápida,
      podés usar un embed de terceros. Si no querés depender de terceros, lo dejamos como “Live Lite”.
    </div>

    <div style="margin-top:12px; border-radius:16px; overflow:hidden; border:1px solid rgba(11,16,32,.08); background:#000;">
      <iframe
        title="Track map (terceros)"
        src="https://f1-dash.com/dashboard/track-map"
        style="width:100%; height:520px; border:0;"
        loading="lazy"
        referrerpolicy="no-referrer"
      ></iframe>
    </div>
    <div class="muted" style="font-size:12px; margin-top:8px;">
      Fuente: f1-dash.com (tercero). Puede cambiar/caerse.
    </div>
  </section>
</Base>
ASTRO

echo "==> Noticias (con intro + “cargar más” simple)"
mkdir -p web/src/pages/noticias
cat > web/src/pages/noticias/index.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const limit = 10;
const res = await fetch(`${api}/api/news?q=colapinto&limit=${limit}&offset=0`);
const data = await res.json();

function fmtDT(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"medium", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Noticias (Colapinto) — Vamos Nene" description="Noticias sobre Colapinto, con fuentes acreditadas y notas editoriales automáticas.">
  <h1 class="h1" style="margin-top:4px;">Noticias (Colapinto)</h1>

  <div class="card">
    <div class="kicker">Qué vas a ver acá</div>
    <div class="muted" style="margin-top:8px;">
      <strong>Fuentes RSS</strong> (crédito + link) filtradas por “colapinto” en título/cuerpo.
      Agregamos <strong>Notas de la Redacción</strong> para contexto rápido sin copiar el artículo.
    </div>
  </div>

  <div id="list" style="display:grid; gap:14px; margin-top:14px;">
    {data?.items?.length ? data.items.map((n) => (
      <article class="card">
        <div class="muted" style="font-size:12px;">
          {n.source_name}{n.published_at ? ` · ${fmtDT(n.published_at)}` : ""}
        </div>

        <h2 class="h2" style="margin-top:8px;">
          <a href={n.url} target="_blank" rel="nofollow noopener">{n.title}</a>
        </h2>

        {n.snippet ? <p class="muted">{n.snippet}</p> : null}

        {n.auto_note ? (
          <div class="note">
            <strong>Notas de la Redacción:</strong> {n.auto_note}
          </div>
        ) : null}

        <div class="muted" style="font-size:12px; margin-top:10px;">
          Fuente: <a href={n.source_url} target="_blank" rel="nofollow noopener">{n.source_name}</a>
        </div>
      </article>
    )) : (
      <div class="card"><div class="muted">No hay noticias aún. Ejecutá /api/admin/sync.</div></div>
    )}
  </div>

  <div style="margin-top:14px; display:flex; gap:10px; align-items:center;">
    <button class="btn primary" id="loadMore" type="button">Cargar más</button>
    <span class="muted" id="loadStatus"></span>
  </div>

  <script is:inline>
    const api = import.meta.env.PUBLIC_API_BASE;
    const limit = 10;
    let offset = limit;

    const btn = document.getElementById("loadMore");
    const status = document.getElementById("loadStatus");
    const list = document.getElementById("list");

    function esc(s){ return String(s ?? ""); }

    btn?.addEventListener("click", async () => {
      btn.disabled = true;
      status.textContent = "Cargando…";

      try{
        const r = await fetch(`${api}/api/news?q=colapinto&limit=${limit}&offset=${offset}`);
        const j = await r.json();
        const items = j?.items || [];

        if(!items.length){
          status.textContent = "No hay más por ahora.";
          return;
        }

        for(const n of items){
          const art = document.createElement("article");
          art.className = "card";
          art.innerHTML = `
            <div class="muted" style="font-size:12px;">${esc(n.source_name)}${n.published_at ? " · " + esc(n.published_at) : ""}</div>
            <h2 class="h2" style="margin-top:8px;">
              <a href="${esc(n.url)}" target="_blank" rel="nofollow noopener">${esc(n.title)}</a>
            </h2>
            ${n.snippet ? `<p class="muted">${esc(n.snippet)}</p>` : ""}
            ${n.auto_note ? `<div class="note"><strong>Notas de la Redacción:</strong> ${esc(n.auto_note)}</div>` : ""}
            <div class="muted" style="font-size:12px; margin-top:10px;">Fuente: <a href="${esc(n.source_url)}" target="_blank" rel="nofollow noopener">${esc(n.source_name)}</a></div>
          `;
          list.appendChild(art);
        }

        offset += items.length;
        status.textContent = "";
      }catch(e){
        status.textContent = "Error cargando más.";
      }finally{
        btn.disabled = false;
      }
    });
  </script>
</Base>
ASTRO

echo "==> Calendario 2026 (simple + claro)"
mkdir -p web/src/pages/calendario
cat > web/src/pages/calendario/2026.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const [nowRes, evRes] = await Promise.all([
  fetch(`${api}/api/now`),
  fetch(`${api}/api/events`)
]);

const now = await nowRes.json();
const data = await evRes.json();

function fmtDT(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"medium", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
const current = now?.current?.event_slug;
const next = now?.next?.event_slug;
---
<Base title="Calendario 2026 — Vamos Nene" description="Calendario de eventos y sesiones en horario Argentina, con acceso a detalle y clima.">
  <h1 class="h1" style="margin-top:4px;">Calendario 2026</h1>

  <div class="card">
    <div class="kicker">Cómo usar este calendario</div>
    <div class="muted" style="margin-top:8px;">
      Entrás, ves qué viene, tocás el evento y tenés horarios ARG + clima (si aplica) + links.
    </div>
  </div>

  <div class="grid" style="margin-top:14px;">
    {data?.events?.length ? data.events.map((e) => (
      <div class="card">
        <div style="display:flex; gap:10px; flex-wrap:wrap; align-items:center;">
          {e.event_slug === current ? <span class="pill" style="border-color:rgba(255,79,216,.25)">HOY</span> : null}
          {e.event_slug === next ? <span class="pill" style="border-color:rgba(0,90,255,.25)">PRÓXIMO</span> : null}
          <div class="kicker">{e.session_type}</div>
        </div>
        <div class="h2" style="margin-top:8px;">{e.event_name}</div>
        <div class="muted">{e.session_name} · {fmtDT(e.start_time)} → {fmtDT(e.end_time)}</div>
        <div style="margin-top:10px;">
          <a class="btn primary" href={`/gran-premio/${e.event_slug}`}>Detalle</a>
        </div>
      </div>
    )) : (
      <div class="card"><div class="muted">No hay eventos aún.</div></div>
    )}
  </div>
</Base>
ASTRO

echo "==> Tienda (3 productos sin precios inventados)"
cat > web/src/pages/tienda.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
---
<Base title="Tienda — Vamos Nene" description="Merch celeste y blanco: Remera, Buzo y Gorra (43 + Vamos Nene).">
  <h1 class="h1" style="margin-top:4px;">Tienda</h1>

  <div class="card">
    <div class="kicker">Qué vas a ver acá</div>
    <div class="muted" style="margin-top:8px;">
      Merch inspirado en Argentina (celeste/blanco) + 43 + “Vamos Nene”. Próximo paso: enlazar a proveedor / afiliados (sin stock propio).
    </div>
  </div>

  <div class="grid grid3" style="margin-top:14px;">
    <div class="card">
      <div class="h2">Remera</div>
      <div class="muted">Celeste/Blanca · 43 · “Vamos Nene”</div>
      <ul style="margin:10px 0 0; padding-left:18px;">
        <li>Talles: S–XXL</li>
        <li>Colores: celeste, blanco</li>
        <li>Estampa: frente 43 / espalda “Vamos Nene”</li>
      </ul>
      <div style="margin-top:12px;">
        <a class="btn primary" href="/contact">Quiero comprar / avisarme</a>
      </div>
    </div>

    <div class="card">
      <div class="h2">Buzo</div>
      <div class="muted">Celeste/Blanco · 43 · “Vamos Nene”</div>
      <ul style="margin:10px 0 0; padding-left:18px;">
        <li>Talles: S–XXL</li>
        <li>Con o sin capucha</li>
        <li>Detalles: toque Alpine (azul/rosa)</li>
      </ul>
      <div style="margin-top:12px;">
        <a class="btn primary" href="/contact">Quiero comprar / avisarme</a>
      </div>
    </div>

    <div class="card">
      <div class="h2">Gorra</div>
      <div class="muted">Blanca/celeste · 43 bordado</div>
      <ul style="margin:10px 0 0; padding-left:18px;">
        <li>Ajustable</li>
        <li>Opciones: 43 / “Vamos Nene”</li>
        <li>Color: celeste y blanco</li>
      </ul>
      <div style="margin-top:12px;">
        <a class="btn primary" href="/contact">Quiero comprar / avisarme</a>
      </div>
    </div>
  </div>
</Base>
ASTRO

echo "==> Suscribirme (unifica avisos)"
cat > web/src/pages/suscribirme.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;
---
<Base title="Suscribirme — Vamos Nene" description="Recibí avisos del calendario: 72hs antes + cronograma + clima + dónde verlo.">
  <h1 class="h1" style="margin-top:4px;">Suscribirme</h1>

  <div class="card">
    <div class="kicker">Por qué sirve</div>
    <div class="muted" style="margin-top:8px;">
      Te avisamos <strong>72hs antes</strong> con: cronograma (ARG), dónde verlo y pronóstico corto si está disponible.
    </div>

    <ul style="margin:10px 0 0; padding-left:18px;">
      <li>Alertas por GP (previo + día de actividad)</li>
      <li>Recordatorio de sesión (cuando aplica)</li>
      <li>Resumen “qué mirar” (automático)</li>
    </ul>
  </div>

  <div class="card" style="margin-top:14px;">
    <div class="kicker">Email</div>
    <form id="f" style="display:flex; gap:10px; flex-wrap:wrap; margin-top:10px;">
      <input id="email" type="email" required placeholder="tu@email.com" style="padding:10px 12px; border-radius:14px; border:1px solid rgba(11,16,32,.15); min-width:260px;" />
      <button class="btn alpine" type="submit">Suscribirme</button>
      <span class="muted" id="msg"></span>
    </form>

    <div class="muted" style="font-size:12px; margin-top:10px;">
      Sin spam. Te podés dar de baja cuando quieras.
    </div>
  </div>

  <script is:inline>
    const api = import.meta.env.PUBLIC_API_BASE;
    const f = document.getElementById("f");
    const email = document.getElementById("email");
    const msg = document.getElementById("msg");

    f.addEventListener("submit", async (e) => {
      e.preventDefault();
      msg.textContent = "Enviando…";
      try{
        const r = await fetch(`${api}/api/subscribe`, {
          method:"POST",
          headers:{ "content-type":"application/json" },
          body: JSON.stringify({ email: email.value })
        });
        const j = await r.json();
        if(j.ok){
          msg.textContent = "Listo. Te vamos a avisar.";
          email.value = "";
        }else{
          msg.textContent = j.error || "Error.";
        }
      }catch(err){
        msg.textContent = "Error.";
      }
    });
  </script>
</Base>
ASTRO

# Redirección simple /avisos -> /suscribirme
cat > web/src/pages/avisos.astro <<'ASTRO'
---
return Astro.redirect('/suscribirme', 301);
---
ASTRO

echo "==> Ruta española /gran-premio/[slug] (reuse API /api/event)"
mkdir -p web/src/pages/gran-premio
cat > web/src/pages/gran-premio/[slug].astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE;

const { slug } = Astro.params;
const res = await fetch(`${api}/api/event?slug=${encodeURIComponent(slug)}`);
const ev = await res.json();

function fmtDT(iso){
  if(!iso) return "";
  const d = new Date(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle:"full", timeStyle:"short", timeZone:"America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title={`${ev?.event_name || "Gran Premio"} — Vamos Nene`} description="Detalle del evento: horarios ARG + clima si aplica.">
  <h1 class="h1" style="margin-top:4px;">{ev?.event_name || "Gran Premio"}</h1>

  <div class="card">
    <div class="kicker">Sesión</div>
    <div class="h2" style="margin-top:6px;">{ev?.session_name || "-"}</div>
    <div class="muted">{fmtDT(ev?.start_time)} → {fmtDT(ev?.end_time)}</div>
  </div>

  <div class="grid grid2" style="margin-top:14px;">
    <div class="card">
      <div class="kicker">Circuito / Lugar</div>
      <div class="muted" style="margin-top:8px;">
        {ev?.circuit_name || "—"} · {ev?.locality || ""} {ev?.country ? `(${ev.country})` : ""}
      </div>
      <div style="margin-top:10px;">
        <a class="btn primary" href="/vivo">Ver en Vivo</a>
        <a class="btn" href="/noticias">Noticias</a>
      </div>
    </div>

    <div class="card">
      <div class="kicker">Clima</div>
      {ev?.weather?.payload ? (
        <div class="muted" style="margin-top:10px;">Pronóstico disponible (ventana corta, ~5 días).</div>
      ) : (
        <div class="muted" style="margin-top:10px;">
          Pronóstico todavía no disponible (o fuera de ventana). Se actualizará cuando se acerque la fecha.
        </div>
      )}
    </div>
  </div>
</Base>
ASTRO

echo "==> sitemap.xml (ruta dinámica)"
cat > web/src/pages/sitemap.xml.ts <<'TS'
export async function GET({ request }: { request: Request }) {
  const origin = new URL(request.url).origin;
  const api = import.meta.env.PUBLIC_API_BASE;

  const staticPaths = [
    "/",
    "/vivo",
    "/calendario/2026",
    "/noticias",
    "/suscribirme",
    "/tienda",
    "/privacy",
    "/terms",
    "/about",
    "/contact"
  ];

  let eventSlugs: string[] = [];
  try {
    const r = await fetch(`${api}/api/events`);
    const j = await r.json() as any;
    eventSlugs = (j?.events || []).map((e: any) => e.event_slug).filter(Boolean);
  } catch {}

  const urls = [
    ...staticPaths.map(p => `${origin}${p}`),
    ...eventSlugs.map(s => `${origin}/gran-premio/${encodeURIComponent(s)}`)
  ];

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
    urls.map(u => `  <url><loc>${u}</loc></url>`).join("\n") +
    `\n</urlset>\n`;

  return new Response(xml, { headers: { "content-type": "application/xml; charset=utf-8" } });
}
TS

echo "==> API (mejoras mínimas: filtro colapinto en cuerpo + paginación + encoding)"
# Migración 0002: image_url + meta
cat > api/migrations/0002_news_images_meta.sql <<'SQL'
ALTER TABLE articles ADD COLUMN image_url TEXT;
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
SQL

# Reemplazo del Worker index.ts (basado en tu estructura existente)
cat > api/src/index.ts <<'TS'
import { XMLParser } from "fast-xml-parser";

export interface Env {
  DB: D1Database;
  // Secrets / vars
  ADMIN_KEY?: string;
  BREVO_API_KEY?: string;
  SENDER_EMAIL?: string;
  SITE_ORIGIN?: string;

  OPENWEATHER_API_KEY?: string;
  OPENWEATHER_BASE?: string;
}

// ---------- util ----------
function ok(body: string, init?: ResponseInit) {
  const headers = new Headers(init?.headers);
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  headers.set("Access-Control-Allow-Headers", "content-type");
  return new Response(body, { ...init, headers });
}
function json(data: any, init?: ResponseInit) {
  return ok(JSON.stringify(data), {
    ...init,
    headers: { ...(init?.headers || {}), "content-type": "application/json; charset=utf-8" }
  });
}

function clampInt(v: any, def: number, min: number, max: number) {
  const n = Number(v);
  if (!Number.isFinite(n)) return def;
  return Math.max(min, Math.min(max, Math.trunc(n)));
}

async function setMeta(env: Env, key: string, value: string) {
  await env.DB.prepare("INSERT INTO meta(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=?2").bind(key, value).run();
}
async function getMeta(env: Env, key: string) {
  const row = await env.DB.prepare("SELECT value FROM meta WHERE key=?1").bind(key).first<any>();
  return row?.value || null;
}

// Decode RSS robusto (evita “present�”)
async function fetchTextSmart(url: string): Promise<string> {
  const res = await fetch(url, { headers: { "user-agent": "vamosnene-bot/1.0" } });
  const buf = await res.arrayBuffer();
  const bytes = new Uint8Array(buf);

  const ct = res.headers.get("content-type") || "";
  const m = ct.match(/charset=([^;]+)/i);
  const charset = (m?.[1] || "utf-8").trim().toLowerCase();

  // Intento 1: charset declarado
  try {
    const td = new TextDecoder(charset as any, { fatal: false });
    const s = td.decode(bytes);
    // Heurística: si tiene muchos �, reintentar latin1
    const bad = (s.match(/\uFFFD/g) || []).length;
    if (bad >= 3 && charset !== "iso-8859-1") {
      const td2 = new TextDecoder("iso-8859-1", { fatal: false });
      return td2.decode(bytes);
    }
    return s;
  } catch {
    const td = new TextDecoder("utf-8", { fatal: false });
    return td.decode(bytes);
  }
}

// ---------- schedule ----------
async function syncSchedule(env: Env) {
  // seed mínimo: 2026 testing weeks en Bahrain
  // Horarios reales del test suelen ser 07:00–16:00 UTC (bloque diario)
  const testing1 = ["2026-02-11", "2026-02-12", "2026-02-13"];
  const testing2 = ["2026-02-18", "2026-02-19", "2026-02-20"];

  const base = {
    circuit_name: "Bahrain International Circuit",
    circuit_lat: 26.0325,
    circuit_lon: 50.5106,
    country: "Bahrain",
    locality: "Sakhir"
  };

  const entries: any[] = [];
  for (let i = 0; i < testing1.length; i++) {
    const d = testing1[i];
    entries.push({
      uid: `2026-test1-day${i + 1}`,
      season: 2026,
      round: null,
      event_slug: "bahrain-testing-1",
      event_name: "Test de pretemporada — Baréin (Semana 1)",
      session_name: `Día ${i + 1}`,
      session_type: "TEST",
      start_time: `${d}T07:00:00Z`,
      end_time: `${d}T16:00:00Z`,
      ...base
    });
  }
  for (let i = 0; i < testing2.length; i++) {
    const d = testing2[i];
    entries.push({
      uid: `2026-test2-day${i + 1}`,
      season: 2026,
      round: null,
      event_slug: "bahrain-testing-2",
      event_name: "Test de pretemporada — Baréin (Semana 2)",
      session_name: `Día ${i + 1}`,
      session_type: "TEST",
      start_time: `${d}T07:00:00Z`,
      end_time: `${d}T16:00:00Z`,
      ...base
    });
  }

  const stmt = env.DB.prepare(`
    INSERT INTO sessions(uid, season, round, event_slug, event_name, session_name, session_type, start_time, end_time,
      circuit_name, circuit_lat, circuit_lon, country, locality, updated_at)
    VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14, datetime('now'))
    ON CONFLICT(uid) DO UPDATE SET
      event_slug=excluded.event_slug,
      event_name=excluded.event_name,
      session_name=excluded.session_name,
      session_type=excluded.session_type,
      start_time=excluded.start_time,
      end_time=excluded.end_time,
      circuit_name=excluded.circuit_name,
      circuit_lat=excluded.circuit_lat,
      circuit_lon=excluded.circuit_lon,
      country=excluded.country,
      locality=excluded.locality,
      updated_at=datetime('now')
  `);

  for (const e of entries) {
    await stmt.bind(
      e.uid, e.season, e.round, e.event_slug, e.event_name, e.session_name, e.session_type,
      e.start_time, e.end_time, e.circuit_name, e.circuit_lat, e.circuit_lon, e.country, e.locality
    ).run();
  }
  await setMeta(env, "schedule_last_sync", new Date().toISOString());
}

// ---------- now/events ----------
async function getNow(env: Env) {
  const now = new Date().toISOString();

  const current = await env.DB.prepare(`
    SELECT event_slug, event_name, session_name, session_type, start_time, end_time
    FROM sessions
    WHERE start_time <= ?1 AND end_time >= ?1
    ORDER BY start_time ASC
    LIMIT 1
  `).bind(now).first<any>();

  const next = await env.DB.prepare(`
    SELECT event_slug, event_name, session_name, session_type, start_time, end_time
    FROM sessions
    WHERE start_time > ?1
    ORDER BY start_time ASC
    LIMIT 1
  `).bind(now).first<any>();

  return { now, current: current || null, next: next || null };
}

async function listEvents(env: Env) {
  const rows = await env.DB.prepare(`
    SELECT event_slug, event_name, session_name, session_type, start_time, end_time
    FROM sessions
    ORDER BY start_time ASC
  `).all<any>();
  return rows?.results || [];
}

async function getEvent(env: Env, slug: string) {
  const row = await env.DB.prepare(`
    SELECT event_slug, event_name, session_name, session_type, start_time, end_time, circuit_name, circuit_lat, circuit_lon, country, locality
    FROM sessions
    WHERE event_slug = ?1
    ORDER BY start_time ASC
    LIMIT 1
  `).bind(slug).first<any>();

  if (!row) return { error: "not_found" };

  // weather cache
  let w = await env.DB.prepare("SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1").bind(slug).first<any>();

  // fetch on-demand si no existe y hay key y coords
  if (!w?.payload && env.OPENWEATHER_API_KEY && row.circuit_lat && row.circuit_lon) {
    await syncWeatherForEvent(env, slug, row.circuit_lat, row.circuit_lon);
    w = await env.DB.prepare("SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1").bind(slug).first<any>();
  }

  return {
    ...row,
    weather: w?.payload ? { fetched_at: w.fetched_at, payload: JSON.parse(w.payload) } : null
  };
}

// ---------- news ----------
type NewsSource = { code: string; name: string; site_url: string; rss_url: string };

const seedSources: NewsSource[] = [
  // EN/ES + Google News RSS para “Colapinto” (AR)
  { code: "motorsport_lat", name: "Motorsport (LatAm)", site_url: "https://lat.motorsport.com/f1/", rss_url: "https://lat.motorsport.com/rss/f1/news/" },
  { code: "motorsport_es", name: "Motorsport (ES)", site_url: "https://es.motorsport.com/f1/", rss_url: "https://es.motorsport.com/rss/f1/news/" },
  { code: "autosport_f1", name: "Autosport", site_url: "https://www.autosport.com/f1/news/", rss_url: "https://www.autosport.com/rss/f1/news/" },
  { code: "google_colapinto", name: "Google News (AR)", site_url: "https://news.google.com/", rss_url: "https://news.google.com/rss/search?q=%22Franco%20Colapinto%22%20OR%20Colapinto%20F1%20OR%20Colapinto%20Alpine&hl=es-419&gl=AR&ceid=AR:es-419" }
];

async function ensureSources(env: Env) {
  const stmt = env.DB.prepare(`
    INSERT INTO news_sources(code, name, site_url, rss_url)
    VALUES(?1,?2,?3,?4)
    ON CONFLICT(code) DO UPDATE SET
      name=excluded.name,
      site_url=excluded.site_url,
      rss_url=excluded.rss_url
  `);
  for (const s of seedSources) {
    await stmt.bind(s.code, s.name, s.site_url, s.rss_url).run();
  }
}

function toArray<T>(v: any): T[] {
  if (!v) return [];
  return Array.isArray(v) ? v : [v];
}

function pickImage(item: any): string | null {
  const enc = item?.enclosure;
  if (enc?.url) return String(enc.url);

  const mt = item?.["media:thumbnail"];
  if (mt?.url) return String(mt.url);

  const mc = item?.["media:content"];
  if (Array.isArray(mc)) {
    for (const m of mc) if (m?.url) return String(m.url);
  } else if (mc?.url) {
    return String(mc.url);
  }
  return null;
}

function buildAutoNote(title: string, snippet: string) {
  // “Notas de la Redacción” rule-based, no LLM (100% free)
  const t = `${title} ${snippet}`.toLowerCase();

  const isCol = t.includes("colapinto");
  const isAlpine = t.includes("alpine");
  const isTest = t.includes("test") || t.includes("pretemporada") || t.includes("bahr");
  const isQualy = t.includes("qual") || t.includes("clasif");
  const isRace = t.includes("carrera") || t.includes("grand prix") || t.includes("gran premio");

  if (isCol && isTest) return "Clave del día: foco en kilometraje y consistencia. Si hay pocas vueltas, suele ser por puesta a punto o detalles del auto nuevo.";
  if (isCol && isAlpine) return "Lo importante: cómo se adapta al auto y qué comentarios da el equipo. Mirá señales de ritmo en tandas largas.";
  if (isCol && isQualy) return "Atención a: ritmo a una vuelta vs. estabilidad. Un buen ‘sector’ puede anticipar salto de rendimiento.";
  if (isCol && isRace) return "Qué mirar: estrategia, degradación y ritmo en tráfico. La lectura real aparece en stints largos.";
  if (isCol) return "Contexto rápido: si el titular menciona a Colapinto, buscá si habla de ritmo, fiabilidad o plan de trabajo.";

  return "Contexto rápido: titular relevante de F1. Abrí la fuente para el detalle completo.";
}

async function syncNews(env: Env) {
  await ensureSources(env);

  const sources = await env.DB.prepare("SELECT code, name, site_url, rss_url FROM news_sources").all<any>();
  const rows: NewsSource[] = sources.results || [];

  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "",
    trimValues: true
  });

  const insert = env.DB.prepare(`
    INSERT INTO articles(guid, source_code, title, url, published_at, snippet, auto_note, tags, image_url)
    VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9)
    ON CONFLICT(guid) DO NOTHING
  `);

  for (const s of rows) {
    let xml = "";
    try {
      xml = await fetchTextSmart(s.rss_url);
    } catch {
      continue;
    }

    let feed: any = null;
    try { feed = parser.parse(xml); } catch { continue; }

    // RSS: feed.rss.channel.item ; Atom: feed.feed.entry
    const channel = feed?.rss?.channel;
    const rssItems = toArray<any>(channel?.item);

    const atomItems = toArray<any>(feed?.feed?.entry);

    const items = rssItems.length ? rssItems : atomItems;

    for (const it of items) {
      const title = String(it?.title?.["#text"] ?? it?.title ?? "").trim();
      if (!title) continue;

      // RSS link puede ser string; Atom link puede ser array con href
      let url = "";
      if (typeof it?.link === "string") url = it.link;
      else if (it?.link?.href) url = it.link.href;
      else if (Array.isArray(it?.link)) {
        const alt = it.link.find((x: any) => x?.rel === "alternate") || it.link[0];
        url = alt?.href || "";
      }
      url = String(url || "").trim();
      if (!url) continue;

      const guid = String(it?.guid?.["#text"] ?? it?.guid ?? url).trim();

      const snippet = String(it?.description?.["#text"] ?? it?.description ?? it?.summary?.["#text"] ?? it?.summary ?? "").replace(/\s+/g, " ").trim();

      const published_at =
        String(it?.pubDate ?? it?.published ?? it?.updated ?? "").trim() || null;

      const lower = `${title} ${snippet}`.toLowerCase();
      const tags = [
        lower.includes("colapinto") ? "colapinto" : null,
        lower.includes("alpine") ? "alpine" : null,
        lower.includes("bahr") || lower.includes("bahrein") ? "bahrain" : null,
        lower.includes("test") || lower.includes("pretemporada") ? "test" : null
      ].filter(Boolean).join(",");

      // filtro “colapinto” en cuerpo/título: SOLO guardamos si pasa (reduce ruido)
      if (!lower.includes("colapinto")) continue;

      const auto_note = buildAutoNote(title, snippet);
      const image_url = pickImage(it);

      await insert.bind(
        guid, s.code, title, url, published_at, snippet, auto_note, tags || null, image_url || null
      ).run();
    }
  }

  await setMeta(env, "news_last_sync", new Date().toISOString());
}

async function listNews(env: Env, q: string, limit: number, offset: number) {
  const qq = (q || "").trim().toLowerCase();

  let where = "1=1";
  let binds: any[] = [];

  if (qq) {
    where = "(lower(title || ' ' || ifnull(snippet,'') || ' ' || ifnull(tags,'')) LIKE ?1)";
    binds.push(`%${qq}%`);
  }

  const stmt = env.DB.prepare(`
    SELECT a.title, a.url, a.published_at, a.snippet, a.auto_note, a.tags, a.image_url,
           s.name as source_name, s.site_url as source_url
    FROM articles a
    JOIN news_sources s ON s.code = a.source_code
    WHERE ${where}
    ORDER BY a.published_at DESC, a.id DESC
    LIMIT ?2 OFFSET ?3
  `);

  const res = await stmt.bind(binds[0] || null, limit, offset).all<any>();
  return res.results || [];
}

// ---------- weather ----------
async function syncWeatherForEvent(env: Env, event_slug: string, lat: number, lon: number) {
  if (!env.OPENWEATHER_API_KEY) return;
  const base = env.OPENWEATHER_BASE || "https://api.openweathermap.org/data/2.5";
  const url = `${base}/forecast?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&appid=${encodeURIComponent(env.OPENWEATHER_API_KEY)}&units=metric&lang=es`;
  const res = await fetch(url);
  if (!res.ok) return;

  const payload = await res.text();
  await env.DB.prepare(`
    INSERT INTO weather_cache(event_slug, fetched_at, payload)
    VALUES(?1, datetime('now'), ?2)
    ON CONFLICT(event_slug) DO UPDATE SET fetched_at=datetime('now'), payload=?2
  `).bind(event_slug, payload).run();

  await setMeta(env, "weather_last_sync", new Date().toISOString());
}

async function syncWeather(env: Env) {
  // Cache only current/next event
  const { current, next } = await getNow(env);
  const slug = (current?.event_slug || next?.event_slug);
  if (!slug) return;

  const row = await env.DB.prepare("SELECT circuit_lat, circuit_lon FROM sessions WHERE event_slug=?1 LIMIT 1").bind(slug).first<any>();
  if (!row?.circuit_lat || !row?.circuit_lon) return;

  await syncWeatherForEvent(env, slug, row.circuit_lat, row.circuit_lon);
}

// ---------- subscribe + alerts (mantenido mínimo) ----------
async function subscribe(env: Env, email: string) {
  email = (email || "").trim().toLowerCase();
  if (!email || !email.includes("@")) return { ok: false, error: "email_invalido" };

  try {
    await env.DB.prepare("INSERT INTO subscribers(email) VALUES(?1)").bind(email).run();
  } catch {
    // already
  }
  return { ok: true };
}

async function sendAlerts(env: Env) {
  // MVP: no enviar aún (evita spam). Queda listo para siguiente paso.
  return;
}

async function handleAdminSync(req: Request, env: Env) {
  const url = new URL(req.url);
  const key = url.searchParams.get("key") || "";
  if (!env.ADMIN_KEY || key !== env.ADMIN_KEY) {
    return json({ ok: false, error: "unauthorized" }, { status: 401 });
  }
  await syncSchedule(env);
  await syncNews(env);
  await syncWeather(env);
  return json({ ok: true });
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext) {
    const url = new URL(req.url);

    if (req.method === "OPTIONS") return ok("", { status: 204 });

    if (url.pathname === "/api/health") return json({ ok: true });

    if (url.pathname === "/api/now") return json(await getNow(env));

    if (url.pathname === "/api/events") {
      const events = await listEvents(env);
      return json({ events });
    }

    if (url.pathname === "/api/event") {
      const slug = url.searchParams.get("slug") || "";
      if (!slug) return json({ error: "missing_slug" }, { status: 400 });
      return json(await getEvent(env, slug));
    }

    if (url.pathname === "/api/weather") {
      const { current, next } = await getNow(env);
      const slug = (current?.event_slug || next?.event_slug);
      if (!slug) return json({ event_slug: null, weather: null });
      const row = await env.DB.prepare("SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1").bind(slug).first<any>();
      return json({ event_slug: slug, fetched_at: row?.fetched_at || null, weather: row?.payload ? JSON.parse(row.payload) : null });
    }

    if (url.pathname === "/api/news") {
      const q = url.searchParams.get("q") || "";
      const limit = clampInt(url.searchParams.get("limit"), 20, 1, 50);
      const offset = clampInt(url.searchParams.get("offset"), 0, 0, 5000);
      const items = await listNews(env, q, limit, offset);
      return json({ items, meta: { news_last_sync: await getMeta(env, "news_last_sync") } });
    }

    if (url.pathname === "/api/subscribe" && req.method === "POST") {
      const body = await req.json<any>().catch(() => ({}));
      const email = String(body.email || "");
      const r = await subscribe(env, email);
      return json(r, { status: r.ok ? 200 : 400 });
    }

    if (url.pathname === "/api/admin/sync") return handleAdminSync(req, env);

    if (url.pathname === "/api/status") {
      return json({
        news_last_sync: await getMeta(env, "news_last_sync"),
        schedule_last_sync: await getMeta(env, "schedule_last_sync"),
        weather_last_sync: await getMeta(env, "weather_last_sync")
      });
    }

    return json({ error: "not_found" }, { status: 404 });
  },

  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    const cron = controller.cron;
    ctx.waitUntil((async () => {
      try {
        if (cron === "*/15 * * * *") {
          await syncNews(env);
          await syncWeather(env);
        } else if (cron === "10 3 * * *") {
          await syncSchedule(env);
        } else if (cron === "20 12 * * *") {
          await sendAlerts(env);
        } else {
          await syncWeather(env);
        }
      } catch (e) {
        console.log("cron error", cron, String(e));
      }
    })());
  }
};
TS

echo "==> Listo. Próximos pasos:"
echo "1) Aplicar migraciones D1 (remote)"
echo "   cd api && npx wrangler d1 migrations apply vamosnene_hub --remote"
echo "2) Deploy Worker"
echo "   npx wrangler deploy"
echo "3) Commit + push para Pages"
echo "   cd .. && git add -A && git commit -m 'reboot: identidad AR + dashboard vivo' && git push"
