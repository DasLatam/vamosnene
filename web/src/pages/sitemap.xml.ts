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
