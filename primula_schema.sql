-- ============================================================
-- Prímula ERP — Schema completo
-- PASO 1: Pegar esto en Supabase → SQL Editor → New query → Run
-- PASO 2: Ir a Authentication → Users → Add user (crear tu usuario)
-- PASO 3: Pegar el archivo primula_seed_movimientos.sql y correrlo
-- ============================================================

-- ── PROFILES (vinculado a Auth de Supabase) ──────────────────
create table if not exists profiles (
  id        uuid references auth.users(id) on delete cascade primary key,
  email     text,
  nombre    text not null default '',
  rol       text not null default 'produccion',
  activo    boolean not null default true,
  created_at timestamptz default now()
);
alter table profiles enable row level security;
drop policy if exists "usuarios ven su propio perfil" on profiles;
drop policy if exists "admin ve todos los perfiles"   on profiles;
create policy "usuarios ven su propio perfil"
  on profiles for select to authenticated
  using (auth.uid() = id);
create policy "admin ve todos los perfiles"
  on profiles for all to authenticated
  using (true) with check (true);

-- Trigger: crea perfil automáticamente al registrar usuario
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, nombre, rol)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'rol', 'produccion')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── MOVIMIENTOS (finanzas) ────────────────────────────────────
create table if not exists movimientos (
  id        bigserial primary key,
  caja      text not null default 'EFECTIVO',
  anio      integer not null default 2026,
  mes       text not null default '',
  sem       integer not null default 0,
  fecha     date,
  concepto  text not null default '',
  detalle   text not null default '',
  ingreso   numeric not null default 0,
  egreso    numeric not null default 0,
  referencia text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table movimientos enable row level security;
drop policy if exists "auth users movimientos" on movimientos;
create policy "auth users movimientos"
  on movimientos for all to authenticated using (true) with check (true);

-- ── COBROS SAN MARCOS (local Monte Grande) ────────────────────
create table if not exists sm_cobros (
  id         bigserial primary key,
  venta_id   text not null,
  fecha      date not null default current_date,
  monto      numeric not null default 0,
  medio      text not null default 'efectivo',
  nota       text,
  created_at timestamptz default now()
);
alter table sm_cobros enable row level security;
drop policy if exists "auth users sm_cobros" on sm_cobros;
create policy "auth users sm_cobros"
  on sm_cobros for all to authenticated using (true) with check (true);

-- ── ÍNDICES para performance ──────────────────────────────────
create index if not exists idx_movimientos_anio  on movimientos(anio);
create index if not exists idx_movimientos_caja  on movimientos(caja);
create index if not exists idx_movimientos_fecha on movimientos(fecha);

-- ============================================================
-- ✅ Schema listo. Ahora:
--  1. Ve a Authentication → Users → Add user
--     Email: juanalonso.6a@gmail.com
--     Password: (la que quieras)
--  2. Corre el archivo primula_seed_movimientos.sql para cargar los datos
-- ============================================================
