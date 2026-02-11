-- Sessions (practice/quali/race + testing day blocks)
CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT NOT NULL UNIQUE,
  season INTEGER NOT NULL,
  round INTEGER,                    -- null for testing
  event_slug TEXT NOT NULL,
  event_name TEXT NOT NULL,
  session_name TEXT NOT NULL,
  session_type TEXT NOT NULL,       -- FP1/FP2/FP3/Q/R/S/TEST
  start_time TEXT NOT NULL,         -- ISO
  end_time TEXT NOT NULL,           -- ISO
  circuit_name TEXT,
  circuit_lat REAL,
  circuit_lon REAL,
  country TEXT,
  locality TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_time ON sessions(start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_sessions_event ON sessions(event_slug, session_type);

-- RSS sources
CREATE TABLE IF NOT EXISTS news_sources (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  site_url TEXT NOT NULL,
  rss_url TEXT NOT NULL
);

-- Articles ingested (title+link+snippet + auto note)
CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT NOT NULL UNIQUE,
  source_code TEXT NOT NULL,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  published_at TEXT,
  snippet TEXT,
  auto_note TEXT,
  tags TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (source_code) REFERENCES news_sources(code)
);

CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(published_at DESC);

-- Subscribers
CREATE TABLE IF NOT EXISTS subscribers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  locale TEXT NOT NULL DEFAULT 'es-AR',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_sent_at TEXT
);

-- Weather cache (per event)
CREATE TABLE IF NOT EXISTS weather_cache (
  event_slug TEXT PRIMARY KEY,
  fetched_at TEXT NOT NULL,
  payload TEXT NOT NULL
);
