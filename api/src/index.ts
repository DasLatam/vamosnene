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
