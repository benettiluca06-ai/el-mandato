// Feed de noticias internacionales en vivo (Vercel Serverless Function).
// Si hay GNEWS_API_KEY configurada usa GNews; si no, junta los titulares de los
// feeds RSS públicos de medios internacionales en español (titular + link al medio).
// La respuesta se cachea 20 minutos en el CDN de Vercel.
const FEEDS = [
  ["BBC Mundo", "https://feeds.bbci.co.uk/mundo/rss.xml"],
  ["France 24", "https://www.france24.com/es/rss"],
  ["DW", "https://rss.dw.com/xml/rss-sp-all"],
  ["El País", "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/section/internacional/portada"],
  ["Noticias ONU", "https://news.un.org/feed/subscribe/es/news/all/rss.xml"]
];

const limpiar = s => String(s || "")
  .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
  .replace(/<[^>]+>/g, "")
  .replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#0?39;|&apos;/g, "'")
  .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n))
  .replace(/\s+/g, " ").trim();

const tag = (xml, t) => { const m = xml.match(new RegExp("<" + t + "(?:\\s[^>]*)?>([\\s\\S]*?)</" + t + ">", "i")); return m ? limpiar(m[1]) : ""; };

async function leerFeed([fuente, url]) {
  const ctl = new AbortController(); const to = setTimeout(() => ctl.abort(), 4500);
  try {
    const r = await fetch(url, { signal: ctl.signal, headers: { "User-Agent": "ElMandato/1.0 (+https://elmandato.app)" } });
    if (!r.ok) return [];
    const xml = await r.text();
    return (xml.match(/<item[\s>][\s\S]*?<\/item>/gi) || []).slice(0, 8).map(it => {
      let link = tag(it, "link");
      if (!link) { const m = it.match(/<link[^>]*href="([^"]+)"/i); link = m ? m[1] : ""; }
      const fecha = tag(it, "pubDate") || tag(it, "dc:date");
      return { title: tag(it, "title"), url: link, source: fuente, publishedAt: fecha ? new Date(fecha).toISOString() : null };
    }).filter(x => x.title && /^https?:\/\//.test(x.url));
  } catch (e) { return []; } finally { clearTimeout(to); }
}

async function gnews(key) {
  const url = "https://gnews.io/api/v4/top-headlines?category=world&lang=es&max=10&apikey=" + encodeURIComponent(key);
  const r = await fetch(url);
  if (!r.ok) throw new Error("GNews respondió " + r.status);
  const j = await r.json();
  return (j.articles || []).map(a => ({ title: a.title, url: a.url, source: (a.source && a.source.name) || "", publishedAt: a.publishedAt }));
}

module.exports = async (req, res) => {
  try {
    let items = [];
    if (process.env.GNEWS_API_KEY) { try { items = await gnews(process.env.GNEWS_API_KEY); } catch (e) { items = []; } }
    if (!items.length) {
      const listas = await Promise.all(FEEDS.map(leerFeed));
      // intercalar fuentes para que no salgan todas del mismo medio
      const max = Math.max(0, ...listas.map(l => l.length));
      for (let i = 0; i < max; i++) for (const l of listas) if (l[i]) items.push(l[i]);
      const vistos = new Set();
      items = items.filter(x => { const k = x.title.toLowerCase(); if (vistos.has(k)) return false; vistos.add(k); return true; }).slice(0, 24);
    }
    if (!items.length) throw new Error("sin noticias");
    res.setHeader("Cache-Control", "s-maxage=1200, stale-while-revalidate=3600");
    res.status(200).json({ items });
  } catch (e) {
    res.setHeader("Cache-Control", "s-maxage=60");
    res.status(502).json({ error: String((e && e.message) || e) });
  }
};
