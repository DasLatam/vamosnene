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
