-- Track the device-local role for the shared DiVie account.
-- The medicine schedule remains account-scoped so both devices see the same data.

create table if not exists public.divie_account_devices (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (length(trim(device_id)) between 1 and 180),
  role text not null default 'elder' check (role in ('elder', 'caregiver')),
  platform text not null default 'android' check (platform in ('android', 'ios', 'web')),
  push_token text,
  app_version text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, device_id)
);

create index if not exists divie_account_devices_account_active_idx
  on public.divie_account_devices(account_id, is_active);

alter table public.divie_account_devices enable row level security;

drop policy if exists "Users can read own DiVie devices" on public.divie_account_devices;
create policy "Users can read own DiVie devices"
  on public.divie_account_devices for select to authenticated
  using ((select auth.uid()) = account_id);

drop policy if exists "Users can register own DiVie devices" on public.divie_account_devices;
create policy "Users can register own DiVie devices"
  on public.divie_account_devices for insert to authenticated
  with check ((select auth.uid()) = account_id);

drop policy if exists "Users can update own DiVie devices" on public.divie_account_devices;
create policy "Users can update own DiVie devices"
  on public.divie_account_devices for update to authenticated
  using ((select auth.uid()) = account_id)
  with check ((select auth.uid()) = account_id);

drop policy if exists "Users can remove own DiVie devices" on public.divie_account_devices;
create policy "Users can remove own DiVie devices"
  on public.divie_account_devices for delete to authenticated
  using ((select auth.uid()) = account_id);

create or replace function public.touch_divie_account_device_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  new.last_seen_at = now();
  return new;
end;
$$;

drop trigger if exists divie_account_devices_touch_updated_at on public.divie_account_devices;
create trigger divie_account_devices_touch_updated_at
before update on public.divie_account_devices
for each row execute function public.touch_divie_account_device_updated_at();

grant select, insert, update, delete on table public.divie_account_devices to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.medicine_reminders;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.medicine_reminder_events;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.divie_account_devices;
exception when duplicate_object then null;
end $$;
