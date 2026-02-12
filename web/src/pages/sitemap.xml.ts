export const prerender = true;

const pages = [
  "/", "/vivo", "/calendario/2026", "/noticias", "/suscribirme", "/tienda",
  "/about", "/contact", "/privacy", "/terms"
];

export async function GET() {
  const base = "https://vamosnene.pages.dev";
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${pages.map(p => `  <url><loc>${base}${p}</loc></url>`).join("\n")}
</urlset>`;
  return new Response(body, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
}
