-- Pegá esto en Supabase → SQL Editor → New query → Run

create table if not exists public.legados (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  nombre        text not null default 'Jugador' check (char_length(nombre) <= 40),
  puntos        integer not null default 0 check (puntos between 0 and 20000),
  titulo        text,
  pais          text,
  cargo         text,
  fecha         date,
  diario_fecha  date,
  diario_puntos integer check (diario_puntos between 0 and 20000),
  diario_titulo text,
  diario_pais   text,
  updated_at    timestamptz not null default now()
);

alter table public.legados enable row level security;

-- Cualquiera puede ver el ranking
create policy "ranking publico" on public.legados
  for select using (true);

-- Cada jugador solo crea y edita su propia fila
create policy "cada uno crea su fila" on public.legados
  for insert with check (auth.uid() = user_id);

create policy "cada uno edita su fila" on public.legados
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists legados_puntos on public.legados (puntos desc);
create index if not exists legados_diario on public.legados (diario_fecha, diario_puntos desc);
