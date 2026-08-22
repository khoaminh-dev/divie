create table if not exists public.divie_emergency_contacts (
  account_id uuid primary key references auth.users(id) on delete cascade,
  numbers text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint divie_emergency_contacts_max_five
    check (coalesce(array_length(numbers, 1), 0) <= 5)
);

create or replace function public.set_divie_emergency_contacts_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists divie_emergency_contacts_updated_at
  on public.divie_emergency_contacts;
create trigger divie_emergency_contacts_updated_at
before update on public.divie_emergency_contacts
for each row execute function public.set_divie_emergency_contacts_updated_at();

alter table public.divie_emergency_contacts enable row level security;
drop policy if exists divie_emergency_contacts_select_own
  on public.divie_emergency_contacts;
create policy divie_emergency_contacts_select_own
on public.divie_emergency_contacts for select
using (auth.uid() = account_id);

drop policy if exists divie_emergency_contacts_insert_own
  on public.divie_emergency_contacts;
create policy divie_emergency_contacts_insert_own
on public.divie_emergency_contacts for insert
with check (auth.uid() = account_id);

drop policy if exists divie_emergency_contacts_update_own
  on public.divie_emergency_contacts;
create policy divie_emergency_contacts_update_own
on public.divie_emergency_contacts for update
using (auth.uid() = account_id)
with check (auth.uid() = account_id);

drop policy if exists divie_emergency_contacts_delete_own
  on public.divie_emergency_contacts;
create policy divie_emergency_contacts_delete_own
on public.divie_emergency_contacts for delete
using (auth.uid() = account_id);

grant select, insert, update, delete on public.divie_emergency_contacts to authenticated;
