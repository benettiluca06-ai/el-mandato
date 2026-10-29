// Feed de noticias internacionales en vivo (Vercel Serverless Function).
// Usa GNews (gnews.io). La clave queda en el servidor, en la variable GNEWS_API_KEY.
// La respuesta se cachea 30 minutos en el CDN de Vercel: con el plan gratis de GNews
// (100 pedidos por día) alcanza aunque entre mucha gente.
module.exports = async (req, res) => {
  const key = process.env.GNEWS_API_KEY;
  if (!key) {
    res.status(500).json({ error: "Falta configurar GNEWS_API_KEY en Vercel" });
    return;
  }
  try {
    const url = "https://gnews.io/api/v4/top-headlines?category=world&lang=es&max=10&apikey=" + encodeURIComponent(key);
    const r = await fetch(url);
    if (!r.ok) throw new Error("GNews respondió " + r.status);
    const j = await r.json();
    const items = (j.articles || []).map(a => ({
      title: a.title,
      url: a.url,
      source: (a.source && a.source.name) || "",
      publishedAt: a.publishedAt
    }));
    res.setHeader("Cache-Control", "s-maxage=1800, stale-while-revalidate=3600");
    res.status(200).json({ items });
  } catch (e) {
    res.setHeader("Cache-Control", "s-maxage=60");
    res.status(502).json({ error: String((e && e.message) || e) });
  }
};
