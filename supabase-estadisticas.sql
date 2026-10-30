-- El Mandato · Estadísticas propias del juego (anónimas)
-- Pegá esto en Supabase → SQL Editor → New query → Run (una sola vez).
-- Después mirás los resultados en Table Editor → embudo_diario y donde_abandonan.

create table if not exists public.eventos (
  id        bigserial primary key,
  creado    timestamptz not null default now(),
  tipo      text not null,
  sesion    text not null,
  visitante text not null,
  datos     jsonb not null default '{}'::jsonb
);
alter table public.eventos enable row level security;
-- (sin políticas: nadie la lee desde el sitio; solo vos desde el panel)
create index if not exists eventos_creado on public.eventos (creado desc);
create index if not exists eventos_tipo on public.eventos (tipo, creado desc);

create or replace function public.registrar_evento(
  p_tipo text, p_sesion text, p_visitante text, p_datos jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_tipo not in ('visita','setup','inicio','turno','eleccion','fin','practica','compartir') then return; end if;
  if p_sesion is null or p_visitante is null or length(p_sesion) > 40 or length(p_visitante) > 40 then return; end if;
  if pg_column_size(coalesce(p_datos, '{}'::jsonb)) > 2000 then return; end if;
  select count(*) into n from eventos where sesion = p_sesion and creado > now() - interval '1 day';
  if n >= 300 then return; end if;
  insert into eventos (tipo, sesion, visitante, datos) values (p_tipo, p_sesion, p_visitante, coalesce(p_datos, '{}'::jsonb));
end $$;

revoke all on function public.registrar_evento(text, text, text, jsonb) from public;
grant execute on function public.registrar_evento(text, text, text, jsonb) to anon, authenticated;

-- Resumen por día (hora de Argentina)
create or replace view public.embudo_diario with (security_invoker = true) as
select (creado at time zone 'America/Argentina/Buenos_Aires')::date as dia,
  count(distinct visitante) filter (where tipo = 'visita')                         as visitantes,
  count(distinct sesion)    filter (where tipo = 'setup')                          as abrieron_formulario,
  count(*)                  filter (where tipo = 'inicio')                         as partidas_empezadas,
  count(*)                  filter (where tipo = 'inicio' and datos->>'modo' = 'rapido') as con_jugar_ya,
  count(*)                  filter (where tipo = 'inicio' and datos->>'modo' = 'diario') as desafios_diarios,
  count(*)                  filter (where tipo = 'turno' and datos->>'n' = '5')    as llegaron_al_turno_5,
  count(*)                  filter (where tipo = 'eleccion')                       as jugaron_una_eleccion,
  count(*)                  filter (where tipo = 'fin')                            as carreras_terminadas,
  count(*)                  filter (where tipo = 'practica')                       as minijuegos_de_practica,
  count(*)                  filter (where tipo = 'compartir')                      as veces_compartido
from public.eventos group by 1 order by 1 desc;

-- Hasta dónde llega cada partida (para ver dónde se aburre la gente)
create or replace view public.donde_abandonan with (security_invoker = true) as
with p as (
  select datos->>'pid' as pid,
         max(case when tipo = 'fin' then 100 when tipo = 'turno' then (datos->>'n')::int else 1 end) as m
  from public.eventos where datos ? 'pid' group by 1
)
select case when m = 100 then '6 · terminó la carrera'
            when m >= 15 then '5 · turno 15 o más'
            when m >= 10 then '4 · turnos 10 a 14'
            when m >= 5  then '3 · turnos 5 a 9'
            when m >= 2  then '2 · turnos 2 a 4'
            else              '1 · se fue en el primer turno' end as etapa,
       count(*) as partidas
from p group by 1 order by 1;

revoke all on public.embudo_diario from anon, authenticated;
revoke all on public.donde_abandonan from anon, authenticated;
