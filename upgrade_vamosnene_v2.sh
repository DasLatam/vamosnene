#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d "api" || ! -d "web" ]]; then
  echo "ERROR: ejecutá desde la raíz del repo (donde existen ./api y ./web)"
  exit 1
fi

echo "==> 0) .gitignore / limpiar .DS_Store"
touch .gitignore
grep -qE '^\*\.DS_Store$' .gitignore || echo '*.DS_Store' >> .gitignore
find . -name ".DS_Store" -print0 | xargs -0 git rm -f --ignore-unmatch >/dev/null 2>&1 || true

echo "==> 1) API migrations (sync_state + mejoras news/image)"
mkdir -p api/migrations

# Si ya existe 0002, no tocamos. Creamos 0003 para sync_state.
cat > api/migrations/0003_sync_state.sql <<'SQL'
CREATE TABLE IF NOT EXISTS sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
SQL

echo "==> 2) API index.ts (encoding RSS, search más amplio, /status, /sessions, last updated)"
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
  updated_at?: string | null;
};

function corsHeaders(extra?: HeadersInit) {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    ...(extra || {}),
  };
}

function json(data: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(data), {
    headers: { "content-type": "application/json; charset=utf-8", ...corsHeaders(init?.headers) },
    ...init,
  });
}

function ok(text: string, init?: ResponseInit) {
  return new Response(text, { ...init, headers: { ...corsHeaders(init?.headers) } });
}

function isoNow() {
  return new Date().toISOString();
}

