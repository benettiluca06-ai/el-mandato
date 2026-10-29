// Configuración pública del sitio. Estas claves SON públicas por diseño:
// la seguridad la dan las reglas (RLS) de Supabase, no esconder la clave.
window.MANDATO_CONFIG = {
  // Supabase → Project Settings → API
  SUPABASE_URL: "",        // ej: "https://abcdefgh.supabase.co"
  SUPABASE_ANON_KEY: "",   // la clave "anon public"

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
