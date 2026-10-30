// Configuración pública del sitio. Estas claves SON públicas por diseño:
// la seguridad la dan las reglas (RLS) de Supabase, no esconder la clave.
window.MANDATO_CONFIG = {
  // Supabase → Project Settings → API
  SUPABASE_URL: "https://ctwynirwoforcmswgfjt.supabase.co",        // ej: "https://abcdefgh.supabase.co"
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0d3luaXJ3b2ZvcmNtc3dnZmp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzMTMxNjcsImV4cCI6MjEwODg4OTE2N30.BrF9GxYe0CKgNwmPlTxj_lrrtRaOoWCIyJWGZ0irC8g",   // la clave "anon public"

  // Google AdSense (cuando te aprueben el sitio)
  ADSENSE_CLIENT: "",      // ej: "ca-pub-1234567890123456"
  ADSENSE_SLOTS: {         // un bloque de anuncios por lugar (AdSense → Anuncios → Por bloque)
    top: "",               // banner superior
    home: "",              // entre secciones del inicio
    sidebar: "",           // columna lateral del inicio
    game: "",              // debajo del cable durante la partida
    end: ""                // pantalla de legado
  }
};
