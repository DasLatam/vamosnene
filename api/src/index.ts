import { XMLParser } from "fast-xml-parser";

export interface Env {
  DB: D1Database;
  OPENWEATHER_API_KEY?: string;
  OPENWEATHER_BASE?: string;
  ADMIN_KEY?: string;
  SITE_ORIGIN?: string;
  SENDER_EMAIL?: string;
  BREVO_API_KEY?: string;
}

type Json = Record<string, any>;

const UA =
  "VamosNeneBot/1.0 (+https://vamosnene.pages.dev) Cloudflare-Worker";

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "",
});

function json(data: any, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...(init.headers || {}),
    },
  });
}

function ok(data: any) {
  return json({ ok: true, ...data });
}

function bad(error: string, code = 400, extra: any = {}) {
  return json({ ok: false, error, ...extra }, { status: code });
}

function toIso(d: any) {
  try {
    const dt = new Date(d);
    return isNaN(dt.getTime()) ? null : dt.toISOString();
  } catch {
    return null;
  }
}

function stripHtml(input: string) {
  if (!input) return "";
  return input
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function fetchTextSmart(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { "user-agent": UA, accept: "text/html,application/xml,text/xml,*/*" },
  });
  const buf = await res.arrayBuffer();
  const ct = (res.headers.get("content-type") || "").toLowerCase();
  const m = ct.match(/charset=([^;]+)/i);
  const hinted = m?.[1]?.trim();

  const candidates = Array.from(
    new Set([hinted, "utf-8", "windows-1252", "iso-8859-1"].filter(Boolean) as string[])
  );

  for (const cs of candidates) {
    try {
      const dec = new TextDecoder(cs as any, { fatal: false });
      const txt = dec.decode(buf);
      // si no hay “�” o es utf-8, lo aceptamos
      if (!txt.includes("�") || cs === "utf-8") return txt;
    } catch {
      // sigue
    }
  }
  // fallback
  return new TextDecoder("utf-8").decode(buf);
}

async function fetchJson(url: string): Promise<any> {
  const res = await fetch(url, { headers: { "user-agent": UA, accept: "application/json" } });
  if (!res.ok) throw new Error(`fetchJson ${res.status} ${url}`);
  return res.json();
}

