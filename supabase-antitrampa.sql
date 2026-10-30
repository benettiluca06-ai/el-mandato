-- El Mandato · Ranking a prueba de trampas
-- Pegá esto en Supabase → SQL Editor → New query → Run (una sola vez).
-- Desde ahora nadie puede escribir el ranking directo: solo a través de estas dos funciones,
-- que validan la partida en el servidor.

-- 1) Cada partida queda registrada en el servidor con su hora de inicio real
create table if not exists public.partidas (
  id      uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  inicio  timestamptz not null default now(),
  diario  boolean not null default false,
  usada   boolean not null default false
);
alter table public.partidas enable row level security;
-- (sin políticas: nadie la lee ni la escribe directo, solo las funciones de abajo)
create index if not exists partidas_user on public.partidas (user_id, inicio desc);

-- 2) Se cierra la escritura directa del ranking (la lectura sigue siendo pública)
drop policy if exists "cada uno crea su fila" on public.legados;
drop policy if exists "cada uno edita su fila" on public.legados;

-- 3) Empezar partida
create or replace function public.iniciar_partida(p_diario boolean default false)
returns json language plpgsql security definer set search_path = public as $$
declare v uuid; n int; d boolean := coalesce(p_diario, false);
begin
  if auth.uid() is null then raise exception 'sin sesion'; end if;
  select count(*) into n from partidas where user_id = auth.uid() and inicio > now() - interval '1 hour';
  if n >= 40 then raise exception 'demasiadas partidas'; end if;
  -- el desafío diario cuenta solo la PRIMERA partida que arrancás (no vale abandonar y reintentar)
  if d and exists (select 1 from partidas where user_id = auth.uid() and diario and inicio > now() - interval '20 hours') then
    d := false;
  end if;
  insert into partidas (user_id, diario) values (auth.uid(), d) returning id into v;
  return json_build_object('id', v, 'diario', d);
end $$;

-- 4) Mandar el legado al terminar
create or replace function public.enviar_legado(
  p_partida uuid, p_puntos int, p_turnos int, p_nombre text,
  p_titulo text, p_pais text, p_cargo text, p_fecha date)
returns text language plpgsql security definer set search_path = public as $$
declare pa partidas; cur legados; seg numeric; tope int; res text := 'igual'; nom text;
begin
  if auth.uid() is null then raise exception 'sin sesion'; end if;
  select * into pa from partidas where id = p_partida and user_id = auth.uid() for update;
  if not found then raise exception 'partida invalida'; end if;
  if pa.usada then raise exception 'partida ya enviada'; end if;
  if p_turnos is null or p_turnos < 1 or p_turnos > 40 then raise exception 'turnos invalidos'; end if;
  seg := extract(epoch from now() - pa.inicio);
  if seg < p_turnos * 4 then raise exception 'demasiado rapido'; end if;
  tope := p_turnos * 144 + 1100;  -- máximo teórico: 6 niveles x 24 pts por turno + finales y logros
  if p_puntos is null or p_puntos < 0 or p_puntos > tope then raise exception 'puntaje imposible'; end if;
  if p_fecha is null or abs(p_fecha - current_date) > 1 then raise exception 'fecha invalida'; end if;

  update partidas set usada = true where id = pa.id;
  nom := left(coalesce(nullif(trim(p_nombre), ''), 'Jugador'), 40);

  select * into cur from legados where user_id = auth.uid();
  if not found then
    insert into legados (user_id, nombre, puntos) values (auth.uid(), nom, 0) returning * into cur;
  end if;

  if p_puntos > cur.puntos then
    update legados set nombre = nom, puntos = p_puntos, titulo = left(p_titulo, 60), pais = left(p_pais, 4),
      cargo = left(p_cargo, 80), fecha = p_fecha, updated_at = now() where user_id = auth.uid();
    res := 'record';
  end if;

  if pa.diario and cur.diario_fecha is distinct from p_fecha then
    update legados set nombre = nom, diario_fecha = p_fecha, diario_puntos = p_puntos,
      diario_titulo = left(p_titulo, 60), diario_pais = left(p_pais, 4), updated_at = now()
      where user_id = auth.uid();
    res := res || '+diario';
  end if;
  return res;
end $$;

revoke all on function public.iniciar_partida(boolean) from public, anon;
revoke all on function public.enviar_legado(uuid, int, int, text, text, text, text, date) from public, anon;
grant execute on function public.iniciar_partida(boolean) to authenticated;
grant execute on function public.enviar_legado(uuid, int, int, text, text, text, text, date) to authenticated;
