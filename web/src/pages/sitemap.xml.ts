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