async function ensureSchema(db: D1Database) {
  // meta
  await db
    .prepare("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
    .run();

  // columns check for articles
  const cols = await db.prepare("PRAGMA table_info(articles)").all<any>();
  const names = new Set((cols.results || []).map((r: any) => r.name));

  if (!names.has("image_url")) {
    await db.prepare("ALTER TABLE articles ADD COLUMN image_url TEXT").run();
  }
  if (!names.has("lang")) {
    await db.prepare("ALTER TABLE articles ADD COLUMN lang TEXT").run();
  }
}

async function setMeta(db: D1Database, key: string, value: string) {
  await db.prepare("INSERT OR REPLACE INTO meta(key,value) VALUES (?1,?2)").bind(key, value).run();
}

async function getMeta(db: D1Database, key: string) {
  const r = await db.prepare("SELECT value FROM meta WHERE key=?1").bind(key).first<any>();
  return r?.value || null;
}

async function seedSources(db: D1Database) {
  // fuentes ES prioritarias + fallback EN
  const seeds = [
    {
      name: "F1Latam",
      url: "https://www.f1latam.com/",
      rss_url: "https://www.f1latam.com/rss/rss.php",
      lang: "es",
    },
    {
      name: "Motorsport LATAM (F1)",
      url: "https://lat.motorsport.com/f1/",
      rss_url: "https://lat.motorsport.com/rss/f1/news/",
      lang: "es",
    },
    {
      name: "Motorsport ES (F1)",
      url: "https://es.motorsport.com/f1/",
      rss_url: "https://es.motorsport.com/rss/f1/news/",
      lang: "es",
    },
    {
      name: "Motorsport (F1)",
      url: "https://www.motorsport.com/f1/",
      rss_url: "https://www.motorsport.com/rss/f1/news/",
      lang: "en",
    },
  ];

  for (const s of seeds) {
    await db
      .prepare(
        "INSERT OR IGNORE INTO news_sources(name,url,rss_url,is_active) VALUES (?1,?2,?3,1)"
      )
      .bind(s.name, s.url, s.rss_url)
      .run();
  }
}

function pickImageFromItem(item: any): string | null {
  // enclosure
  const enc = item?.enclosure;
  if (enc?.url) return String(enc.url);

  // media:content / media:thumbnail
  const mc = item?.["media:content"];
  if (mc) {
    if (Array.isArray(mc) && mc[0]?.url) return String(mc[0].url);
    if (mc.url) return String(mc.url);
  }
  const mt = item?.["media:thumbnail"];
  if (mt) {
    if (Array.isArray(mt) && mt[0]?.url) return String(mt[0].url);
    if (mt.url) return String(mt.url);
  }

  // html inside description/content
  const html = item?.["content:encoded"] || item?.description || "";
  const m = String(html).match(/<img[^>]+src=["']([^"']+)["']/i);
  if (m?.[1]) return m[1];

  return null;
}

async function fetchOgImage(url: string): Promise<string | null> {
  try {
    const html = await fetchTextSmart(url);
    const m =
      html.match(/property=["']og:image["'][^>]*content=["']([^"']+)["']/i) ||
      html.match(/content=["']([^"']+)["'][^>]*property=["']og:image["']/i);
    if (m?.[1]) return m[1];
  } catch {
    // ignore
  }
  return null;
}

function autoNote(title: string, snippet: string) {
  const t = (title || "").toLowerCase();
  const s = (snippet || "").toLowerCase();

  const bullets: string[] = [];
  if (t.includes("testing") || t.includes("pruebas") || s.includes("testing") || s.includes("pruebas")) {
    bullets.push("Separá ritmo real vs. simulación (carga/compuesto).");
    bullets.push("Buscá consistencia y confiabilidad, no un tiempo aislado.");
  }
  if (t.includes("qualifying") || t.includes("clasificación") || s.includes("qualifying")) {
    bullets.push("En quali importa: neumático, tráfico y evolución de pista.");
  }
  if (t.includes("race") || t.includes("carrera") || s.includes("race")) {
    bullets.push("Mirá degradación, estrategia y ventana de parada.");
  }
  if (t.includes("alpine") || s.includes("alpine")) {
    bullets.push("Clave Alpine: balance + tracción lenta + gestión de neumáticos.");
  }
  if (t.includes("colapinto") || s.includes("colapinto") || t.includes("franco")) {
    bullets.push("En clave argentina: compará contra referencia (Gasly) y contexto del stint.");
  }

  if (!bullets.length) {
    bullets.push("Leé el titular como señal, no como conclusión.");
    bullets.push("Buscá datos: stint, compuesto, tráfico y confiabilidad.");
  }

  return bullets.slice(0, 3).join(" ");
}

async function syncNews(env: Env) {
  const db = env.DB;
  await ensureSchema(db);
  await seedSources(db);

  const sources = await db
    .prepare("SELECT id,name,url,rss_url FROM news_sources WHERE is_active=1")
    .all<any>();

  const KEYWORDS = ["colapinto", "franco colapinto", "alpine", "43"];

  for (const src of sources.results || []) {
    const xml = await fetchTextSmart(src.rss_url);
    const parsed = parser.parse(xml);

    // RSS2: rss.channel.item
    const channel = parsed?.rss?.channel;
    const items = channel?.item
      ? Array.isArray(channel.item)
        ? channel.item
        : [channel.item]
      : [];

    // Atom: feed.entry
    const entries = parsed?.feed?.entry
      ? Array.isArray(parsed.feed.entry)
        ? parsed.feed.entry
        : [parsed.feed.entry]
      : [];

    const list = items.length ? items : entries;

    // Intentamos enriquecer imágenes (si faltan)
    for (let i = 0; i < Math.min(list.length, 30); i++) {
      const it = list[i];
      const title = stripHtml(it.title || it["title"] || "");
      const link = it.link?.href || it.link || it.guid || "";
      const pub = it.pubDate || it.published || it.updated || null;

      const descRaw = it.description || it.summary || it["content:encoded"] || "";
      const snippet = stripHtml(descRaw).slice(0, 220);

      const haystack = (title + " " + snippet).toLowerCase();
      const matches = KEYWORDS.some((k) => haystack.includes(k));

      // guardamos todo pero si only_colapinto, mostramos filtrado.
      const image1 = pickImageFromItem(it);
      let image = image1;

      if (!image && i < 8 && link) {
        image = await fetchOgImage(String(link));
      }

      const note = autoNote(title, snippet);

      // tags básicas
      const tags = haystack.includes("colapinto") ? "colapinto" : (haystack.includes("alpine") ? "alpine" : "");

      await db
        .prepare(
          `INSERT OR IGNORE INTO articles
            (source_id,title,url,snippet,published_at,tags,created_at,image_url,lang)
           VALUES
            (?1,?2,?3,?4,?5,?6,?7,?8,?9)`
        )
        .bind(
          src.id,
          title,
          String(link),
          snippet,
          toIso(pub) || new Date().toISOString(),
          tags,
          new Date().toISOString(),
          image || null,
          src.name.includes("ES") || src.name.includes("LATAM") || src.name.includes("F1Latam") ? "es" : "en"
        )
        .run();

      // auto_note en tabla separada? MVP: guardamos en snippet? mejor: columna no existe.
      // Para no tocar schema más, auto_note se recalcula al listar.
      // (igual, el frontend lo toma desde API)
      void matches;
    }
  }

  await setMeta(db, "news_last_sync", new Date().toISOString());
}

async function listNews(env: Env, req: Request) {
  const db = env.DB;
  await ensureSchema(db);

  const url = new URL(req.url);
  const q = (url.searchParams.get("q") || "").trim().toLowerCase();
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "12", 10) || 12, 50);
  const offset = Math.max(parseInt(url.searchParams.get("offset") || "0", 10) || 0, 0);
  const only = url.searchParams.get("only_colapinto") === "1";

  // WHERE
  const where: string[] = [];
  const binds: any[] = [];

  if (only) {
    where.push("(LOWER(title) LIKE ? OR LOWER(snippet) LIKE ? OR LOWER(tags) LIKE ?)");
    binds.push("%colapinto%", "%colapinto%", "%colapinto%");
  }

  if (q) {
    where.push("(LOWER(title) LIKE ? OR LOWER(snippet) LIKE ? OR LOWER(tags) LIKE ?)");
    binds.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }

  const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

  const totalR = await db
    .prepare(`SELECT COUNT(*) as c FROM articles ${whereSql}`)
    .bind(...binds)
    .first<any>();
  const total = totalR?.c || 0;

  const rows = await db
    .prepare(
      `SELECT a.id,a.title,a.url,a.snippet,a.published_at,a.tags,a.image_url,
              ns.name as source_name, ns.url as source_url
       FROM articles a
       JOIN news_sources ns ON ns.id=a.source_id
       ${whereSql}
       ORDER BY a.published_at DESC
       LIMIT ? OFFSET ?`
    )
    .bind(...binds, limit, offset)
    .all<any>();

  const items = (rows.results || []).map((r: any) => ({
    id: r.id,
    title: r.title,
    url: r.url,
    snippet: r.snippet,
    published_at: r.published_at,
    tags: r.tags,
    source_name: r.source_name,
    source_url: r.source_url,
    image_url: r.image_url,
    auto_note: autoNote(r.title, r.snippet),
  }));

  const last_sync = await getMeta(db, "news_last_sync");

  return json({
    ok: true,
    items,
    meta: { total, offset, limit, last_sync },
  });
}

// Calendar / events: usamos lo ya existente del starter (Ergast/Jolpica) y DB sessions/events.
async function syncCalendar(env: Env, season = 2026) {
  const db = env.DB;
  // Jolpica (Ergast replacement)
  const base = "https://api.jolpi.ca/ergast/f1";
  const r = await fetchJson(`${base}/${season}.json`);
  const races = r?.MRData?.RaceTable?.Races || [];

  // schema base (starter)
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      season INTEGER,
      round INTEGER,
      slug TEXT UNIQUE,
      name TEXT,
      circuit_name TEXT,
      locality TEXT,
      country TEXT,
      start_at TEXT,
      end_at TEXT,
      created_at TEXT
    )`
  ).run();

  await db.prepare(
    `CREATE TABLE IF NOT EXISTS sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER,
      name TEXT,
      start_at TEXT,
      end_at TEXT,
      created_at TEXT
    )`
  ).run();

  for (const race of races) {
    const round = parseInt(race.round, 10);
    const slug = String(race.raceName || race.raceName).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g,"") || `round-${round}`;
    const start = new Date(`${race.date}T${race.time || "00:00:00Z"}`);
    const end = new Date(start.getTime() + 3 * 60 * 60 * 1000);

    await db.prepare(
      `INSERT OR REPLACE INTO events(season,round,slug,name,circuit_name,locality,country,start_at,end_at,created_at)
       VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)`
    ).bind(
      season,
      round,
      slug,
      race.raceName,
      race.Circuit?.circuitName || "",
      race.Circuit?.Location?.locality || "",
      race.Circuit?.Location?.country || "",
      start.toISOString(),
      end.toISOString(),
      new Date().toISOString()
    ).run();

    // sessions: Practice/Quali/Race si existen
    const ev = await db.prepare("SELECT id FROM events WHERE slug=?1").bind(slug).first<any>();
    const eventId = ev?.id;
    if (!eventId) continue;

    await db.prepare("DELETE FROM sessions WHERE event_id=?1").bind(eventId).run();

    const add = async (name: string, date?: string, time?: string, durH = 1) => {
      if (!date) return;
      const st = new Date(`${date}T${time || "00:00:00Z"}`);
      const en = new Date(st.getTime() + durH * 60 * 60 * 1000);
      await db.prepare(
        `INSERT INTO sessions(event_id,name,start_at,end_at,created_at)
         VALUES (?1,?2,?3,?4,?5)`
      ).bind(eventId, name, st.toISOString(), en.toISOString(), new Date().toISOString()).run();
    };

    await add("Práctica 1", race.FirstPractice?.date, race.FirstPractice?.time, 1);
    await add("Práctica 2", race.SecondPractice?.date, race.SecondPractice?.time, 1);
    await add("Práctica 3", race.ThirdPractice?.date, race.ThirdPractice?.time, 1);
    await add("Clasificación", race.Qualifying?.date, race.Qualifying?.time, 1);
    await add("Carrera", race.date, race.time, 2);
  }

  await setMeta(db, "calendar_last_sync", new Date().toISOString());
}

async function syncWeather(env: Env) {
  const db = env.DB;
  const key = env.OPENWEATHER_API_KEY;
  if (!key) return;

  await db.prepare(
    `CREATE TABLE IF NOT EXISTS weather_cache(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      city TEXT,
      country TEXT,
      payload TEXT,
      updated_at TEXT
    )`
  ).run();

  const evs = await db.prepare("SELECT locality,country FROM events WHERE season=2026").all<any>();
  const seen = new Set<string>();

  const base = env.OPENWEATHER_BASE || "https://api.openweathermap.org/data/2.5";
  for (const e of evs.results || []) {
    const city = (e.locality || "").trim();
    const country = (e.country || "").trim();
    if (!city || !country) continue;
    const k = `${city}|${country}`.toLowerCase();
    if (seen.has(k)) continue;
    seen.add(k);

    try{
      const url = `${base}/forecast?q=${encodeURIComponent(city)},${encodeURIComponent(country)}&appid=${encodeURIComponent(key)}&units=metric&lang=es`;
      const payload = await fetchTextSmart(url);
      await db.prepare(
        "INSERT INTO weather_cache(city,country,payload,updated_at) VALUES (?1,?2,?3,?4)"
      ).bind(city, country, payload, new Date().toISOString()).run();
    }catch{
      // ignore
    }
  }

  await setMeta(db, "weather_last_sync", new Date().toISOString());
}

async function getWeatherFor(env: Env, city: string, country: string) {
  const db = env.DB;
  const r = await db.prepare(
    "SELECT payload,updated_at FROM weather_cache WHERE LOWER(city)=LOWER(?1) AND LOWER(country)=LOWER(?2) ORDER BY updated_at DESC LIMIT 1"
  ).bind(city, country).first<any>();

  if (!r?.payload) return null;

  try {
    const j = JSON.parse(r.payload);
    return { city: j?.city?.name || city, updated_at: r.updated_at, raw: j };
  } catch {
    return null;
  }
}

async function getGp(env: Env, slug: string) {
  const db = env.DB;
  const ev = await db.prepare("SELECT * FROM events WHERE slug=?1").bind(slug).first<any>();
  if (!ev) return null;

  const sess = await db.prepare("SELECT name,start_at,end_at FROM sessions WHERE event_id=?1 ORDER BY start_at ASC").bind(ev.id).all<any>();
  const weather = await getWeatherFor(env, ev.locality, ev.country);

  return {
    event: ev,
    sessions: (sess.results || []),
    weather,
  };
}

async function listEvents(env: Env, season = 2026) {
  const db = env.DB;
  const r = await db.prepare(
    "SELECT season,round,slug,name,circuit_name,locality,country,start_at,end_at FROM events WHERE season=?1 ORDER BY round ASC"
  ).bind(season).all<any>();
  return (r.results || []);
}

function computeStatus(nowMs: number, sessions: any[]) {
  const enriched = sessions.map((s) => {
    const st = Date.parse(s.start_at);
    const en = Date.parse(s.end_at);
    const live = st <= nowMs && nowMs <= en;
    const soon = nowMs < st && (st - nowMs) < 48 * 3600 * 1000;
    return { ...s, live, soon };
  });

  const liveOne = enriched.find((s) => s.live);
  if (liveOne) return { status: "live", sessions: enriched, next: liveOne };

  const next = enriched.find((s) => s.soon) || enriched.find((s) => Date.parse(s.start_at) > nowMs);
  if (next) return { status: "soon", sessions: enriched, next };

  return { status: "panel", sessions: enriched, next: null };
}

async function nowEndpoint(env: Env) {
  const db = env.DB;
  const evs = await listEvents(env, 2026);

  const nowMs = Date.now();
  // evento actual: el más cercano cuyo inicio ya pasó o está por venir
  let current = null;
  let bestDist = Infinity;

  for (const e of evs) {
    const st = Date.parse(e.start_at);
    const dist = Math.abs(st - nowMs);
    if (dist < bestDist) {
      bestDist = dist;
      current = e;
    }
  }

  let sessions: any[] = [];
  let next_session: any = null;
  let status = "panel";

  if (current) {
    const evDb = await db.prepare("SELECT id FROM events WHERE slug=?1").bind(current.slug).first<any>();
    if (evDb?.id) {
      const s = await db.prepare("SELECT name,start_at,end_at FROM sessions WHERE event_id=?1 ORDER BY start_at ASC").bind(evDb.id).all<any>();
      const calc = computeStatus(nowMs, s.results || []);
      status = calc.status;
      sessions = calc.sessions;
      next_session = calc.next;
    }
  }

  const weather = current ? await getWeatherFor(env, current.locality, current.country) : null;

  const last_sync = await getMeta(db, "calendar_last_sync");
  const news_last = await getMeta(db, "news_last_sync");
  const weather_last = await getMeta(db, "weather_last_sync");

  const where_to_watch = [
    "Streaming: Disney+ (según plan/disponibilidad)",
    "TV/cable: ESPN / Fox Sports (según operador)",
    "Operadores típicos: Flow, DirecTV, Telecentro, Movistar (puede variar)",
  ];

  return ok({
    status,
    current_event: current,
    sessions,
    next_session,
    weather,
    where_to_watch,
    meta: { last_sync: last_sync || news_last || weather_last || null },
  });
}

async function subscribe(env: Env, email: string) {
  const db = env.DB;
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS subscribers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE,
      locale TEXT,
      created_at TEXT
    )`
  ).run();

  await db.prepare(
    "INSERT OR IGNORE INTO subscribers(email,locale,created_at) VALUES (?1,'es-AR',?2)"
  ).bind(email, new Date().toISOString()).run();

  return ok({ subscribed: true });
}