function slugify(s: string) {
  return s.toLowerCase().replace(/&/g, "and").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
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

async function setSync(env: Env, key: string, value: string) {
  await env.DB.prepare(
    "INSERT INTO sync_state (key, value, updated_at) VALUES (?1, ?2, ?3) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at"
  ).bind(key, value, isoNow()).run();
}

async function getSync(env: Env, key: string) {
  return await env.DB.prepare("SELECT value, updated_at FROM sync_state WHERE key=?1").bind(key).first<any>();
}

async function seedSources(env: Env) {
  const sources = [
    { code: "f1latam", name: "F1Latam", site_url: "https://www.f1latam.com/", rss_url: "https://www.f1latam.com/rss/rss.php" },
    { code: "f1", name: "Formula1.com", site_url: "https://www.formula1.com/", rss_url: "https://www.formula1.com/en/latest/all.xml" },
    { code: "autosport", name: "Autosport", site_url: "https://www.autosport.com/f1/", rss_url: "https://www.autosport.com/rss/f1/news/" },
    { code: "motorsport", name: "Motorsport.com", site_url: "https://www.motorsport.com/f1/", rss_url: "https://www.motorsport.com/rss/f1/news/" },
  ];

  const stmt = env.DB.prepare("INSERT OR REPLACE INTO news_sources (code, name, site_url, rss_url) VALUES (?1, ?2, ?3, ?4)");
  await env.DB.batch(sources.map(s => stmt.bind(s.code, s.name, s.site_url, s.rss_url)));
}

function stripHtml(s: string) {
  return (s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

function textish(v: any): string {
  if (!v) return "";
  if (typeof v === "string") return v;
  if (typeof v === "object" && "#text" in v) return String(v["#text"] || "");
  return String(v);
}

function fixMojibake(s: string) {
  // Corrige casos comunes tipo "present�" por problemas de decoding
  // (no es mágico; la clave es decodificar bien el RSS; esto es un fallback mínimo)
  return (s || "").replace(/\uFFFD/g, ""); // elimina �
}

function autoNote(title: string, snippet: string, sourceName: string) {
  const t = (title || "").toLowerCase();
  const sn = (snippet || "").toLowerCase();
  const hay = `${t} ${sn}`;
  const tags: string[] = [];
  const add = (x: string) => { if (!tags.includes(x)) tags.push(x); };

  if (hay.includes("colapinto") || (hay.includes("franco") && hay.includes("alpine"))) add("colapinto");
  if (hay.includes("alpine")) add("alpine");
  if (hay.includes("williams")) add("williams");

  if (/(wins|victory|gan(a|ó)|triunf)/.test(hay)) add("resultado");
  if (/(qualifying|pole|clasific)/.test(hay)) add("qualy");
  if (/(practice|fp1|fp2|fp3|práctic)/.test(hay)) add("practica");
  if (/(penalty|sancion|grid drop)/.test(hay)) add("sancion");
  if (/(crash|accident|choque)/.test(hay)) add("incidente");
  if (/(test|testing|pre-season|pretemporada)/.test(hay)) add("testing");

  const angle =
    tags.includes("sancion") ? "posibles cambios en la grilla" :
    tags.includes("incidente") ? "estado del auto y consecuencias deportivas" :
    tags.includes("resultado") ? "tendencias de ritmo y estrategia" :
    "qué significa para el fin de semana";

  const note =
`Según ${sourceName}, la noticia apunta a ${angle}. ` +
`Lectura útil: separar titular de señales (ritmo, confiabilidad, decisiones del equipo). ` +
`Si aparece Colapinto, mirá el contexto (compuesto, carga, tráfico) antes de cerrar conclusiones.`;

  return { note, tags: tags.join(",") };
}

async function fetchRSS(url: string) {
  const res = await fetch(url, { cf: { cacheTtl: 300, cacheEverything: true } as any });
  if (!res.ok) throw new Error(`rss fetch failed ${res.status}`);
  const ct = res.headers.get("content-type") || "";

  const buf = await res.arrayBuffer();
  const bytes = new Uint8Array(buf);

  // Intento UTF-8 primero; si hay muchos � o el header dice latin1/iso-8859-1, pruebo latin1.
  const utf8 = new TextDecoder("utf-8", { fatal: false }).decode(bytes);
  const looksBad = (utf8.match(/\uFFFD/g) || []).length >= 2;
  const wantsLatin1 = /iso-8859-1|latin1/i.test(ct);

  if (wantsLatin1 || looksBad) {
    const latin1 = new TextDecoder("iso-8859-1", { fatal: false }).decode(bytes);
    return latin1;
  }
  return utf8;
}

function extractImageUrl(it: any): string | null {
  const enc = it.enclosure;
  if (enc) {
    if (typeof enc === "object" && (enc.url || enc["@_url"])) return String(enc.url || enc["@_url"]);
    if (typeof enc === "string") return enc;
  }

  const media = it["media:content"] || it["media:thumbnail"];
  const pick = (x: any) => {
    if (!x) return null;
    if (Array.isArray(x)) return pick(x[0]);
    if (typeof x === "object" && (x.url || x["@_url"])) return String(x.url || x["@_url"]);
    return null;
  };
  const m = pick(media);
  if (m) return m;

  const raw = textish(it.description || it.summary || it.content || "");
  const m2 = String(raw).match(/https?:\/\/[^\s"'<>]+?\.(jpg|jpeg|png|webp)/i);
  if (m2?.[0]) return m2[0];

  return null;
}

async function syncNews(env: Env) {
  await seedSources(env);

  const srcRows = await env.DB.prepare("SELECT code, name, rss_url FROM news_sources").all();
  const sources = (srcRows.results || []) as any[];

  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: "", trimValues: true });

  let inserted = 0;

  for (const s of sources) {
    try {
      const xml = await fetchRSS(s.rss_url);
      const data = parser.parse(xml);

      const items = data?.rss?.channel?.item || data?.feed?.entry || [];
      const arr = Array.isArray(items) ? items : [items];

      for (const it of arr.slice(0, 60)) {
        const titleRaw = textish(it.title && (it.title["#text"] || it.title)) || textish(it.title);
        const title = fixMojibake(titleRaw);
        const link =
          (typeof it.link === "string" ? it.link :
           it.link?.href || it.link?.["@_href"] || it.link?.["href"] ||
           (Array.isArray(it.link) ? (it.link[0]?.href || it.link[0]) : "")) || "";

        const guid = textish(it.guid && (it.guid["#text"] || it.guid)) || link || `${s.code}:${title}`;
        const pub = it.pubDate || it.published || it.updated || null;

        const rawDesc = it.description || it.summary || it.content || "";
        const descRaw = typeof rawDesc === "string" ? rawDesc : rawDesc?.["#text"] || "";
        const desc = fixMojibake(stripHtml(descRaw));
        const snippet = desc.slice(0, 220).trim();

        if (!title || !link) continue;

        const { note, tags } = autoNote(title, snippet, s.name);
        const imageUrl = extractImageUrl(it);

        const r = await env.DB.prepare(
          "INSERT OR IGNORE INTO articles (guid, source_code, title, url, published_at, snippet, auto_note, tags, image_url) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)"
        ).bind(guid, s.code, title, link, pub, snippet, note, tags, imageUrl).run();

        if ((r as any)?.meta?.changes) inserted += (r as any).meta.changes;
      }
    } catch (e) {
      console.log("RSS failed", s.code, String(e));
    }
  }

  await setSync(env, "news", JSON.stringify({ inserted }));
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

  // Testing Bahrain (3 días)
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

  await setSync(env, "schedule", "ok");
}

async function getNow(env: Env) {
  const nowIso = isoNow();
  const last = await env.DB.prepare("SELECT * FROM sessions WHERE end_time < ?1 ORDER BY end_time DESC LIMIT 1")
    .bind(nowIso).first<SessionRow>();

  const current = await env.DB.prepare("SELECT * FROM sessions WHERE start_time <= ?1 AND end_time >= ?1 ORDER BY start_time ASC LIMIT 1")
    .bind(nowIso).first<SessionRow>();

  const next = await env.DB.prepare("SELECT * FROM sessions WHERE start_time > ?1 ORDER BY start_time ASC LIMIT 1")
    .bind(nowIso).first<SessionRow>();

  const today = await env.DB.prepare("SELECT * FROM sessions WHERE date(start_time) = date(?1) ORDER BY start_time ASC")
    .bind(nowIso).all<SessionRow>();

  return { now: nowIso, last, current, next, today: today.results || [] };
}

async function listSessions(env: Env, fromIso: string, toIso: string) {
  const rows = await env.DB.prepare(
    "SELECT * FROM sessions WHERE start_time >= ?1 AND start_time <= ?2 ORDER BY start_time ASC"
  ).bind(fromIso, toIso).all<SessionRow>();
  return rows.results || [];
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

  await env.DB.prepare("INSERT OR REPLACE INTO weather_cache (event_slug, fetched_at, payload) VALUES (?1, ?2, ?3)")
    .bind(eventSlug, isoNow(), JSON.stringify(payload)).run();

  await setSync(env, "weather", eventSlug);
}

async function syncWeather(env: Env) {
  const { current, next } = await getNow(env);
  const slug = (current?.event_slug || next?.event_slug);
  if (!slug) return;
  await syncWeatherForEvent(env, slug);
}

async function getEvent(env: Env, slug: string) {
  const sessions = await env.DB.prepare(
    "SELECT * FROM sessions WHERE event_slug = ?1 ORDER BY start_time ASC"
  ).bind(slug).all<any>();

  let weatherRow = await env.DB.prepare(
    "SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1"
  ).bind(slug).first<any>();

  if (env.OPENWEATHER_API_KEY) {
    const stale = !weatherRow?.fetched_at || hoursBetween(weatherRow.fetched_at, isoNow()) > 2;
    if (stale) {
      try {
        await syncWeatherForEvent(env, slug);
        weatherRow = await env.DB.prepare("SELECT fetched_at, payload FROM weather_cache WHERE event_slug = ?1").bind(slug).first<any>();
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
  const qRaw = (opts.q || "").trim().toLowerCase();
  const q = qRaw === "all" ? "" : qRaw;
  const like = `%${q}%`;

  const rows = await env.DB.prepare(
    `SELECT a.title, a.url, a.published_at, a.snippet, a.auto_note, a.tags, a.image_url,
            s.name as source_name, s.site_url as source_url
     FROM articles a
     JOIN news_sources s ON s.code = a.source_code
     WHERE (?1 = '' OR
            lower(a.title) LIKE ?2 OR
            lower(a.snippet) LIKE ?2 OR
            lower(a.tags) LIKE ?2 OR
            lower(a.auto_note) LIKE ?2)
     ORDER BY a.published_at DESC, a.id DESC
     LIMIT ?3 OFFSET ?4`
  ).bind(q, like, opts.limit, opts.offset).all<any>();

  // last update: max(published_at) visible
  const last = await env.DB.prepare("SELECT MAX(published_at) AS max_pub FROM articles").first<any>();

  return { items: rows.results || [], max_published_at: last?.max_pub || null };
}

async function subscribe(env: Env, email: string) {
  email = email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { ok: false, error: "Email inválido" };
  await env.DB.prepare("INSERT OR IGNORE INTO subscribers (email, locale) VALUES (?1, 'es-AR')").bind(email).run();
  return { ok: true };
}

async function sendAlerts(env: Env) {
  if (!env.BREVO_API_KEY || !env.SENDER_EMAIL) return;

  const now = new Date();
  const from = new Date(now.getTime() + 72 * 3600_000).toISOString();
  const to = new Date(now.getTime() + 96 * 3600_000).toISOString();

  const sessions = await env.DB.prepare(
    "SELECT * FROM sessions WHERE start_time >= ?1 AND start_time < ?2 ORDER BY start_time ASC"
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

  await setSync(env, "alerts", "sent");
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

  if (!res.ok) console.log("brevo send failed", res.status, await res.text());
}

async function handleAdminSync(req: Request, env: Env) {
  const url = new URL(req.url);
  const key = url.searchParams.get("key") || "";
  if (!env.ADMIN_KEY || key !== env.ADMIN_KEY) return json({ ok: false, error: "unauthorized" }, { status: 401 });

  await syncSchedule(env);
  await syncNews(env);
  await syncWeather(env);
  return json({ ok: true });
}

async function status(env: Env) {
  const s = await getSync(env, "schedule");
  const n = await getSync(env, "news");
  const w = await getSync(env, "weather");
  const a = await getSync(env, "alerts");

  const counts = await env.DB.prepare(
    "SELECT (SELECT COUNT(*) FROM sessions) AS sessions, (SELECT COUNT(*) FROM articles) AS articles, (SELECT COUNT(*) FROM subscribers) AS subs"
  ).first<any>();

  return {
    now: isoNow(),
    sync: {
      schedule: s?.updated_at || null,
      news: n?.updated_at || null,
      weather: w?.updated_at || null,
      alerts: a?.updated_at || null,
    },
    counts: counts || {}
  };
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext) {
    const url = new URL(req.url);
    if (req.method === "OPTIONS") return ok("", { status: 204 });

    if (url.pathname === "/api/health") return json({ ok: true });
    if (url.pathname === "/api/status") return json(await status(env));

    if (url.pathname === "/api/now") return json(await getNow(env));

    if (url.pathname === "/api/sessions") {
      const from = url.searchParams.get("from");
      const to = url.searchParams.get("to");
      if (!from || !to) return json({ error: "missing_from_to" }, { status: 400 });
      const items = await listSessions(env, from, to);
      return json({ items, from, to });
    }

    if (url.pathname === "/api/news") {
      const q = (url.searchParams.get("q") ?? "colapinto").trim();
      const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") || "20", 10), 1), 50);
      const offset = Math.max(parseInt(url.searchParams.get("offset") || "0", 10), 0);
      const data = await listNews(env, { q, limit, offset });
      return json({ ...data, q, limit, offset });
    }

    if (url.pathname === "/api/events") return json({ events: await listEvents(env) });

    if (url.pathname === "/api/event") {
      const slug = url.searchParams.get("slug") || "";
      if (!slug) return json({ error: "missing_slug" }, { status: 400 });
      return json(await getEvent(env, slug));
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

    if (url.pathname === "/api/admin/sync") return handleAdminSync(req, env);

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

echo "==> 3) WEB assets (favicon 43 + imágenes SVG Colapinto/Alpine + sol)"
mkdir -p web/public/img

cat > web/public/favicon.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <defs>
    <linearGradient id="a" x1="0" x2="1">
      <stop offset="0" stop-color="#74ACDF"/>
      <stop offset="1" stop-color="#ffffff"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="28" fill="#0b1020"/>
  <rect x="10" y="10" width="108" height="108" rx="24" fill="url(#a)" opacity="0.95"/>
  <circle cx="94" cy="34" r="12" fill="#f6c343"/>
  <g fill="#f6c343" opacity="0.9">
    <path d="M94 14 l2 10 h-4z"/>
    <path d="M94 54 l2 -10 h-4z"/>
    <path d="M74 34 l10 2 v-4z"/>
    <path d="M114 34 l-10 2 v-4z"/>
  </g>
  <text x="32" y="88" font-family="system-ui, -apple-system, Segoe UI, Roboto" font-weight="900" font-size="54" fill="#0b1020">43</text>
</svg>
SVG

cat > web/public/img/sol.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
  <circle cx="32" cy="32" r="14" fill="#f6c343"/>
  <g fill="#f6c343">
    <path d="M32 2l3 14h-6z"/>
    <path d="M32 62l3-14h-6z"/>
    <path d="M2 32l14 3v-6z"/>
    <path d="M62 32l-14 3v-6z"/>
    <path d="M10 10l10 10-5 5z"/>
    <path d="M54 54l-10-10 5-5z"/>
    <path d="M54 10l-10 10-5-5z"/>
    <path d="M10 54l10-10 5 5z"/>
  </g>
</svg>
SVG

cat > web/public/img/colapinto.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="600">
  <defs>
    <linearGradient id="g" x1="0" x2="1">
      <stop offset="0" stop-color="#74ACDF" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0.10"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="600" fill="#0b1020"/>
  <rect x="60" y="60" width="1080" height="480" rx="40" fill="url(#g)" stroke="rgba(255,255,255,0.16)"/>
  <text x="110" y="180" fill="rgba(255,255,255,0.92)" font-family="system-ui" font-size="54" font-weight="900">Franco Colapinto</text>
  <text x="110" y="245" fill="rgba(255,255,255,0.72)" font-family="system-ui" font-size="26" font-weight="700">Ilustración propia (placeholder) · Celeste/Blanco · #43</text>
  <g transform="translate(110,290)">
    <path d="M120 180c90-20 160-80 190-160 10-28 10-60-5-85-25-40-80-55-130-40-45 14-80 50-95 92-20 55-35 120-60 170z" fill="rgba(255,255,255,0.16)"/>
    <circle cx="260" cy="60" r="28" fill="#f6c343"/>
    <text x="520" y="120" fill="#74ACDF" font-family="system-ui" font-size="140" font-weight="950">43</text>
    <text x="520" y="170" fill="rgba(255,255,255,0.78)" font-family="system-ui" font-size="28" font-weight="800">Vamos Nene..!</text>
  </g>
</svg>
SVG

cat > web/public/img/alpine.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="600">
  <defs>
    <linearGradient id="p" x1="0" x2="1">
      <stop offset="0" stop-color="#1fa3ff" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#ff5ab3" stop-opacity="0.22"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="600" fill="#0b1020"/>
  <rect x="60" y="60" width="1080" height="480" rx="40" fill="url(#p)" stroke="rgba(255,255,255,0.16)"/>
  <text x="110" y="180" fill="rgba(255,255,255,0.92)" font-family="system-ui" font-size="54" font-weight="900">Alpine (colores guía)</text>
  <text x="110" y="245" fill="rgba(255,255,255,0.72)" font-family="system-ui" font-size="26" font-weight="700">Azul + Rosa (referencia visual) · Placeholder</text>
  <g transform="translate(120,320)" fill="none" stroke="rgba(255,255,255,0.40)" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
    <path d="M80 160c120-80 260-120 420-120 120 0 220 20 320 60 40 16 80 34 120 54"/>
    <path d="M170 160c40-80 110-120 210-120h110c90 0 150 40 190 110"/>
    <circle cx="260" cy="170" r="40"/>
    <circle cx="700" cy="170" r="40"/>
  </g>
  <text x="980" y="510" fill="#ff5ab3" font-family="system-ui" font-size="56" font-weight="950">A</text>
</svg>
SVG

echo "==> 4) WEB Base layout (colores AR + alpine, favicon, brand clickeable, footer sitemap, disclaimer abajo)"
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
        --bg:#070b18;
        --card:rgba(255,255,255,.06);
        --border:rgba(255,255,255,.16);
        --text:rgba(255,255,255,.92);
        --muted:rgba(255,255,255,.72);

        /* Argentina */
        --ar:#74ACDF;
        --sun:#f6c343;

        /* Alpine accents */
        --alpine-blue:#1fa3ff;
        --alpine-pink:#ff5ab3;

        --cta:#22c55e;
        color-scheme: dark;
      }
      *{ box-sizing:border-box; }
      body{
        margin:0;
        font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Noto Sans", sans-serif;
        line-height:1.5;
        background:
          radial-gradient(900px 560px at 12% 0%, rgba(116,172,223,.20), transparent 60%),
          radial-gradient(900px 560px at 88% 10%, rgba(255,90,179,.14), transparent 55%),
          radial-gradient(1200px 700px at 70% 0%, rgba(31,163,255,.16), transparent 60%),
          var(--bg);
        color: var(--text);
      }
      a{ color: inherit; }
      .wrap{ max-width: 1080px; margin: 0 auto; padding: 18px; }
      header{
        position: sticky; top:0;
        backdrop-filter: blur(10px);
        background: rgba(7,11,24,.74);
        border-bottom: 1px solid var(--border);
        z-index: 10;
      }
      .topbar{ display:flex; align-items:center; justify-content:space-between; gap: 12px; }
      .brandLink{ text-decoration:none; display:flex; align-items:center; gap:10px; }
      .brandTitle{ display:flex; flex-direction:column; gap:2px; }
      .brandTitle strong{ letter-spacing:.2px; }
      .brandTitle small{ color: var(--muted); font-size:12px; }
      nav a{ text-decoration:none; opacity:.9; margin-right: 12px; font-weight: 700; }
      nav a:hover{ opacity:1; text-decoration: underline; text-underline-offset: 4px; }
      .btn{
        display:inline-flex; align-items:center; justify-content:center;
        padding:10px 12px; border-radius: 12px;
        border: 1px solid var(--border);
        background: rgba(255,255,255,.04);
        text-decoration:none;
        font-weight: 800;
      }
      .btn.primary{ background: var(--cta); border-color: rgba(0,0,0,.2); color:#07130a; }
      .hero{ padding: 14px 0 0; }
      .heroCard{
        border-radius: 18px;
        background: linear-gradient(90deg, rgba(116,172,223,.16), rgba(255,255,255,.06));
        border: 1px solid var(--border);
        padding: 14px;
      }
      .hero h1{ margin: 0 0 6px; font-size: 26px; letter-spacing:.2px; }
      .muted{ color: var(--muted); }
      main{ padding: 14px 0 24px; }
      .card{
        border: 1px solid var(--border);
        border-radius: 16px;
        padding: 14px;
        background: var(--card);
        margin: 14px 0;
      }
      .grid{ display:grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; }
      .pill{
        display:inline-block;
        padding: 4px 10px;
        border-radius: 999px;
        border:1px solid var(--border);
        color: var(--muted);
        font-size: 12px;
        background: rgba(255,255,255,.03);
      }
      .row{ display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
      .spacer{ flex:1; }
      footer{ border-top: 1px solid var(--border); padding: 18px 0 26px; color: var(--muted); }
      img{ max-width:100%; height:auto; }
      input,button{ font:inherit; }
      code{ color: rgba(116,172,223,.95); }
      .siteMapGrid{ display:grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 14px; margin-top: 12px; }
      .siteMapGrid a{ text-decoration:none; }
      .siteMapGrid a:hover{ text-decoration: underline; text-underline-offset: 3px; }
      .noteBox{
        border-left: 4px solid var(--ar);
        padding: 10px 12px;
        border-radius: 12px;
        background: rgba(116,172,223,.10);
      }
    </style>

    <!-- AdSense: pegá acá el script cuando te aprueben -->
    <!-- <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXX" crossorigin="anonymous"></script> -->
  </head>

  <body>
    <header>
      <div class="wrap topbar">
        <a class="brandLink" href="/" aria-label="Inicio">
          <img src="/img/sol.svg" width="28" height="28" alt="Sol de Mayo" />
          <div class="brandTitle">
            <strong>Vamos Nene...!!!</strong>
            <small>F1 en castellano · foco Colapinto · calendario · clima</small>
          </div>
        </a>

        <nav class="row">
          <a href="/vivo">Vivo</a>
          <a href="/calendario/2026">Calendario</a>
          <a href="/noticias">Noticias</a>
          <a href="/tienda">Tienda</a>
          <a href="/suscribirme">Suscribirme</a>
          <span class="spacer"></span>
          <a class="btn primary" href="/suscribirme">Recibir avisos</a>
        </nav>
      </div>
    </header>

    <div class="wrap hero">
      <div class="heroCard">
        <h1>Todo lo importante de F1, en clave argentina.</h1>
        <div class="row">
          <span class="pill">Celeste + Blanco</span>
          <span class="pill">#43</span>
          <span class="pill">Horarios ARG</span>
          <span class="pill">Clima del circuito</span>
          <span class="pill">Noticias con contexto</span>
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

echo "==> 5) WEB robots + OG (dejar robots como está, pero agregamos og.svg si faltaba)"
cat > web/public/og.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#74ACDF" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#ff5ab3" stop-opacity="0.20"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="#070b18"/>
  <rect x="60" y="70" width="1080" height="490" rx="36" fill="url(#g)" stroke="rgba(255,255,255,0.16)" />
  <text x="120" y="230" fill="rgba(255,255,255,0.92)" font-family="system-ui" font-size="72" font-weight="900">Vamos Nene...!!!</text>
  <text x="120" y="315" fill="rgba(255,255,255,0.78)" font-family="system-ui" font-size="34" font-weight="700">F1 en castellano · Colapinto · Calendario · Clima</text>
  <text x="120" y="395" fill="rgba(255,255,255,0.70)" font-family="system-ui" font-size="26">Noticias con fuente + contexto · Horarios ARG · Avisos 72h</text>
</svg>
SVG

# robots: no lo rompemos si ya estaba; si no existe, lo creamos
if [[ ! -f web/public/robots.txt ]]; then
cat > web/public/robots.txt <<'TXT'
User-agent: *
Allow: /
Sitemap: https://vamosnene.pages.dev/sitemap.xml
TXT
fi

echo "==> 6) WEB: /suscribirme unifica avisos (redirects) + tienda mejorada + vivo mejorado + gran premio mejorado + noticias mejoradas"

mkdir -p web/src/pages/noticias web/src/pages/calendario web/src/pages/guias web/src/pages/gran-premio

# redirects viejos -> nuevos
cat > web/src/pages/alerts.astro <<'ASTRO'
---
return Astro.redirect("/suscribirme", 301);
---
ASTRO
cat > web/src/pages/avisos.astro <<'ASTRO'
---
return Astro.redirect("/suscribirme", 301);
---
ASTRO

cat > web/src/pages/merch.astro <<'ASTRO'
---
return Astro.redirect("/tienda", 301);
---
ASTRO

cat > web/src/pages/live.astro <<'ASTRO'
---
return Astro.redirect("/vivo", 301);
---
ASTRO

cat > web/src/pages/calendar/2026.astro <<'ASTRO'
---
return Astro.redirect("/calendario/2026", 301);
---
ASTRO

cat > web/src/pages/news/index.astro <<'ASTRO'
---
return Astro.redirect("/noticias", 301);
---
ASTRO

cat > web/src/pages/gp/[slug].astro <<'ASTRO'
---
const { slug } = Astro.params;
return Astro.redirect(`/gran-premio/${slug}`, 301);
---
ASTRO

# /suscribirme (unificada)
cat > web/src/pages/suscribirme.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
const status = api ? await fetch(`${api}/api/status`).then(r => r.json()).catch(() => null) : null;

function fmt(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Suscribirme — Vamos Nene...!!!" description="Avisos útiles: 72h antes (cronograma, clima y dónde verlo), y recordatorios de sesiones clave.">
  <h2>Suscribirme</h2>

  <div class="card">
    <p><strong>¿Para qué sirve?</strong> Para no perderte nada. Te mandamos avisos útiles y concretos:</p>
    <ul>
      <li><strong>72h antes:</strong> cronograma (horarios ARG) + clima estimado + “dónde verlo”.</li>
      <li><strong>Día de actividad:</strong> recordatorio de la primera sesión del día.</li>
      <li><strong>Cambios:</strong> si actualizamos calendario o clima relevante.</li>
    </ul>
    <p class="muted">Última actualización (sistema): {fmt(status?.sync?.alerts)}.</p>
  </div>

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

# /tienda (3 productos con opciones)
cat > web/src/pages/tienda.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
const status = api ? await fetch(`${api}/api/status`).then(r => r.json()).catch(() => null) : null;

function fmt(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Tienda — Vamos Nene...!!!" description="Merch celeste y blanco: 43 + Vamos Nene. Remeras, buzos y gorras (catálogo).">
  <h2>Tienda</h2>

  <div class="card">
    <p><strong>Qué vas a ver:</strong> catálogo base (3 productos) con variantes de talle y color. El diseño es el mismo: celeste/blanco + <strong>43</strong> + “<strong>Vamos Nene..!</strong>”.</p>
    <p class="muted">Actualización: {fmt(status?.now)} · Esto es catálogo; la compra se conectará a print-on-demand (sin stock).</p>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Remera</h3>
      <img src="/img/colapinto.svg" alt="Remera Vamos Nene" style="border-radius:14px;border:1px solid rgba(255,255,255,.12);margin:10px 0" />
      <div class="row">
        <label class="muted">Talle</label>
        <select style="padding:8px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92)">
          <option>S</option><option>M</option><option>L</option><option>XL</option>
        </select>
        <label class="muted">Color</label>
        <select style="padding:8px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92)">
          <option>Celeste</option><option>Blanco</option><option>Negro</option>
        </select>
      </div>
      <div class="muted" style="margin-top:10px">Compra: pronto (link externo)</div>
      <a class="btn primary" href="/contact" style="margin-top:10px">Quiero este diseño</a>
    </div>

    <div class="card">
      <h3>Buzo</h3>
      <img src="/img/alpine.svg" alt="Buzo Vamos Nene" style="border-radius:14px;border:1px solid rgba(255,255,255,.12);margin:10px 0" />
      <div class="row">
        <label class="muted">Talle</label>
        <select style="padding:8px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92)">
          <option>S</option><option>M</option><option>L</option><option>XL</option>
        </select>
        <label class="muted">Color</label>
        <select style="padding:8px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92)">
          <option>Celeste</option><option>Blanco</option><option>Azul (Alpine)</option><option>Rosa (Alpine)</option>
        </select>
      </div>
      <div class="muted" style="margin-top:10px">Compra: pronto (link externo)</div>
      <a class="btn primary" href="/contact" style="margin-top:10px">Quiero este diseño</a>
    </div>

    <div class="card">
      <h3>Gorra</h3>
      <img src="/img/colapinto.svg" alt="Gorra Vamos Nene" style="border-radius:14px;border:1px solid rgba(255,255,255,.12);margin:10px 0" />
      <div class="row">
        <label class="muted">Talle</label>
        <select style="padding:8px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92)">
          <option>Único</option>
        </select>
        <label class="muted">Color</label>
        <select style="padding:8px 10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);color:rgba(255,255,255,.92)">
          <option>Celeste</option><option>Blanco</option><option>Negro</option>
        </select>
      </div>
      <div class="muted" style="margin-top:10px">Compra: pronto (link externo)</div>
      <a class="btn primary" href="/contact" style="margin-top:10px">Quiero este diseño</a>
    </div>
  </div>
</Base>
ASTRO

# /vivo mejorado
cat > web/src/pages/vivo.astro <<'ASTRO'
---
import Base from "../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";

async function safeJson(url) {
  try { const r = await fetch(url); return await r.json(); } catch { return null; }
}

const status = api ? await safeJson(`${api}/api/status`) : null;
const now = api ? await safeJson(`${api}/api/now`) : null;

// sesiones próximas 7 días
const from = new Date().toISOString();
const to = new Date(Date.now() + 7*24*3600*1000).toISOString();
const sessionsResp = api ? await safeJson(`${api}/api/sessions?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`) : null;
const sessions = sessionsResp?.items || [];

const weather = api ? await safeJson(`${api}/api/weather`) : null;
const news = api ? await safeJson(`${api}/api/news?q=colapinto&limit=10&offset=0`) : null;

const tz = "America/Argentina/Buenos_Aires";
const dkey = (iso) => new Intl.DateTimeFormat("en-CA", { timeZone: tz, year:"numeric", month:"2-digit", day:"2-digit" }).format(new Date(iso));
const todayKey = dkey(new Date().toISOString());
const tomorrowKey = dkey(new Date(Date.now() + 24*3600*1000).toISOString());

const todaySessions = sessions.filter(s => dkey(s.start_time) === todayKey);
const tomorrowSessions = sessions.filter(s => dkey(s.start_time) === tomorrowKey);
const nextSessions = sessions.filter(s => dkey(s.start_time) !== todayKey && dkey(s.start_time) !== tomorrowKey).slice(0, 12);

function fmt(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "full", timeStyle: "short", timeZone: tz }).format(d);
}

function dayLabel(key) {
  if (key === todayKey) return "Hoy";
  if (key === tomorrowKey) return "Mañana";
  return "Próximamente";
}

function whereToWatchBlock() {
  return `
    <ul>
      <li><strong>Streaming:</strong> Disney+ (según plan/disponibilidad).</li>
      <li><strong>TV / cable:</strong> señales deportivas (según operador).</li>
      <li><strong>Operadores típicos:</strong> Flow, DirecTV, Telecentro, Movistar (puede variar).</li>
    </ul>
    <p class="muted">Nota: la disponibilidad cambia por temporada y proveedor. Confirmá en tu grilla o app.</p>
  `;
}

function summarizeForecast(payload) {
  if (!payload?.list?.length) return [];
  const groups = new Map();
  for (const it of payload.list) {
    const key = dkey(it.dt_txt || new Date(it.dt*1000).toISOString());
    const t = it.main?.temp;
    const icon = it.weather?.[0]?.icon;
    const desc = it.weather?.[0]?.description;
    if (!groups.has(key)) groups.set(key, { key, min: t, max: t, icon, desc });
    const g = groups.get(key);
    if (typeof t === "number") {
      g.min = Math.min(g.min ?? t, t);
      g.max = Math.max(g.max ?? t, t);
    }
    // keep first icon/desc
  }
  return Array.from(groups.values()).slice(0, 5);
}
const daily = summarizeForecast(weather?.weather);
---
<Base title="Vivo — Vamos Nene...!!!" description="Contexto en vivo: agenda (hoy/mañana), horarios ARG, clima del circuito y noticias (Colapinto).">
  <h2>Contexto en vivo</h2>

  <div class="card">
    <p><strong>Qué vas a ver:</strong> agenda (hoy/mañana/próximamente), horarios en Argentina, clima del circuito y noticias relevantes.</p>
    <p><strong>Fuentes consultadas:</strong> calendario (Ergast/Jolpica), clima (OpenWeather), noticias (RSS con crédito por fuente).</p>
    <p class="muted">
      Última actualización: calendario {status?.sync?.schedule ? fmt(status.sync.schedule) : "—"} ·
      noticias {status?.sync?.news ? fmt(status.sync.news) : "—"} ·
      clima {status?.sync?.weather ? fmt(status.sync.weather) : "—"}.
    </p>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Ahora / Próximo</h3>
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
      <h3>Dónde verlo</h3>
      <div set:html={whereToWatchBlock()} />
    </div>

    <div class="card">
      <h3>Clima (tendencia)</h3>
      {weather?.weather?.city?.name ? (
        <div>
          <div><strong>{weather.weather.city.name}</strong></div>
          <div class="muted">Actualizado: {weather.fetched_at ? fmt(weather.fetched_at) : "—"}</div>
          <div style="margin-top:10px">
            {daily.map(d => (
              <div class="row" style="justify-content:space-between;margin:6px 0">
                <div>
                  <strong>{dayLabel(d.key)}</strong> <span class="muted">({d.key})</span>
                </div>
                <div class="row" style="gap:8px">
                  {d.icon ? <img src={`https://openweathermap.org/img/wn/${d.icon}@2x.png`} width="34" height="34" alt={d.desc || "clima"} /> : null}
                  <span>{Math.round(d.min)}° / {Math.round(d.max)}°</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div class="muted">Todavía no hay pronóstico cacheado para el evento actual/próximo.</div>
      )}
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Agenda — Hoy</h3>
      {todaySessions.length ? (
        <ul>
          {todaySessions.map(s => (
            <li style="margin:10px 0">
              <strong>{s.event_name}</strong> — {s.session_name}
              <div class="muted" style="font-size:12px">{fmt(s.start_time)} → {fmt(s.end_time)}</div>
            </li>
          ))}
        </ul>
      ) : <div class="muted">No hay sesiones hoy en la ventana de los próximos 7 días.</div>}
    </div>

    <div class="card">
      <h3>Agenda — Mañana</h3>
      {tomorrowSessions.length ? (
        <ul>
          {tomorrowSessions.map(s => (
            <li style="margin:10px 0">
              <strong>{s.event_name}</strong> — {s.session_name}
              <div class="muted" style="font-size:12px">{fmt(s.start_time)} → {fmt(s.end_time)}</div>
            </li>
          ))}
        </ul>
      ) : <div class="muted">No hay sesiones mañana en la ventana de los próximos 7 días.</div>}
    </div>

    <div class="card">
      <h3>Próximamente</h3>
      {nextSessions.length ? (
        <ul>
          {nextSessions.map(s => (
            <li style="margin:10px 0">
              <a href={`/gran-premio/${s.event_slug}`}><strong>{s.event_name}</strong></a> — {s.session_name}
              <div class="muted" style="font-size:12px">{fmt(s.start_time)}</div>
            </li>
          ))}
        </ul>
      ) : <div class="muted">Sin próximas sesiones.</div>}
    </div>
  </div>

  <div class="card">
    <h3>Noticias (Colapinto)</h3>
    {news?.items?.length ? (
      <ul>
        {news.items.slice(0,8).map(n => (
          <li style="margin:10px 0">
            <a href={n.url} rel="nofollow noopener noreferrer" target="_blank">{n.title}</a>
            <div class="muted" style="font-size:12px">{n.source_name}</div>
          </li>
        ))}
      </ul>
    ) : <div class="muted">Sin noticias aún.</div>}
    <a class="btn" href="/noticias">Ver todas</a>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Galería</h3>
      <img src="/img/colapinto.svg" alt="Colapinto placeholder" style="border-radius:14px;border:1px solid rgba(255,255,255,.12)"/>
    </div>
    <div class="card">
      <h3>Alpine (colores guía)</h3>
      <img src="/img/alpine.svg" alt="Alpine placeholder" style="border-radius:14px;border:1px solid rgba(255,255,255,.12)"/>
    </div>
  </div>
</Base>
ASTRO

# /calendario/2026 (se mantiene; solo aseguramos que existe)
cat > web/src/pages/calendario/2026.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
const status = api ? await fetch(`${api}/api/status`).then(r => r.json()).catch(() => null) : null;
const res = api ? await fetch(`${api}/api/events`) : null;
const data = res ? await res.json() : { events: [] };

function fmt(iso) {
  if (!iso) return "-";
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(new Date(iso));
}
---
<Base title="Calendario 2026 — Vamos Nene...!!!" description="Calendario F1 2026: prácticas, clasificación, sprint y carrera con horarios en Argentina.">
  <h2>Calendario 2026</h2>
  <div class="card">
    <p><strong>Qué vas a ver:</strong> lista de eventos con páginas por Gran Premio (sesiones + horarios ARG + clima).</p>
    <p class="muted">Última actualización calendario: {status?.sync?.schedule ? fmt(status.sync.schedule) : "—"}.</p>
  </div>

  <div class="card">
    {!api ? <div class="muted">Falta configurar <code>PUBLIC_API_BASE</code> en Cloudflare Pages.</div> : null}
    {data.events?.length ? (
      <ul>
        {data.events.map((e) => (
          <li style="margin:10px 0">
            <a href={`/gran-premio/${e.event_slug}`}><strong>{e.event_name}</strong></a>
            <div class="muted">{fmt(e.start_time)} → {fmt(e.end_time)} · {e.locality || ""} {e.country ? `(${e.country})` : ""}</div>
          </li>
        ))}
      </ul>
    ) : <div class="muted">Todavía no hay eventos (corré el sync admin o esperá al cron).</div>}
  </div>
</Base>
ASTRO

# /gran-premio/[slug]
cat > web/src/pages/gran-premio/[slug].astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";
const { slug } = Astro.params;

const status = api ? await fetch(`${api}/api/status`).then(r => r.json()).catch(() => null) : null;
const res = api ? await fetch(`${api}/api/event?slug=${encodeURIComponent(slug)}`) : null;
const ev = res ? await res.json() : { sessions: [], weather: null };

const tz = "America/Argentina/Buenos_Aires";
function fmt(iso) {
  if (!iso) return "-";
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "full", timeStyle: "short", timeZone: tz }).format(new Date(iso));
}
---
<Base title={`${ev.sessions?.[0]?.event_name || slug} — Vamos Nene...!!!`} description="Detalle del evento: sesiones + horarios Argentina + clima del circuito + guía de transmisión.">
  <h2>{ev.sessions?.[0]?.event_name || slug}</h2>
  <p class="muted">{ev.sessions?.[0]?.circuit_name || ""} · {ev.sessions?.[0]?.locality || ""} · {ev.sessions?.[0]?.country || ""}</p>

  <div class="card">
    <p><strong>Qué vas a ver:</strong> sesiones oficiales con horario ARG, clima del circuito y links útiles.</p>
    <p><strong>Fuentes:</strong> calendario (Ergast/Jolpica) · clima (OpenWeather) · noticias (RSS con crédito).</p>
    <p class="muted">Actualización: calendario {status?.sync?.schedule ? fmt(status.sync.schedule) : "—"} · clima {status?.sync?.weather ? fmt(status.sync.weather) : "—"}.</p>
  </div>

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
        <div class="muted">Todavía no hay pronóstico cacheado para este evento. Si ya configuraste OpenWeather, recargá (el API intenta cachear on-demand) o corré el sync.</div>
      )}
    </div>

    <div class="card">
      <h3>Dónde verlo</h3>
      <ul>
        <li><strong>Streaming:</strong> Disney+ (según plan/disponibilidad).</li>
        <li><strong>TV / cable:</strong> señales deportivas (según operador).</li>
        <li><strong>Operadores típicos:</strong> Flow, DirecTV, Telecentro, Movistar (puede variar).</li>
      </ul>
      <p class="muted">Confirmá disponibilidad en tu proveedor: cambia por temporada y plan.</p>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Imagen (placeholder)</h3>
      <img src="/img/colapinto.svg" alt="Colapinto placeholder" style="border-radius:14px;border:1px solid rgba(255,255,255,.12)"/>
    </div>
    <div class="card">
      <h3>Alpine (placeholder)</h3>
      <img src="/img/alpine.svg" alt="Alpine placeholder" style="border-radius:14px;border:1px solid rgba(255,255,255,.12)"/>
    </div>
  </div>
</Base>
ASTRO

# /noticias mejoradas (intro + status + encoding arreglado en API + imagen fallback + callout notas)
cat > web/src/pages/noticias/index.astro <<'ASTRO'
---
import Base from "../../layouts/Base.astro";
const api = import.meta.env.PUBLIC_API_BASE || "";

const q = "colapinto";
const limit = 15;
const offset = 0;

const status = api ? await fetch(`${api}/api/status`).then(r => r.json()).catch(() => null) : null;
const res = api ? await fetch(`${api}/api/news?q=${encodeURIComponent(q)}&limit=${limit}&offset=${offset}`) : null;
const data = res ? await res.json() : { items: [], q, limit, offset };

function fmt(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Argentina/Buenos_Aires" }).format(d);
}
---
<Base title="Noticias — Vamos Nene...!!!" description="Noticias de Colapinto con fuente y link, más notas editoriales automáticas en castellano.">
  <h2>Noticias (Colapinto)</h2>

  <div class="card">
    <p><strong>Qué vas a ver:</strong> titulares con crédito a la fuente + link, y un bloque de “Notas de la Redacción” con contexto breve (sin copiar el artículo).</p>
    <p><strong>Fuentes consultadas:</strong> RSS de F1Latam, Formula1.com, Autosport y Motorsport.com.</p>
    <p class="muted">Última actualización: {status?.sync?.news ? fmt(status.sync.news) : "—"}.</p>
    <p class="muted">Tip: para ver todo (sin filtro), usá el botón “Ver todo”.</p>
    <div class="row" style="margin-top:10px">
      <a class="btn" href="/noticias">Colapinto</a>
      <a class="btn" href={`${api}/api/news?q=all&limit=20&offset=0`} rel="nofollow" target="_blank">Ver todo (API)</a>
    </div>
  </div>

  <div id="news-list">
    {data.items?.length ? (
      data.items.map((n) => (
        <article class="card">
          <div class="muted" style="font-size:12px">
            <a href={n.source_url} rel="nofollow noopener noreferrer" target="_blank">{n.source_name}</a>
            {n.published_at ? ` · ${fmt(n.published_at)}` : ""}
          </div>

          <img
            src={n.image_url || "/img/colapinto.svg"}
            loading="lazy"
            decoding="async"
            alt={n.title}
            style="margin:10px 0;border-radius:14px;border:1px solid rgba(255,255,255,.10)"
          />

          <h3 style="margin:8px 0 6px">
            <a href={n.url} rel="nofollow noopener noreferrer" target="_blank">{n.title}</a>
          </h3>

          {n.snippet ? <p class="muted" style="margin:0 0 10px">{n.snippet}</p> : null}

          <div class="noteBox">
            <strong>Notas de la Redacción</strong>
            <div style="margin-top:6px">{n.auto_note}</div>
          </div>

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
    let offset = {limit};

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

      const img = document.createElement("img");
      img.src = n.image_url || "/img/colapinto.svg";
      img.loading = "lazy";
      img.decoding = "async";
      img.alt = n.title || "noticia";
      img.style.margin = "10px 0";
      img.style.borderRadius = "14px";
      img.style.border = "1px solid rgba(255,255,255,.10)";
      wrap.appendChild(img);

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

      const noteBox = document.createElement("div");
      noteBox.className = "noteBox";
      noteBox.innerHTML = `<strong>Notas de la Redacción</strong><div style="margin-top:6px">${esc(n.auto_note)}</div>`;
      wrap.appendChild(noteBox);

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

echo "==> 7) Sitemap actualizado (incluye /suscribirme y rutas ES)"
cat > web/src/pages/sitemap.xml.ts <<'TS'
export async function GET({ request }: { request: Request }) {
  const origin = new URL(request.url).origin;
  const api = (import.meta as any).env?.PUBLIC_API_BASE || "";

  const staticPaths = [
    "/", "/vivo", "/calendario/2026", "/noticias", "/tienda", "/suscribirme",
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

echo "==> 8) Ajustar links internos a nuevas rutas"
perl -pi -e '
  s#href="/alerts"#href="/suscribirme"#g;
  s#href="/avisos"#href="/suscribirme"#g;
  s#href="/merch"#href="/tienda"#g;
  s#href="/live"#href="/vivo"#g;
  s#href="/calendar/2026"#href="/calendario/2026"#g;
  s#href="/news"#href="/noticias"#g;
  s#/gp/#/gran-premio/#g;
' $(find web/src -name "*.astro" -type f) 2>/dev/null || true

echo ""
echo "OK: cambios aplicados en tu working tree."
echo "Siguiente: migraciones D1 + deploy worker + commit/push."
