# El Mandato · cómo ponerlo online

Simulador de carrera política. Este proyecto ya tiene:

- **Login con Google o con mail** (link mágico, sin contraseña) usando Supabase.
- **Ranking real**, histórico y del desafío diario, guardado en Supabase.
- **Feed de noticias internacionales en vivo** con la API de GNews, a través de una función en `api/news.js`.
- **Anuncios de Google AdSense** en 5 lugares: arriba, en el inicio, al costado, durante la partida y en el legado.
- Página de **privacidad**, que AdSense te pide, y el archivo `ads.txt`.

Todo es gratis para arrancar. Tardás aproximadamente una hora la primera vez.

---

## 1. Subí el código a GitHub
1. Creá una cuenta en github.com si no tenés.
2. Creá un repositorio nuevo, por ejemplo `el-mandato`.
3. Subí todos los archivos de esta carpeta con **Add file → Upload files**.

## 2. Publicalo en Vercel (esto te da el link para compartir)
1. Entrá a vercel.com con tu cuenta de GitHub.
2. **Add New → Project** e importá el repo `el-mandato`. No hace falta cambiar nada.
3. Tocá **Deploy**. Te da una dirección tipo `https://el-mandato.vercel.app`.
   **Ese es el link para compartir.**

## 3. Base de datos y login (Supabase)
1. Creá una cuenta en supabase.com y un proyecto nuevo (región: São Paulo).
2. **SQL Editor → New query**: pegá el contenido de `supabase.sql` y tocá **Run**.
3. **Authentication → URL Configuration**:
   - *Site URL*: tu link de Vercel.
   - *Redirect URLs*: agregá tu link de Vercel (y tu dominio propio si después tenés uno).
4. **Authentication → Providers → Email**: dejalo activado. Así funciona el login con mail.
5. **Authentication → Providers → Google**:
   1. En console.cloud.google.com creá un proyecto. Después andá a **APIs y servicios → Pantalla de consentimiento** y configurala como Externa.
   2. **Credenciales → Crear credenciales → ID de cliente de OAuth → Aplicación web**.
   3. En *URI de redireccionamiento autorizados* pegá la *Callback URL* que te muestra Supabase. Es del estilo `https://xxxx.supabase.co/auth/v1/callback`.
   4. Copiá el *Client ID* y el *Client Secret* en Supabase y activá Google.
6. **Project Settings → API**: copiá la *Project URL* y la clave *anon public*. Pegalas en `config.js`.

## 4. Noticias en vivo (GNews)
1. Creá una cuenta gratis en gnews.io y copiá tu API key.
2. En Vercel andá a tu proyecto → **Settings → Environment Variables**. Agregá `GNEWS_API_KEY` con tu clave.
3. **Deployments → Redeploy** para que tome la clave.

Mientras no esté configurada, el inicio muestra links a medios internacionales en lugar del feed.

## 5. Anuncios (Google AdSense)
1. Pedí la cuenta en adsense.google.com con tu link. Conviene usar un dominio propio, por ejemplo un `.com.ar` en nic.ar.
2. Cuando te den tu ID (`ca-pub-…`):
   - Ponelo en `ADSENSE_CLIENT` dentro de `config.js`.
   - En `ads.txt`, reemplazá `pub-0000000000000000` por tu ID. Sin `ca-`.
3. Esperá la aprobación. Puede tardar días o semanas, y necesitás algo de tráfico y contenido.
4. Creá 5 **bloques de anuncios** (Display, adaptables). Pegá cada número en `ADSENSE_SLOTS` de `config.js`.

Mientras no esté configurado, se ven los recuadros grises de "Publicidad".

## 6. Cada vez que cambies algo
Subí el archivo cambiado a GitHub y Vercel lo publica solo en un minuto.

---

### Cosas a tener en cuenta
- **Los puntajes se calculan en el navegador.** Alguien que sepa programar podría inventarse un puntaje. Para el arranque alcanza. Si el ranking se vuelve competitivo, el siguiente paso es calcular el puntaje en el servidor.
- En el ranking se muestra **el nombre del personaje**, nunca el mail del jugador.
- Completá tu mail de contacto en `privacidad.html`.