async function replay(env: Env, req: Request) {
  const url = new URL(req.url);
  const driver = parseInt(url.searchParams.get("driver") || "43", 10);
  const windowSec = Math.min(parseInt(url.searchParams.get("window") || "25", 10) || 25, 60);

  // OpenF1: histórico gratis, realtime pago. :contentReference[oaicite:1]{index=1}
  try{
    // obtener sesión latest (puede fallar si es realtime)
    const sessions = await fetchJson("https://api.openf1.org/v1/sessions?meeting_key=latest");
    const s0 = Array.isArray(sessions) ? sessions[0] : null;
    const session_key = s0?.session_key;
    if(!session_key) return bad("no_session", 200, { note:"Sin sesión disponible para replay." });

    const to = new Date();
    const from = new Date(to.getTime() - windowSec * 1000);
    const locUrl =
      `https://api.openf1.org/v1/location?session_key=${encodeURIComponent(session_key)}&driver_number=${encodeURIComponent(driver)}&date>=${encodeURIComponent(from.toISOString())}`;

    const loc = await fetchJson(locUrl);
    if(!Array.isArray(loc) || !loc.length) return bad("no_points", 200, { note:"No llegaron puntos (quizá no hay histórico disponible ahora)." });

    // Normalizar x/y a [0..1]
    let minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity;
    for(const p of loc){
      minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
    }
    const dx = Math.max(1e-6, maxX - minX);
    const dy = Math.max(1e-6, maxY - minY);

    const points = loc.slice(-180).map((p:any)=>({
      x: (p.x - minX)/dx,
      y: (p.y - minY)/dy,
      t: p.date,
    }));

    return ok({ session_key, points });
  }catch(e:any){
    // si es realtime paywall u otro error
    return bad("replay_unavailable", 200, { note:"Replay no disponible ahora (puede requerir realtime pago o no hay datos históricos en este momento)." });
  }
}

