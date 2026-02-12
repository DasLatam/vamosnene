export async function GET({ request }: { request: Request }) {
  const origin = new URL(request.url).origin;
  const urls = [
    "/",
    "/vivo",
    "/noticias",
    "/calendario/2026",
    "/tienda",
    "/suscribirme",
    "/about",
    "/contact",
    "/privacy",
    "/terms",
    "/gran-premio/bahrain",
  ];

  const now = new Date().toISOString();
  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
    urls.map((p) =>
      `  <url><loc>${origin}${p}</loc><lastmod>${now}</lastmod><changefreq>daily</changefreq></url>`
    ).join("\n") +
    `\n</urlset>\n`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "public, max-age=600",
    },
  });
}
