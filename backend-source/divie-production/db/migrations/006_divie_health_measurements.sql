-- Persist confirmed blood-pressure OCR results for the signed-in account.
-- The production project already contains this table; this migration keeps
-- fresh environments reproducible and is safe to run more than once.

create table if not exists public.health_measurement_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  systolic_bp integer,
  diastolic_bp integer,
  heart_rate integer,
  source text not null default 'manual',
  raw_payload jsonb not null default '{}'::jsonb,
  measured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists health_measurement_sessions_user_measured_idx
  on public.health_measurement_sessions(user_id, measured_at desc);

alter table public.health_measurement_sessions enable row level security;

drop policy if exists "Users can insert own health measurements"
  on public.health_measurement_sessions;
create policy "Users can insert own health measurements"
  on public.health_measurement_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can read own health measurements"
  on public.health_measurement_sessions;
create policy "Users can read own health measurements"
  on public.health_measurement_sessions for select to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert on table public.health_measurement_sessions to authenticated;
