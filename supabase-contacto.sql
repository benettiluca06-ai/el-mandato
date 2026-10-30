-- El Mandato · Formulario de contacto
-- Pegá esto en Supabase → SQL Editor → New query → Run (una sola vez).
-- Los mensajes los leés en Supabase → Table Editor → mensajes.

create table if not exists public.mensajes (
  id        bigserial primary key,
  creado    timestamptz not null default now(),
  tipo      text not null,
  mensaje   text not null,
  contacto  text,
  user_id   uuid,
  pagina    text,
  agente    text,
  ip        text,
  leido     boolean not null default false
);
alter table public.mensajes enable row level security;
-- (sin políticas: nadie puede leerla desde el sitio; solo vos desde el panel)

create or replace function public.enviar_mensaje(
  p_tipo text, p_mensaje text, p_contacto text default null,
  p_pagina text default null, p_agente text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_ip text; n int;
begin
  if p_tipo not in ('sugerencia','bug','colaborar','publicidad','otro') then raise exception 'tipo invalido'; end if;
  if p_mensaje is null or char_length(trim(p_mensaje)) < 10 then raise exception 'mensaje corto'; end if;
  if char_length(p_mensaje) > 3000 then raise exception 'mensaje largo'; end if;
  begin
    v_ip := split_part(coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for', ''), ',', 1);
  exception when others then v_ip := null; end;
  select count(*) into n from mensajes where creado > now() - interval '1 hour'
    and ((v_ip is not null and v_ip <> '' and ip = v_ip) or (auth.uid() is not null and user_id = auth.uid()));
  if n >= 5 then raise exception 'demasiados mensajes'; end if;
  select count(*) into n from mensajes where creado > now() - interval '1 minute';
  if n >= 30 then raise exception 'demasiados mensajes'; end if;
  insert into mensajes (tipo, mensaje, contacto, user_id, pagina, agente, ip)
  values (p_tipo, trim(p_mensaje), left(nullif(trim(coalesce(p_contacto, '')), ''), 120), auth.uid(),
          left(p_pagina, 200), left(p_agente, 300), nullif(v_ip, ''));
end $$;

revoke all on function public.enviar_mensaje(text, text, text, text, text) from public;
grant execute on function public.enviar_mensaje(text, text, text, text, text) to anon, authenticated;
