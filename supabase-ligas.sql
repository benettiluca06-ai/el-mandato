-- El Mandato · Rachas y ligas con amigos
-- Pegá esto en Supabase → SQL Editor → New query → Run (una sola vez).
-- Requiere haber corrido antes supabase.sql y supabase-antitrampa.sql.

-- 1) Racha de días jugando el desafío diario
alter table public.legados add column if not exists racha int not null default 0;
alter table public.legados add column if not exists racha_max int not null default 0;

-- enviar_legado ahora también lleva la racha
create or replace function public.enviar_legado(
  p_partida uuid, p_puntos int, p_turnos int, p_nombre text,
  p_titulo text, p_pais text, p_cargo text, p_fecha date)
returns text language plpgsql security definer set search_path = public as $$
declare pa partidas; cur legados; seg numeric; tope int; res text := 'igual'; nom text; r int;
begin
  if auth.uid() is null then raise exception 'sin sesion'; end if;
  select * into pa from partidas where id = p_partida and user_id = auth.uid() for update;
  if not found then raise exception 'partida invalida'; end if;
  if pa.usada then raise exception 'partida ya enviada'; end if;
  if p_turnos is null or p_turnos < 1 or p_turnos > 40 then raise exception 'turnos invalidos'; end if;
  seg := extract(epoch from now() - pa.inicio);
  if seg < p_turnos * 4 then raise exception 'demasiado rapido'; end if;
  tope := p_turnos * 144 + 1100;
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
    r := case when cur.diario_fecha = p_fecha - 1 then cur.racha + 1 else 1 end;
    update legados set nombre = nom, diario_fecha = p_fecha, diario_puntos = p_puntos,
      diario_titulo = left(p_titulo, 60), diario_pais = left(p_pais, 4),
      racha = r, racha_max = greatest(cur.racha_max, r), updated_at = now()
      where user_id = auth.uid();
    res := res || '+diario+racha' || r;
  end if;
  return res;
end $$;

-- 2) Ligas con amigos
create table if not exists public.ligas (
  id      uuid primary key default gen_random_uuid(),
  codigo  text unique not null,
  nombre  text not null check (char_length(nombre) between 3 and 40),
  owner   uuid not null references auth.users(id) on delete cascade,
  creada  timestamptz not null default now()
);
create table if not exists public.liga_miembros (
  liga_id uuid not null references public.ligas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  unido   timestamptz not null default now(),
  primary key (liga_id, user_id)
);
alter table public.ligas enable row level security;
alter table public.liga_miembros enable row level security;
-- (sin políticas: todo pasa por las funciones de abajo)

create or replace function public.crear_liga(p_nombre text)
returns json language plpgsql security definer set search_path = public as $$
declare v ligas; c text; n int; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i int;
begin
  if auth.uid() is null then raise exception 'sin sesion'; end if;
  if p_nombre is null or char_length(trim(p_nombre)) < 3 then raise exception 'nombre corto'; end if;
  select count(*) into n from ligas where owner = auth.uid();
  if n >= 5 then raise exception 'maximo de ligas'; end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(abc, 1 + floor(random() * length(abc))::int, 1); end loop;
    exit when not exists (select 1 from ligas where codigo = c);
  end loop;
  insert into ligas (codigo, nombre, owner) values (c, left(trim(p_nombre), 40), auth.uid()) returning * into v;
  insert into liga_miembros (liga_id, user_id) values (v.id, auth.uid());
  return json_build_object('id', v.id, 'codigo', v.codigo, 'nombre', v.nombre);
end $$;

create or replace function public.unirse_liga(p_codigo text)
returns json language plpgsql security definer set search_path = public as $$
declare v ligas; n int;
begin
  if auth.uid() is null then raise exception 'sin sesion'; end if;
  select * into v from ligas where codigo = upper(trim(p_codigo));
  if not found then raise exception 'codigo inexistente'; end if;
  select count(*) into n from liga_miembros where liga_id = v.id;
  if n >= 300 then raise exception 'liga llena'; end if;
  select count(*) into n from liga_miembros where user_id = auth.uid();
  if n >= 15 then raise exception 'demasiadas ligas'; end if;
  insert into liga_miembros (liga_id, user_id) values (v.id, auth.uid()) on conflict do nothing;
  return json_build_object('id', v.id, 'codigo', v.codigo, 'nombre', v.nombre);
end $$;

create or replace function public.salir_liga(p_liga uuid)
returns void language sql security definer set search_path = public as $$
  delete from liga_miembros where liga_id = p_liga and user_id = auth.uid();
$$;

create or replace function public.mis_ligas()
returns table (id uuid, nombre text, codigo text, miembros bigint)
language sql security definer set search_path = public stable as $$
  select l.id, l.nombre, l.codigo, (select count(*) from liga_miembros m2 where m2.liga_id = l.id)
  from ligas l join liga_miembros m on m.liga_id = l.id
  where m.user_id = auth.uid() order by m.unido;
$$;

create or replace function public.ranking_liga(p_liga uuid, p_hoy date default null)
returns table (nombre text, puntos int, titulo text, pais text, racha int, es_yo boolean)
language plpgsql security definer set search_path = public stable as $$
begin
  if not exists (select 1 from liga_miembros where liga_id = p_liga and user_id = auth.uid()) then
    raise exception 'no sos de esta liga';
  end if;
  if p_hoy is null then
    return query select g.nombre, g.puntos, g.titulo, g.pais,
      case when g.diario_fecha >= current_date - 1 then g.racha else 0 end, g.user_id = auth.uid()
      from legados g join liga_miembros m on m.user_id = g.user_id
      where m.liga_id = p_liga order by g.puntos desc limit 50;
  else
    return query select g.nombre, g.diario_puntos, g.diario_titulo, g.diario_pais,
      g.racha, g.user_id = auth.uid()
      from legados g join liga_miembros m on m.user_id = g.user_id
      where m.liga_id = p_liga and g.diario_fecha = p_hoy order by g.diario_puntos desc limit 50;
  end if;
end $$;

revoke all on function public.crear_liga(text) from public, anon;
revoke all on function public.unirse_liga(text) from public, anon;
revoke all on function public.salir_liga(uuid) from public, anon;
revoke all on function public.mis_ligas() from public, anon;
revoke all on function public.ranking_liga(uuid, date) from public, anon;
grant execute on function public.crear_liga(text) to authenticated;
grant execute on function public.unirse_liga(text) to authenticated;
grant execute on function public.salir_liga(uuid) to authenticated;
grant execute on function public.mis_ligas() to authenticated;
grant execute on function public.ranking_liga(uuid, date) to authenticated;
