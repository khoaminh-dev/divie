-- Connect a caregiver account to an elder account without sharing passwords.
-- The elder must explicitly accept before their health and reminder data is
-- visible to the caregiver.

create table if not exists public.divie_care_relationships (
  id uuid primary key default gen_random_uuid(),
  caregiver_id uuid not null references auth.users(id) on delete cascade,
  elder_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'declined', 'revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (caregiver_id, elder_id),
  check (caregiver_id <> elder_id)
);

create index if not exists divie_care_relationships_caregiver_status_idx
  on public.divie_care_relationships(caregiver_id, status);
create index if not exists divie_care_relationships_elder_status_idx
  on public.divie_care_relationships(elder_id, status);

create or replace function public.touch_divie_care_relationship_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists divie_care_relationships_touch_updated_at
  on public.divie_care_relationships;
create trigger divie_care_relationships_touch_updated_at
before update on public.divie_care_relationships
for each row execute function public.touch_divie_care_relationship_updated_at();

alter table public.divie_care_relationships enable row level security;

drop policy if exists divie_care_relationships_participants_read
  on public.divie_care_relationships;
create policy divie_care_relationships_participants_read
on public.divie_care_relationships for select to authenticated
using ((select auth.uid()) in (caregiver_id, elder_id));

-- Requests and responses go through SECURITY DEFINER functions below. Direct
-- writes are deliberately not granted to the app role.
revoke insert, update, delete on public.divie_care_relationships from authenticated;
grant select on public.divie_care_relationships to authenticated;

create or replace function public.is_active_caregiver_for(target_elder_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.divie_care_relationships
    where caregiver_id = (select auth.uid())
      and elder_id = target_elder_id
      and status = 'active'
  );
$$;

grant execute on function public.is_active_caregiver_for(uuid) to authenticated;

create or replace function public.request_divie_care_connection(target_phone text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_elder_id uuid;
  relationship_id uuid;
  normalized_phone text := regexp_replace(coalesce(target_phone, ''), '\D', '', 'g');
begin
  if normalized_phone like '84%' and length(normalized_phone) = 11 then
    normalized_phone := '0' || substring(normalized_phone from 3);
  end if;

  if normalized_phone !~ '^0(?:3|5|7|8|9)[0-9]{8}$' then
    raise exception 'invalid_phone';
  end if;

  select id into target_elder_id
  from public.profiles
  where phone_number = normalized_phone
  limit 1;

  if target_elder_id is null then
    raise exception 'profile_not_found';
  end if;
  if target_elder_id = (select auth.uid()) then
    raise exception 'cannot_connect_self';
  end if;

  insert into public.divie_care_relationships (caregiver_id, elder_id, status)
  values ((select auth.uid()), target_elder_id, 'pending')
  on conflict (caregiver_id, elder_id) do update
  set status = case
    when public.divie_care_relationships.status in ('declined', 'revoked') then 'pending'
    else public.divie_care_relationships.status
  end,
  updated_at = now()
  returning id into relationship_id;

  return relationship_id;
end;
$$;

grant execute on function public.request_divie_care_connection(text) to authenticated;

create or replace function public.respond_divie_care_connection(
  relationship_id uuid,
  accept_request boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.divie_care_relationships
  set status = case when accept_request then 'active' else 'declined' end,
      updated_at = now()
  where id = relationship_id
    and elder_id = (select auth.uid())
    and status = 'pending';

  if not found then
    raise exception 'care_request_not_found';
  end if;
end;
$$;

grant execute on function public.respond_divie_care_connection(uuid, boolean) to authenticated;

create or replace function public.list_divie_care_recipients()
returns table (
  relationship_id uuid,
  elder_id uuid,
  full_name text,
  phone_number text
)
language sql
stable
security definer
set search_path = public
as $$
  select relationship.id, relationship.elder_id, profile.full_name, profile.phone_number
  from public.divie_care_relationships relationship
  left join public.profiles profile on profile.id = relationship.elder_id
  where relationship.caregiver_id = (select auth.uid())
    and relationship.status = 'active'
  order by relationship.created_at;
$$;

grant execute on function public.list_divie_care_recipients() to authenticated;

create or replace function public.list_divie_care_invitations()
returns table (
  relationship_id uuid,
  caregiver_id uuid,
  full_name text,
  phone_number text
)
language sql
stable
security definer
set search_path = public
as $$
  select relationship.id, relationship.caregiver_id, profile.full_name, profile.phone_number
  from public.divie_care_relationships relationship
  left join public.profiles profile on profile.id = relationship.caregiver_id
  where relationship.elder_id = (select auth.uid())
    and relationship.status = 'pending'
  order by relationship.created_at desc;
$$;

grant execute on function public.list_divie_care_invitations() to authenticated;

-- An accepted caregiver may read and manage the elder's care records. The
-- account owner keeps the same access as before.
drop policy if exists "Users can read own medicine reminders" on public.medicine_reminders;
drop policy if exists "Users can create own medicine reminders" on public.medicine_reminders;
drop policy if exists "Users can update own medicine reminders" on public.medicine_reminders;
drop policy if exists "Users can delete own medicine reminders" on public.medicine_reminders;
create policy divie_care_reminders_read
on public.medicine_reminders for select to authenticated
using ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id));
create policy divie_care_reminders_write
on public.medicine_reminders for all to authenticated
using ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id))
with check ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id));

drop policy if exists "Users can read own medicine reminder events" on public.medicine_reminder_events;
drop policy if exists "Users can create own medicine reminder events" on public.medicine_reminder_events;
drop policy if exists "Users can update own medicine reminder events" on public.medicine_reminder_events;
drop policy if exists "Users can delete own medicine reminder events" on public.medicine_reminder_events;
create policy divie_care_reminder_events_read
on public.medicine_reminder_events for select to authenticated
using ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id));
create policy divie_care_reminder_events_write
on public.medicine_reminder_events for all to authenticated
using ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id))
with check (
  ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id))
  and exists (
    select 1 from public.medicine_reminders
    where medicine_reminders.id = reminder_id
      and medicine_reminders.account_id = account_id
  )
);

drop policy if exists "Users can read own health measurements" on public.health_measurement_sessions;
drop policy if exists "Users can insert own health measurements" on public.health_measurement_sessions;
create policy divie_care_health_read
on public.health_measurement_sessions for select to authenticated
using ((select auth.uid()) = user_id or public.is_active_caregiver_for(user_id));
create policy divie_care_health_insert
on public.health_measurement_sessions for insert to authenticated
with check ((select auth.uid()) = user_id or public.is_active_caregiver_for(user_id));

drop policy if exists divie_emergency_contacts_select_own on public.divie_emergency_contacts;
drop policy if exists divie_emergency_contacts_insert_own on public.divie_emergency_contacts;
drop policy if exists divie_emergency_contacts_update_own on public.divie_emergency_contacts;
drop policy if exists divie_emergency_contacts_delete_own on public.divie_emergency_contacts;
create policy divie_care_emergency_contacts_read
on public.divie_emergency_contacts for select to authenticated
using ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id));
create policy divie_care_emergency_contacts_write
on public.divie_emergency_contacts for all to authenticated
using ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id))
with check ((select auth.uid()) = account_id or public.is_active_caregiver_for(account_id));