async function syncAll(env: Env) {
  await ensureSchema(env.DB);
  await syncCalendar(env, 2026);
  await syncWeather(env);
  await syncNews(env);
}

export default {
  async fetch(req: Request, env: Env) {
    const url = new URL(req.url);

    // CORS simple
    if (req.method === "OPTIONS") {
      return new Response("", {
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET,POST,OPTIONS",
          "access-control-allow-headers": "content-type",
        },
      });
    }

    try {
      if (url.pathname === "/api/health") return ok({ ts: new Date().toISOString() });
      if (url.pathname === "/api/now") return nowEndpoint(env);
      if (url.pathname === "/api/news") return listNews(env, req);

      if (url.pathname === "/api/events") {
        const season = parseInt(url.searchParams.get("season") || "2026", 10);
        const items = await listEvents(env, season);
        return ok({ items });
      }

      if (url.pathname.startsWith("/api/gp/")) {
        const slug = url.pathname.split("/").pop() || "";
        const data = await getGp(env, slug);
        if (!data) return bad("not_found", 404);
        return ok(data);
      }

      if (url.pathname === "/api/subscribe" && req.method === "POST") {
        const body = (await req.json().catch(() => ({}))) as Json;
        const email = String(body.email || "").trim().toLowerCase();
        if (!email || !email.includes("@")) return bad("invalid_email");
        return subscribe(env, email);
      }

      if (url.pathname === "/api/replay") {
        return replay(env, req);
      }

      if (url.pathname === "/api/admin/sync") {
        const key = url.searchParams.get("key") || "";
        if (!env.ADMIN_KEY || key !== env.ADMIN_KEY) return bad("unauthorized", 401);
        await syncAll(env);
        return ok({ synced: true });
      }

      return bad("not_found", 404);
    } catch (e: any) {
      return bad("server_error", 500, { message: String(e?.message || e) });
    }
  },

  async scheduled(_event: ScheduledEvent, env: Env) {
    try {
      await syncAll(env);
    } catch {
      // ignore
    }
  },
};
