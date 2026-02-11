#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [[ ! -d "api" || ! -d "web" ]]; then
  echo "ERROR: ejecutá esto desde la raiz del repo (donde existen ./api y ./web)"
  exit 1
fi

echo "==> 0) Git hygiene"
# ignorar .DS_Store
if ! grep -qE '^\*\.DS_Store$' .gitignore 2>/dev/null; then
  echo '*.DS_Store' >> .gitignore
fi

# remover .DS_Store si quedaron trackeados
find . -name ".DS_Store" -print0 | xargs -0 git rm -f --ignore-unmatch >/dev/null 2>&1 || true

echo "==> 1) API: migracion para image_url"
mkdir -p api/migrations
cat > api/migrations/0002_articles_image.sql <<'SQL'
-- Adds image_url to articles for richer news cards
ALTER TABLE articles ADD COLUMN image_url TEXT;
SQL

echo "==> 2) API: reemplazo api/src/index.ts (news: filtro+imagenes+paginado, weather on-demand, copy Vamos Nene)"
cat > api/src/index.ts <<'TS'
import { XMLParser } from "fast-xml-parser";

export interface Env {
  DB: D1Database;
  SITE_ORIGIN: string;
  OPENWEATHER_BASE: string;
  OPENWEATHER_API_KEY?: string; // secret
  BREVO_API_KEY?: string;       // secret
  ADMIN_KEY?: string;           // secret
  SENDER_EMAIL?: string;
}

type SessionRow = {
  uid: string;
  season: number;
  round: number | null;
  event_slug: string;
  event_name: string;
  session_name: string;
  session_type: string;
  start_time: string;
  end_time: string;
  circuit_name: string | null;
  circuit_lat: number | null;
  circuit_lon: number | null;
  country: string | null;
  locality: string | null;
};

function json(data: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(data), {
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...corsHeaders(init?.headers),
    },
    ...init,
  });
}

function corsHeaders(extra?: HeadersInit) {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    ...(extra || {}),
  };
}

function ok(text: string, init?: ResponseInit) {
  return new Response(text, { ...init, headers: { ...corsHeaders(init?.headers) } });
}

function isoNow() {
  return new Date().toISOString();
}

function slugify(s: string) {
  return s
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function parseErgastTime(date: string, time?: string) {
  const t = (time || "00:00:00Z").replace("Z", "Z");
  return new Date(`${date}T${t}`).toISOString();
}

function addHours(iso: string, hours: number) {
  return new Date(new Date(iso).getTime() + hours * 3600_000).toISOString();
}

function addDays(dateYYYYMMDD: string, add: number) {
  const d = new Date(`${dateYYYYMMDD}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + add);
  return d.toISOString().slice(0, 10);
}

async function seedSources(env: Env) {
  // Fuente RSS en español confirmada
  // https://www.f1latam.com/rss/rss.php
  const sources = [
    {
      code: "f1latam",
      name: "F1Latam",
      site_url: "https://www.f1latam.com/",
      rss_url: "https://www.f1latam.com/rss/rss.php"
    },
    {
      code: "f1",
      name: "Formula1.com",
      site_url: "https://www.formula1.com/",
      rss_url: "https://www.formula1.com/en/latest/all.xml"
    },
    {
      code: "autosport",
      name: "Autosport",
      site_url: "https://www.autosport.com/f1/",
      rss_url: "https://www.autosport.com/rss/f1/news/"
    },
    {
      code: "motorsport",
      name: "Motorsport.com",
      site_url: "https://www.motorsport.com/f1/",
      rss_url: "https://www.motorsport.com/rss/f1/news/"
    }
  ];

  const stmt = env.DB.prepare(
    "INSERT OR REPLACE INTO news_sources (code, name, site_url, rss_url) VALUES (?1, ?2, ?3, ?4)"
  );
  const batch = sources.map(s => stmt.bind(s.code, s.name, s.site_url, s.rss_url));
  await env.DB.batch(batch);
}

function autoNote(title: string, sourceName: string) {
  const t = title.toLowerCase();
  const tags: string[] = [];
  const add = (tag: string) => { if (!tags.includes(tag)) tags.push(tag); };

  if (t.includes("colapinto")) add("colapinto");
  if (t.includes("alpine")) add("alpine");
  if (t.includes("williams")) add("williams");
  if (t.includes("verstappen")) add("verstappen");
  if (t.includes("hamilton")) add("hamilton");
  if (t.includes("leclerc")) add("leclerc");
  if (t.includes("norris")) add("norris");

  if (/(wins|victory|gan(a|ó)|triunf)/.test(t)) add("resultado");
  if (/(qualifying|pole|clasific)/.test(t)) add("qualy");
  if (/(practice|fp1|fp2|fp3|práctic)/.test(t)) add("practica");
  if (/(penalty|sancion|grid drop)/.test(t)) add("sancion");
  if (/(crash|accident|choque)/.test(t)) add("incidente");
  if (/(test|testing|pre-season|pretemporada)/.test(t)) add("testing");

  const angle =
    tags.includes("sancion") ? "posibles cambios en la grilla" :
    tags.includes("incidente") ? "estado del auto y consecuencias deportivas" :
    tags.includes("resultado") ? "tendencias de ritmo y estrategia" :
    "qué significa para el fin de semana";

  const note =
`Según ${sourceName}, la noticia gira en torno a ${angle}. ` +
`En clave argentina, la lectura útil es separar "ruido" (titulares) de señales: ` +
`ritmo relativo, confiabilidad y decisiones del equipo. ` +
`Si Colapinto aparece en el foco, mirá también el contexto (compuesto, carga, tráfico) antes de sacar conclusiones.`;

  return { note, tags: tags.join(",") };
}

async function fetchText(url: string, init?: RequestInit) {
  const res = await fetch(url, init);
  if (!res.ok) throw new Error(`fetch failed ${res.status} ${url}`);
  return await res.text();
}

function textish(v: any): string {
  if (!v) return "";
  if (typeof v === "string") return v;
  if (typeof v === "object" && "#text" in v) return String(v["#text"] || "");
  return String(v);
}

function stripHtml(s: string) {
  return (s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

function extractImageUrl(it: any): string | null {
  // RSS enclosure
  const enc = it.enclosure;
  if (enc) {
    if (typeof enc === "object" && enc.url) return String(enc.url);
    if (typeof enc === "object" && enc["@_url"]) return String(enc["@_url"]);
    if (typeof enc === "string") return enc;
  }

  // Media RSS
  const mediaContent = it["media:content"] || it["media:thumbnail"];
  const pick = (x: any) => {
    if (!x) return null;
    if (Array.isArray(x)) return pick(x[0]);
    if (typeof x === "object" && x.url) return String(x.url);
    if (typeof x === "object" && x["@_url"]) return String(x["@_url"]);
    return null;
  };
  const m = pick(mediaContent);
  if (m) return m;

  // Some feeds embed img in description/content
  const desc = stripHtml(textish(it.description || it.summary || it.content || ""));
  const raw = textish(it.description || it.summary || it.content || "");
  const m2 = String(raw).match(/https?:\/\/[^\s"'<>]+?\.(jpg|jpeg|png|webp)/i);
  if (m2?.[0]) return m2[0];

  // Fallback: none
  void desc;
  return null;
}

async function syncNews(env: Env) {
  await seedSources(env);

  const srcRows = await env.DB.prepare("SELECT code, name, rss_url FROM news_sources").all();
  const sources = (srcRows.results || []) as any[];

  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "",
    trimValues: true
  });

  for (const s of sources) {
    try {
      const xml = await fetchText(s.rss_url, { cf: { cacheTtl: 300, cacheEverything: true } as any });
      const data = parser.parse(xml);

      const items = data?.rss?.channel?.item || data?.feed?.entry || [];
      const arr = Array.isArray(items) ? items : [items];

      for (const it of arr.slice(0, 40)) {
        const title = textish(it.title && (it.title["#text"] || it.title)) || textish(it.title);
        const link =
          (typeof it.link === "string" ? it.link :
           it.link?.href || it.link?.["@_href"] || it.link?.["href"] ||
           (Array.isArray(it.link) ? (it.link[0]?.href || it.link[0]) : "")) || "";

        const guid = textish(it.guid && (it.guid["#text"] || it.guid)) || link || `${s.code}:${title}`;
        const pub = it.pubDate || it.published || it.updated || null;

        const rawDesc = it.description || it.summary || it.content || "";
        const desc = stripHtml(typeof rawDesc === "string" ? rawDesc : rawDesc?.["#text"] || "");
        const snippet = desc.slice(0, 180).trim();

        if (!title || !link) continue;

        const { note, tags } = autoNote(title, s.name);
        const imageUrl = extractImageUrl(it);

        await env.DB.prepare(
          "INSERT OR IGNORE INTO articles (guid, source_code, title, url, published_at, snippet, auto_note, tags, image_url) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)"
        ).bind(guid, s.code, title, link, pub, snippet, note, tags, imageUrl).run();
      }
    } catch (e) {
      console.log("RSS failed", s.code, String(e));
    }
  }
}

async function upsertSession(env: Env, row: SessionRow) {
  await env.DB.prepare(
    `INSERT INTO sessions (uid, season, round, event_slug, event_name, session_name, session_type, start_time, end_time, circuit_name, circuit_lat, circuit_lon, country, locality, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)
     ON CONFLICT(uid) DO UPDATE SET
       season=excluded.season,
       round=excluded.round,
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
       updated_at=excluded.updated_at`
  ).bind(
    row.uid,
    row.season,
    row.round,
    row.event_slug,
    row.event_name,
    row.session_name,
    row.session_type,
    row.start_time,
    row.end_time,
    row.circuit_name,
    row.circuit_lat,
    row.circuit_lon,
    row.country,
    row.locality,
    isoNow()
  ).run();
}

async function syncSchedule(env: Env) {
  const url = "https://api.jolpi.ca/ergast/f1/2026.json";
  const res = await fetch(url, { cf: { cacheTtl: 3600, cacheEverything: true } as any });
  if (!res.ok) throw new Error(`schedule fetch failed ${res.status}`);
  const data = await res.json<any>();
  const races = data?.MRData?.RaceTable?.Races || [];

  for (const r of races) {
    const round = Number(r.round);
    const raceName: string = r.raceName;
    const eventName = raceName;
    const eventSlug = slugify(raceName.replace("Grand Prix", "gp"));
    const circuitName = r.Circuit?.circuitName || null;
    const lat = r.Circuit?.Location?.lat ? Number(r.Circuit.Location.lat) : null;
    const lon = r.Circuit?.Location?.long ? Number(r.Circuit.Location.long) : null;
    const country = r.Circuit?.Location?.country || null;
    const locality = r.Circuit?.Location?.locality || null;

    const raceStart = parseErgastTime(r.date, r.time);
    const raceEnd = addHours(raceStart, 2.5);
    await upsertSession(env, {
      uid: `2026:${round}:R`,
      season: 2026,
      round,
      event_slug: eventSlug,
      event_name: eventName,
      session_name: "Carrera",
      session_type: "R",
      start_time: raceStart,
      end_time: raceEnd,
      circuit_name: circuitName,
      circuit_lat: lat,
      circuit_lon: lon,
      country,
      locality
    });

    if (r.Qualifying?.date) {
      const qStart = parseErgastTime(r.Qualifying.date, r.Qualifying.time);
      await upsertSession(env, {
        uid: `2026:${round}:Q`,
        season: 2026,
        round,
        event_slug: eventSlug,
        event_name: eventName,
        session_name: "Clasificación",
        session_type: "Q",
        start_time: qStart,
        end_time: addHours(qStart, 1.5),
        circuit_name: circuitName,
        circuit_lat: lat,
        circuit_lon: lon,
        country,
        locality
      });
    }

    const pmap = [
      ["FirstPractice", "FP1", "Práctica 1"],
      ["SecondPractice", "FP2", "Práctica 2"],
      ["ThirdPractice", "FP3", "Práctica 3"]
    ] as const;

    for (const [key, st, name] of pmap) {
      const v = (r as any)[key];
      if (!v?.date) continue;
      const start = parseErgastTime(v.date, v.time);
      await upsertSession(env, {
        uid: `2026:${round}:${st}`,
        season: 2026,
        round,
        event_slug: eventSlug,
        event_name: eventName,
        session_name: name,
        session_type: st,
        start_time: start,
        end_time: addHours(start, 1.25),
        circuit_name: circuitName,
        circuit_lat: lat,
        circuit_lon: lon,
        country,
        locality
      });
    }

    if (r.Sprint?.date) {
      const sStart = parseErgastTime(r.Sprint.date, r.Sprint.time);
      await upsertSession(env, {
        uid: `2026:${round}:S`,
        season: 2026,
        round,
        event_slug: eventSlug,
        event_name: eventName,
        session_name: "Sprint",
        session_type: "S",
        start_time: sStart,
        end_time: addHours(sStart, 1.0),
        circuit_name: circuitName,
        circuit_lat: lat,
        circuit_lon: lon,
        country,
        locality
      });
    }
  }

  // Testing Bahrain (bloques día)
  const testing = [
    { slug: "bahrain-testing-1", name: "Pre-Season Testing 1 (Baréin)", start: "2026-02-11" },
    { slug: "bahrain-testing-2", name: "Pre-Season Testing 2 (Baréin)", start: "2026-02-18" }
  ];

  for (const t of testing) {
    const days = [t.start, addDays(t.start, 1), addDays(t.start, 2)];
    let i = 1;
    for (const d of days) {
      const start = new Date(`${d}T00:00:00Z`).toISOString();
      const end = new Date(`${d}T23:59:59Z`).toISOString();
      await upsertSession(env, {
        uid: `2026:TEST:${t.slug}:D${i}`,
        season: 2026,
        round: null,
        event_slug: t.slug,
        event_name: t.name,
        session_name: `Día ${i}`,
        session_type: "TEST",
        start_time: start,
        end_time: end,
        circuit_name: "Bahrain International Circuit",
        circuit_lat: 26.0325,
        circuit_lon: 50.5106,
        country: "Bahrain",
        locality: "Sakhir"
      });
      i += 1;
    }
  }
}

async function getNow(env: Env) {
  const nowIso = isoNow();
  const last = await env.DB.prepare(
    "SELECT * FROM sessions WHERE end_time < ?1 ORDER BY end_time DESC LIMIT 1"
  ).bind(nowIso).first<SessionRow>();

  const current = await env.DB.prepare(
    "SELECT * FROM sessions WHERE start_time <= ?1 AND end_time >= ?1 ORDER BY start_time ASC LIMIT 1"
  ).bind(nowIso).first<SessionRow>();

  const next = await env.DB.prepare(
    "SELECT * FROM sessions WHERE start_time > ?1 ORDER BY start_time ASC LIMIT 1"
  ).bind(nowIso).first<SessionRow>();

  const today = await env.DB.prepare(
    "SELECT * FROM sessions WHERE date(start_time) = date(?1) ORDER BY start_time ASC"
  ).bind(nowIso).all<SessionRow>();

  return { now: nowIso, last, current, next, today: today.results || [] };
}

async function syncWeatherForEvent(env: Env, eventSlug: string) {
  if (!env.OPENWEATHER_API_KEY) return;

  const row = await env.DB.prepare(
    "SELECT circuit_lat, circuit_lon FROM sessions WHERE event_slug = ?1 AND circuit_lat IS NOT NULL AND circuit_lon IS NOT NULL LIMIT 1"
  ).bind(eventSlug).first<any>();

  if (!row?.circuit_lat || !row?.circuit_lon) return;

  const url = `${env.OPENWEATHER_BASE}/forecast?lat=${row.circuit_lat}&lon=${row.circuit_lon}&appid=${env.OPENWEATHER_API_KEY}&units=metric&lang=es`;
  const res = await fetch(url, { cf: { cacheTtl: 600, cacheEverything: true } as any });
  if (!res.ok) throw new Error(`weather fetch failed ${res.status}`);
  const payload = await res.json<any>();

  await env.DB.prepare(
    "INSERT OR REPLACE INTO weather_cache (event_slug, fetched_at, payload) VALUES (?1, ?2, ?3)"
  ).bind(eventSlug, isoNow(), JSON.stringify(payload)).run();
}

async function syncWeather(env: Env) {
  const { current, next } = await getNow(env);
  const slug = (current?.event_slug || next?.event_slug);
  if (!slug) return;
  await syncWeatherForEvent(env, slug);
}

async function listEvents(env: Env) {
  const rows = await env.DB.prepare(
    `SELECT event_slug, event_name,
            MIN(start_time) AS start_time,
            MAX(end_time)   AS end_time,
            MAX(round)      AS round,
            MAX(country)    AS country,
            MAX(locality)   AS locality,
            MAX(circuit_name) AS circuit_name
     FROM sessions
     WHERE season = 2026
     GROUP BY event_slug, event_name
     ORDER BY MIN(start_time) ASC`
  ).all<any>();
  return rows.results || [];
}

function hoursBetween(aIso: string, bIso: string) {
  const a = new Date(aIso).getTime();
  const b = new Date(bIso).getTime();
  if (!isFinite(a) || !isFinite(b)) return 1e9;
  return Math.abs(a - b) / 3600_000;
}

async function getEvent(env: Env, slug: string) {
  const sessions = await env.DB.prepare(
    `SELECT * FROM sessions
     WHERE event_slug = ?1
     ORDER BY start_time ASC`
  ).bind(slug).all<any>();

  let weatherRow = await env.DB.prepare(
    "SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1"
  ).bind(slug).first<any>();

  // Weather on-demand: si no hay cache o está viejo, intenta refrescar.
  if (env.OPENWEATHER_API_KEY) {
    const stale = !weatherRow?.fetched_at || hoursBetween(weatherRow.fetched_at, isoNow()) > 2;
    if (stale) {
      try {
        await syncWeatherForEvent(env, slug);
        weatherRow = await env.DB.prepare(
          "SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1"
        ).bind(slug).first<any>();
      } catch (e) {
        console.log("weather on-demand failed", slug, String(e));
      }
    }
  }

  return {
    slug,
    sessions: sessions.results || [],
    weather: weatherRow?.payload ? JSON.parse(weatherRow.payload) : null,
    weather_fetched_at: weatherRow?.fetched_at || null
  };
}

async function listNews(env: Env, opts: { q: string; limit: number; offset: number }) {
  const q = (opts.q || "").trim().toLowerCase();
  const like = `%${q}%`;

  const rows = await env.DB.prepare(
    `SELECT a.title, a.url, a.published_at, a.snippet, a.auto_note, a.tags, a.image_url,
            s.name as source_name, s.site_url as source_url
     FROM articles a
     JOIN news_sources s ON s.code = a.source_code
     WHERE (?1 = '' OR lower(a.title) LIKE ?2 OR lower(a.snippet) LIKE ?2 OR lower(a.tags) LIKE ?2)
     ORDER BY a.published_at DESC, a.id DESC
     LIMIT ?3 OFFSET ?4`
  ).bind(q, like, opts.limit, opts.offset).all<any>();

  return rows.results || [];
}

async function subscribe(env: Env, email: string) {
  email = email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, error: "Email inválido" };
  }
  await env.DB.prepare("INSERT OR IGNORE INTO subscribers (email, locale) VALUES (?1, 'es-AR')").bind(email).run();
  return { ok: true };
}

async function sendAlerts(env: Env) {
  if (!env.BREVO_API_KEY || !env.SENDER_EMAIL) return;

  const now = new Date();
  const from = new Date(now.getTime() + 72 * 3600_000).toISOString();
  const to = new Date(now.getTime() + 96 * 3600_000).toISOString();

  const sessions = await env.DB.prepare(
    `SELECT * FROM sessions
     WHERE start_time >= ?1 AND start_time < ?2
     ORDER BY start_time ASC`
  ).bind(from, to).all<SessionRow>();

  if (!sessions.results?.length) return;

  const subs = await env.DB.prepare("SELECT email FROM subscribers").all<any>();
  if (!subs.results?.length) return;

  const lines = sessions.results.map(s => `• ${s.event_name} — ${s.session_name} (${s.start_time})`).join("\n");
  const subject = "F1 (72h): cronograma + clima + dónde verlo";
  const text =
`Hola!\n
En ~72 horas tenés esto:\n\n${lines}\n\n` +
`Detalle (horarios ARG + clima + links): ${env.SITE_ORIGIN}/vivo\n\n` +
`— Vamos Nene...!!!`;

  for (const u of subs.results) {
    await brevoSend(env, u.email, subject, text);
  }
}

async function brevoSend(env: Env, to: string, subject: string, text: string) {
  const payload = {
    sender: { name: "Vamos Nene...!!!", email: env.SENDER_EMAIL! },
    to: [{ email: to }],
    subject,
    textContent: text
  };

  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "accept": "application/json",
      "content-type": "application/json",
      "api-key": env.BREVO_API_KEY!
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    console.log("brevo send failed", res.status, await res.text());
  }
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

    if (url.pathname === "/api/now") {
      const data = await getNow(env);
      return json(data);
    }

    if (url.pathname === "/api/news") {
      const qRaw = (url.searchParams.get("q") ?? "colapinto").trim();
      const q = qRaw.toLowerCase() === "all" ? "" : qRaw;
      const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") || "20", 10), 1), 50);
      const offset = Math.max(parseInt(url.searchParams.get("offset") || "0", 10), 0);

      const items = await listNews(env, { q, limit, offset });
      return json({ items, q, limit, offset });
    }

    if (url.pathname === "/api/events") {
      const events = await listEvents(env);
      return json({ events });
    }

    if (url.pathname === "/api/event") {
      const slug = url.searchParams.get("slug") || "";
      if (!slug) return json({ error: "missing_slug" }, { status: 400 });
      const ev = await getEvent(env, slug);
      return json(ev);
    }

    if (url.pathname === "/api/weather") {
      const { current, next } = await getNow(env);
      const slug = (current?.event_slug || next?.event_slug);
      if (!slug) return json({ event_slug: null, weather: null });

      const row = await env.DB.prepare("SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1")
        .bind(slug).first<any>();

      return json({
        event_slug: slug,
        fetched_at: row?.fetched_at || null,
        weather: row?.payload ? JSON.parse(row.payload) : null
      });
    }

    if (url.pathname === "/api/subscribe" && req.method === "POST") {
      const body = await req.json<any>().catch(() => ({}));
      const email = String(body.email || "");
      const r = await subscribe(env, email);
      return json(r, { status: r.ok ? 200 : 400 });
    }

    if (url.pathname === "/api/admin/sync") {
      return handleAdminSync(req, env);
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

echo "==> 3) WEB: Base.astro (SEO+UI)"
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
const siteName = "Vamos Nene...!!!";
---
<!doctype html>
<html lang="es-AR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonical} />

    <!-- OpenGraph / Twitter -->
    <meta property="og:locale" content="es_AR" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content={siteName} />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:url" content={canonical} />
    <meta property="og:image" content={ogImage} />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={title} />
    <meta name="twitter:description" content={description} />

    <meta name="theme-color" content="#76c7ff" />

    <script type="application/ld+json">
      {JSON.stringify({
        "@context": "https://schema.org",
        "@type": "WebSite",
        name: siteName,
        url: origin,
        inLanguage: "es-AR",
        description,
      })}
    </script>

    <style>
      :root{
        --bg: #0b1020;
        --card: rgba(255,255,255,.06);
        --border: rgba(255,255,255,.14);
        --text: rgba(255,255,255,.92);
        --muted: rgba(255,255,255,.72);
        --brand: #76c7ff;
        --brand2:#ffffff;
        --cta:#22c55e;
        color-scheme: dark;
      }
      *{ box-sizing:border-box; }
      body{
        margin:0;
        font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Noto Sans", sans-serif;
        line-height:1.5;
        background:
          radial-gradient(1200px 600px at 10% 0%, rgba(118,199,255,.18), transparent 60%),
          radial-gradient(1000px 600px at 90% 10%, rgba(255,255,255,.10), transparent 55%),
          var(--bg);
        color: var(--text);
      }
      a{ color: inherit; }
      .wrap{ max-width: 1040px; margin: 0 auto; padding: 18px; }
      header{
        position: sticky; top:0;
        backdrop-filter: blur(10px);
        background: rgba(11,16,32,.72);
        border-bottom: 1px solid var(--border);
        z-index: 10;
      }
      .topbar{
        display:flex; align-items:center; justify-content:space-between; gap: 12px;
      }
      .brand{
        display:flex; flex-direction:column; gap:2px;
      }
      .brand strong{
        letter-spacing:.2px;
      }
      .brand small{
        color: var(--muted);
        font-size:12px;
      }
      nav a{
        text-decoration:none;
        opacity:.9;
        margin-right: 12px;
        font-weight: 600;
      }
      nav a:hover{ opacity:1; text-decoration: underline; text-underline-offset: 4px; }
      .btn{
        display:inline-flex; align-items:center; justify-content:center;
        padding:10px 12px; border-radius: 12px;
        border: 1px solid var(--border);
        background: rgba(255,255,255,.04);
        text-decoration:none;
        font-weight: 700;
      }
      .btn.primary{
        background: var(--cta);
        border-color: rgba(0,0,0,.2);
        color:#07130a;
      }
      .hero{
        padding: 14px 0 0;
      }
      .hero .card{
        border-radius: 18px;
        background: linear-gradient(90deg, rgba(118,199,255,.12), rgba(255,255,255,.06));
        border: 1px solid var(--border);
        padding: 14px;
      }
      .hero h1{
        margin: 0 0 6px;
        font-size: 26px;
        letter-spacing:.2px;
      }
      .muted{ color: var(--muted); }
      main{ padding: 14px 0 24px; }
      .card{
        border: 1px solid var(--border);
        border-radius: 16px;
        padding: 14px;
        background: var(--card);
        margin: 14px 0;
      }
      .grid{
        display:grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 14px;
      }
      .pill{
        display:inline-block;
        padding: 4px 10px;
        border-radius: 999px;
        border:1px solid var(--border);
        color: var(--muted);
        font-size: 12px;
      }
      footer{
        border-top: 1px solid var(--border);
        padding: 18px 0 26px;
        color: var(--muted);
      }
      img{ max-width:100%; height:auto; }
      input,button{ font:inherit; }
      .row{ display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
      .spacer{ flex:1; }
      code{ color: rgba(118,199,255,.95); }
    </style>

    <!-- AdSense: pegá acá el script cuando te aprueben -->
    <!-- <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXX" crossorigin="anonymous"></script> -->
  </head>

  <body>
    <header>
      <div class="wrap topbar">
        <div class="brand">
          <strong>Vamos Nene...!!!</strong>
          <small>F1 en castellano · foco Colapinto · calendario · clima</small>
        </div>

        <nav class="row">
          <a href="/vivo">Vivo</a>
          <a href="/calendario/2026">Calendario</a>
          <a href="/noticias">Noticias</a>
          <a href="/tienda">Tienda</a>
          <a href="/avisos">Avisos</a>
          <span class="spacer"></span>
          <a class="btn primary" href="/avisos">Suscribirme</a>
        </nav>
      </div>
    </header>

    <div class="wrap hero">
      <div class="card">
        <h1>Todo lo importante de F1, en clave argentina.</h1>
        <div class="row">
          <span class="pill">Colapinto</span>
          <span class="pill">Horarios ARG</span>
          <span class="pill">Clima del circuito</span>
          <span class="pill">Noticias con contexto</span>
        </div>
        <p class="muted" style="margin:10px 0 0">
          Nota: no somos un sitio oficial ni afiliado a Formula 1. Fuentes acreditadas en cada nota.
        </p>
      </div>
    </div>

    <main class="wrap">
      <slot />
    </main>

    <footer>
      <div class="wrap">
        <div>© {new Date().getFullYear()} Vamos Nene...!!!</div>
        <div class="muted" style="margin-top:6px">
          <a href="/privacy">Privacidad</a> · <a href="/terms">Términos</a> · <a href="/about">Sobre</a> · <a href="/contact">Contacto</a>
        </div>
        <div class="muted" style="margin-top:6px">
          API: <code>{apiBase || "(no configurada)"}</code>
        </div>
      </div>
    </footer>
  </body>
</html>
ASTRO

echo "==> 4) WEB: assets (OG image) + robots con sitemap"
mkdir -p web/public
cat > web/public/og.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#76c7ff" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0.15"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="#0b1020"/>
  <rect x="60" y="70" width="1080" height="490" rx="36" fill="url(#g)" stroke="rgba(255,255,255,0.16)" />
  <text x="120" y="230" fill="rgba(255,255,255,0.92)" font-family="system-ui, -apple-system, Segoe UI, Roboto" font-size="72" font-weight="800">Vamos Nene...!!!</text>
  <text x="120" y="315" fill="rgba(255,255,255,0.78)" font-family="system-ui, -apple-system, Segoe UI, Roboto" font-size="34" font-weight="600">F1 en castellano · foco Colapinto · calendario · clima</text>
  <text x="120" y="395" fill="rgba(255,255,255,0.70)" font-family="system-ui, -apple-system, Segoe UI, Roboto" font-size="26">Noticias con contexto (fuente + link) · Horarios ARG · Alertas 72h</text>
</svg>
SVG

cat > web/public/robots.txt <<'TXT'
User-agent: *
Allow: /

Sitemap: https://vamosnene.pages.dev/sitemap.xml
TXT

echo "==> 5) WEB: rutas en castellano + redirects 301 (SSR safe)"
mkdir -p web/src/pages/noticias web/src/pages/calendario web/src/pages/guias web/src/pages/gran-premio

# /vivo (nuevo)
cat > web/src/pages/vivo.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";

async function safeJson(url) {
  try {
    const r = await fetch(url);
    return await r.json();
  } catch {
    return null;
  }
}

const now = api ? await safeJson(`${api}/api/now`) : null;
const weather = api ? await safeJson(`${api}/api/weather`) : null;
const news = api ? await safeJson(`${api}/api/news?q=colapinto&limit=8&offset=0`) : null;

function fmt(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "full", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Vivo — Vamos Nene...!!!" description="Contexto en vivo: qué pasó, qué está ocurriendo, qué viene. Horarios ARG + clima + noticias de Colapinto.">
  <h2>Contexto en vivo</h2>

  {!api ? (
    <div class="card">
      <div class="muted">Falta configurar <code>PUBLIC_API_BASE</code> en Cloudflare Pages.</div>
    </div>
  ) : null}

  <div class="grid">
    <div class="card">
      <h3>Ahora</h3>
      {now?.current ? (
        <div>
          <div><strong>{now.current.event_name}</strong></div>
          <div class="muted">{now.current.session_name} · {fmt(now.current.start_time)} → {fmt(now.current.end_time)}</div>
        </div>
      ) : (
        <div class="muted">No hay sesión en vivo ahora.</div>
      )}
      <div style="margin-top:10px">
        {now?.next ? (
          <div>
            <div class="muted">Próximo:</div>
            <div><strong>{now.next.event_name}</strong></div>
            <div class="muted">{now.next.session_name} · {fmt(now.next.start_time)}</div>
            <a class="btn" href={`/gran-premio/${now.next.event_slug}`} style="margin-top:10px">Ver detalle</a>
          </div>
        ) : null}
      </div>
    </div>

    <div class="card">
      <h3>Clima del circuito</h3>
      {weather?.weather?.city?.name ? (
        <div>
          <div><strong>{weather.weather.city.name}</strong></div>
          <div class="muted">Actualizado: {weather.fetched_at ? fmt(weather.fetched_at) : "—"}</div>
          <div class="muted" style="margin-top:10px">Tip: el pronóstico cambia mucho; tomalo como tendencia.</div>
        </div>
      ) : (
        <div class="muted">Todavía no hay pronóstico cacheado para el evento actual/próximo.</div>
      )}
    </div>

    <div class="card">
      <h3>Colapinto (últimas)</h3>
      {news?.items?.length ? (
        <ul>
          {news.items.map((n) => (
            <li style="margin:10px 0">
              <a href={n.url} rel="nofollow noopener noreferrer" target="_blank">{n.title}</a>
              <div class="muted" style="font-size:12px">{n.source_name}</div>
            </li>
          ))}
        </ul>
      ) : (
        <div class="muted">Sin noticias aún (o el sync no corrió).</div>
      )}
      <a class="btn" href="/noticias">Ver todas</a>
    </div>
  </div>
</Base>
ASTRO

# redirect /live -> /vivo
cat > web/src/pages/live.astro <<'ASTRO'
---
return Astro.redirect("/vivo", 301);
---
ASTRO

# /calendario/2026 (nuevo)
cat > web/src/pages/calendario/2026.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
const res = api ? await fetch(`${api}/api/events`) : null;
const data = res ? await res.json() : { events: [] };

function fmt(iso) {
  if (!iso) return "-";
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(new Date(iso));
}
---
<Base title="Calendario 2026 — Vamos Nene...!!!" description="Calendario F1 2026: prácticas, clasificación, sprint y carrera con horarios en Argentina.">
  <h2>Calendario 2026</h2>
  <p class="muted">Cada evento tiene su página con sesiones + clima (si hay datos) + links.</p>

  <div class="card">
    {!api ? (
      <div class="muted">Falta configurar <code>PUBLIC_API_BASE</code> en Cloudflare Pages.</div>
    ) : null}

    {data.events?.length ? (
      <ul>
        {data.events.map((e) => (
          <li style="margin:10px 0">
            <a href={`/gran-premio/${e.event_slug}`}><strong>{e.event_name}</strong></a>
            <div class="muted">{fmt(e.start_time)} → {fmt(e.end_time)} · {e.locality || ""} {e.country ? `(${e.country})` : ""}</div>
          </li>
        ))}
      </ul>
    ) : (
      <div class="muted">Todavía no hay eventos (corré el sync admin o esperá al cron).</div>
    )}
  </div>
</Base>
ASTRO

# redirect /calendar/2026 -> /calendario/2026
cat > web/src/pages/calendar/2026.astro <<'ASTRO'
---
return Astro.redirect("/calendario/2026", 301);
---
ASTRO

# /noticias (nuevo) + load more + imagen + "Notas de la Redacción"
cat > web/src/pages/noticias/index.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";

const q = "colapinto";
const limit = 15;
const offset = 0;

const res = api ? await fetch(`${api}/api/news?q=${encodeURIComponent(q)}&limit=${limit}&offset=${offset}`) : null;
const data = res ? await res.json() : { items: [], q, limit, offset };

function fmt(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Noticias — Vamos Nene...!!!" description="Noticias de Colapinto con fuente y link, más notas editoriales automáticas en castellano.">
  <h2>Noticias (Colapinto)</h2>
  <p class="muted">Mostramos fuente + link y sumamos contexto breve en castellano. Evitamos copiar artículos completos.</p>

  {!api ? (
    <div class="card">
      <div class="muted">Falta configurar <code>PUBLIC_API_BASE</code> en Cloudflare Pages.</div>
    </div>
  ) : null}

  <div id="news-list">
    {data.items?.length ? (
      data.items.map((n) => (
        <article class="card">
          <div class="muted" style="font-size:12px">
            <a href={n.source_url} rel="nofollow noopener noreferrer" target="_blank">{n.source_name}</a>
            {n.published_at ? ` · ${fmt(n.published_at)}` : ""}
          </div>

          {n.image_url ? (
            <img src={n.image_url} loading="lazy" decoding="async" style="margin:10px 0;border-radius:14px;border:1px solid rgba(255,255,255,.10)" />
          ) : null}

          <h3 style="margin:8px 0 6px">
            <a href={n.url} rel="nofollow noopener noreferrer" target="_blank">{n.title}</a>
          </h3>

          {n.snippet ? <p class="muted" style="margin:0 0 10px">{n.snippet}</p> : null}

          <p style="margin:0"><strong>Notas de la Redacción:</strong> {n.auto_note}</p>

          {n.tags ? <div class="muted" style="font-size:12px;margin-top:10px">Tags: {n.tags}</div> : null}
        </article>
      ))
    ) : (
      <div class="card">
        <div class="muted">No hay noticias aún. Corré el sync admin o esperá al cron.</div>
      </div>
    )}
  </div>

  <div class="card">
    <button class="btn" id="load-more" type="button">Cargar más</button>
    <span class="muted" id="load-state" style="margin-left:10px"></span>
  </div>

  <script is:inline>
    const api = "{api}";
    const q = "{q}";
    let limit = {limit};
    let offset = {limit}; // ya mostramos 0..limit-1

    const list = document.getElementById("news-list");
    const btn = document.getElementById("load-more");
    const state = document.getElementById("load-state");

    function esc(s){ return String(s||""); }

    function card(n){
      const wrap = document.createElement("article");
      wrap.className = "card";

      const meta = document.createElement("div");
      meta.className = "muted";
      meta.style.fontSize = "12px";
      meta.innerHTML = `<a href="${esc(n.source_url)}" rel="nofollow noopener noreferrer" target="_blank">${esc(n.source_name)}</a>` + (n.published_at ? ` · ${esc(n.published_at)}` : "");
      wrap.appendChild(meta);

      if (n.image_url){
        const img = document.createElement("img");
        img.src = n.image_url;
        img.loading = "lazy";
        img.decoding = "async";
        img.style.margin = "10px 0";
        img.style.borderRadius = "14px";
        img.style.border = "1px solid rgba(255,255,255,.10)";
        wrap.appendChild(img);
      }

      const h = document.createElement("h3");
      h.style.margin = "8px 0 6px";
      h.innerHTML = `<a href="${esc(n.url)}" rel="nofollow noopener noreferrer" target="_blank">${esc(n.title)}</a>`;
      wrap.appendChild(h);

      if (n.snippet){
        const p = document.createElement("p");
        p.className = "muted";
        p.style.margin = "0 0 10px";
        p.textContent = n.snippet;
        wrap.appendChild(p);
      }

      const note = document.createElement("p");
      note.style.margin = "0";
      note.innerHTML = `<strong>Notas de la Redacción:</strong> ${esc(n.auto_note)}`;
      wrap.appendChild(note);

      if (n.tags){
        const t = document.createElement("div");
        t.className = "muted";
        t.style.fontSize = "12px";
        t.style.marginTop = "10px";
        t.textContent = "Tags: " + n.tags;
        wrap.appendChild(t);
      }

      return wrap;
    }

    async function loadMore(){
      if (!api) return;
      btn.disabled = true;
      state.textContent = "Cargando…";
      try{
        const url = `${api}/api/news?q=${encodeURIComponent(q)}&limit=${limit}&offset=${offset}`;
        const r = await fetch(url);
        const data = await r.json();
        const items = data.items || [];
        if (!items.length){
          state.textContent = "No hay más.";
          btn.style.display = "none";
          return;
        }
        for (const n of items){
          list.appendChild(card(n));
        }
        offset += items.length;
        state.textContent = "";
      }catch(e){
        state.textContent = "Error cargando más.";
      }finally{
        btn.disabled = false;
      }
    }

    btn?.addEventListener("click", loadMore);
  </script>
</Base>
ASTRO

# redirect /news -> /noticias
cat > web/src/pages/news/index.astro <<'ASTRO'
---
return Astro.redirect("/noticias", 301);
---
ASTRO

# detalle de GP en español: /gran-premio/[slug]
cat > web/src/pages/gran-premio/[slug].astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
const { slug } = Astro.params;

const res = api ? await fetch(`${api}/api/event?slug=${encodeURIComponent(slug)}`) : null;
const ev = res ? await res.json() : { sessions: [], weather: null };

function fmt(iso) {
  if (!iso) return "-";
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "full", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(new Date(iso));
}
---
<Base title={`${slug} — Vamos Nene...!!!`} description="Detalle del evento: sesiones oficiales + horarios Argentina + clima del circuito (si disponible).">
  <h2>{ev.sessions?.[0]?.event_name || slug}</h2>
  <p class="muted">{ev.sessions?.[0]?.circuit_name || ""} · {ev.sessions?.[0]?.locality || ""} · {ev.sessions?.[0]?.country || ""}</p>

  <div class="grid">
    <div class="card">
      <h3>Sesiones</h3>
      {ev.sessions?.length ? (
        <ul>
          {ev.sessions.map((s) => (
            <li style="margin:8px 0">
              <strong>{s.session_name}</strong>
              <div class="muted" style="font-size:12px">{fmt(s.start_time)} → {fmt(s.end_time)}</div>
            </li>
          ))}
        </ul>
      ) : <div class="muted">Sin sesiones.</div>}
    </div>

    <div class="card">
      <h3>Clima</h3>
      {ev.weather?.city?.name ? (
        <div>
          <div><strong>{ev.weather.city.name}</strong></div>
          <div class="muted" style="font-size:12px">Actualizado: {ev.weather_fetched_at ? fmt(ev.weather_fetched_at) : "-"}</div>
          <div class="muted" style="margin-top:10px">Forecast (cada 3h, 5 días). Tomalo como tendencia.</div>
        </div>
      ) : (
        <div class="muted">
          Todavía no hay pronóstico cacheado para este evento. Si ya configuraste OpenWeather, corré el sync admin o recargá (el API intenta cachear on-demand).
        </div>
      )}
    </div>
  </div>

  <div class="card">
    <h3>Turismo (próximo)</h3>
    <p class="muted">Acá vamos a sumar paquetes / hoteles cerca del circuito con referidos (cuando tengamos los links aprobados).</p>
  </div>
</Base>
ASTRO

# redirect /gp/[slug] -> /gran-premio/[slug]
cat > web/src/pages/gp/[slug].astro <<'ASTRO'
---
const { slug } = Astro.params;
return Astro.redirect(`/gran-premio/${slug}`, 301);
---
ASTRO

# /tienda y redirect /merch
cat > web/src/pages/tienda.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
---
<Base title="Tienda — Vamos Nene...!!!" description="Merch celeste y blanco: 43 + Vamos Nene. Remeras, buzos, gorritas (próximamente).">
  <h2>Tienda (Merch)</h2>
  <div class="card">
    <p class="muted">Diseños sugeridos: celeste y blanco, número <strong>43</strong>, leyenda <strong>“Vamos Nene..!”</strong>.</p>
    <p class="muted">Para monetización sin stock, lo ideal es print-on-demand + link externo. Lo conectamos cuando elijas plataforma.</p>
  </div>
</Base>
ASTRO

cat > web/src/pages/merch.astro <<'ASTRO'
---
return Astro.redirect("/tienda", 301);
---
ASTRO

# /avisos y redirect /alerts
cat > web/src/pages/avisos.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
---
<Base title="Avisos — Vamos Nene...!!!" description="Suscribite para recibir avisos 72h antes: cronograma, dónde verlo y pronóstico.">
  <h2>Avisos (72h antes)</h2>
  <p class="muted">Te mandamos el cronograma, dónde verlo y clima estimado. (El envío requiere configurar Brevo; la suscripción se guarda igual).</p>

  <div class="card">
    <form method="post" id="subForm">
      <label class="muted" for="email">Email</label><br/>
      <input id="email" name="email" type="email" required placeholder="tu@email.com"
        style="padding:10px 12px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92);min-width:280px" />
      <button class="btn primary" type="submit" style="margin-left:8px">Suscribirme</button>
      <div class="muted" id="subMsg" style="margin-top:10px"></div>
    </form>
  </div>

  <script is:inline>
    const api = "{api}";
    const form = document.getElementById("subForm");
    const msg = document.getElementById("subMsg");
    form?.addEventListener("submit", async (e) => {
      e.preventDefault();
      if (!api) { msg.textContent = "Falta configurar PUBLIC_API_BASE."; return; }
      const email = document.getElementById("email").value;
      msg.textContent = "Enviando…";
      try{
        const r = await fetch(`${api}/api/subscribe`, { method:"POST", headers:{ "content-type":"application/json" }, body: JSON.stringify({ email }) });
        const data = await r.json();
        msg.textContent = data.ok ? "Listo. Te avisamos antes de la próxima actividad." : (data.error || "Error");
      }catch{
        msg.textContent = "Error de red.";
      }
    });
  </script>
</Base>
ASTRO

cat > web/src/pages/alerts.astro <<'ASTRO'
---
return Astro.redirect("/avisos", 301);
---
ASTRO

echo "==> 6) WEB: sitemap dinamico (SSR)"
cat > web/src/pages/sitemap.xml.ts <<'TS'
export async function GET({ request }: { request: Request }) {
  const origin = new URL(request.url).origin;
  const api = (import.meta as any).env?.PUBLIC_API_BASE || "";

  const staticPaths = [
    "/", "/vivo", "/calendario/2026", "/noticias", "/tienda", "/avisos",
    "/privacy", "/terms", "/about", "/contact",
    "/guias/como-ver-f1-en-argentina",
    "/guias/colapinto-biografia",
    "/guias/glosario-f1",
    "/guias/horarios-argentina",
    "/guias/testing-bahrain"
  ];

  let eventPaths: string[] = [];
  if (api) {
    try {
      const r = await fetch(`${api}/api/events`);
      const data = await r.json();
      eventPaths = (data.events || []).map((e: any) => `/gran-premio/${e.event_slug}`);
    } catch {}
  }

  const urls = [...staticPaths, ...eventPaths]
    .map((p) => `<url><loc>${origin}${p}</loc></url>`)
    .join("");

  const xml =
`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>`;

  return new Response(xml, {
    headers: {
      "content-type": "application/xml; charset=utf-8",
      "cache-control": "public, max-age=900"
    }
  });
}
TS

echo "==> 7) WEB: guias (contenido original en español)"
cat > web/src/pages/guias/como-ver-f1-en-argentina.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Cómo ver la F1 en Argentina — Vamos Nene...!!!" description="Guía práctica: opciones para ver F1 desde Argentina, tips de horario, y qué mirar para entender una carrera.">
  <h2>Cómo ver la F1 en Argentina</h2>
  <div class="card">
    <p>Esta guía es práctica: la idea es que no te pierdas el <strong>horario en Argentina</strong>, tengas un checklist para el fin de semana y sepas qué mirar más allá del resultado.</p>
    <ul>
      <li><strong>Horario:</strong> chequeá siempre el cronograma en <a href="/calendario/2026">Calendario 2026</a>.</li>
      <li><strong>Antes de la carrera:</strong> mirá prácticas largas (ritmo) y clasificación (posición de salida).</li>
      <li><strong>Durante:</strong> prestá atención a paradas, neumáticos y tráfico (explican cambios “raros” de ritmo).</li>
    </ul>
    <p class="muted">Tip: usá <a href="/vivo">Vivo</a> para ver qué está pasando ahora y qué viene después.</p>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/colapinto-biografia.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Colapinto — Bio y contexto — Vamos Nene...!!!" description="Resumen biográfico y contexto: cómo leer el rendimiento de un piloto argentino en F1 sin caer en el ruido del titular.">
  <h2>Colapinto: bio y contexto</h2>
  <div class="card">
    <p>Cuando un piloto argentino está en foco, el ruido mediático sube. Para entender el rendimiento, conviene mirar tres cosas: <strong>ritmo</strong>, <strong>confiabilidad</strong> y <strong>decisiones del equipo</strong>.</p>
    <p>En este sitio, las noticias se muestran con <strong>fuente + link</strong>, y agregamos <strong>Notas de la Redacción</strong> para explicar “qué significa” sin copiar el artículo original.</p>
    <p class="muted">Ver: <a href="/noticias">Noticias</a> y <a href="/vivo">Vivo</a>.</p>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/glosario-f1.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Glosario F1 — Vamos Nene...!!!" description="Glosario básico en castellano: quali, ritmo, stint, undercut, DRS y conceptos clave para seguir F1.">
  <h2>Glosario F1 (rápido)</h2>
  <div class="card">
    <ul>
      <li><strong>Stint:</strong> tramo de carrera entre paradas.</li>
      <li><strong>Undercut:</strong> parar antes para ganar tiempo con gomas nuevas.</li>
      <li><strong>Overcut:</strong> estirar el stint mientras el otro recalienta o queda en tráfico.</li>
      <li><strong>Ritmo:</strong> consistencia de tiempos (no solo una vuelta rápida).</li>
      <li><strong>DRS:</strong> ayuda en rectas cuando vas a menos de 1s (según zona/regla).</li>
    </ul>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/horarios-argentina.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Horarios de F1 en Argentina — Vamos Nene...!!!" description="Cómo leer horarios de F1 en Argentina: zona horaria, consejos para no confundirte y links directos al calendario.">
  <h2>Horarios de F1 en Argentina</h2>
  <div class="card">
    <p>El error más común es mezclar horario local del circuito con horario en Argentina. Acá todo está mostrado en <strong>America/Argentina/Buenos_Aires</strong>.</p>
    <p>Usá el <a href="/calendario/2026">Calendario 2026</a> y, para el fin de semana, el detalle por evento en <a href="/calendario/2026">cada Gran Premio</a>.</p>
  </div>
</Base>
ASTRO

cat > web/src/pages/guias/testing-bahrain.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
---
<Base title="Testing Baréin — Cómo leer las pruebas — Vamos Nene...!!!" description="Cómo interpretar los tests: combustible, neumáticos, cargas y por qué el tiempo final engaña.">
  <h2>Cómo leer el testing (Baréin)</h2>
  <div class="card">
    <p>En tests, el “mejor tiempo” rara vez cuenta toda la historia. Los equipos prueban con cargas distintas, compuestos distintos y programas distintos.</p>
    <ul>
      <li><strong>Compará stints</strong>, no una vuelta.</li>
      <li><strong>Confiabilidad</strong>: cuántas vueltas completas hacen y con qué problemas.</li>
      <li><strong>Contexto</strong>: temperatura, viento, y tráfico cambian el tiempo.</li>
    </ul>
    <p class="muted">Ver también: <a href="/vivo">Vivo</a> y <a href="/noticias">Noticias</a>.</p>
  </div>
</Base>
ASTRO

echo "==> 8) Reemplazos de links en el resto del sitio (si quedaron rutas viejas)"
# Ajusta links en .astro para que apunten a rutas nuevas
perl -pi -e 's#href="/live"#href="/vivo"#g; s#href="/calendar/2026"#href="/calendario/2026"#g; s#href="/news"#href="/noticias"#g; s#href="/alerts"#href="/avisos"#g; s#href="/merch"#href="/tienda"#g; s#/gp/#/gran-premio/#g' $(find web/src -name "*.astro" -type f) 2>/dev/null || true

echo "==> 9) Done. Commit sugerido:"
echo "   git add . && git commit -m 'seo+ux: rutas es, noticias colapinto, imagenes, load more, sitemap' && git push"
