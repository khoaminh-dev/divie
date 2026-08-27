-- Store a readable relationship/name alongside each emergency phone number.
-- Keep `numbers` in sync so older installed DiVie versions remain usable.

alter table public.divie_emergency_contacts
  add column if not exists contacts jsonb not null default '[]'::jsonb;

alter table public.divie_emergency_contacts
  drop constraint if exists divie_emergency_contacts_contacts_array;
alter table public.divie_emergency_contacts
  add constraint divie_emergency_contacts_contacts_array
  check (
    jsonb_typeof(contacts) = 'array'
    and jsonb_array_length(contacts) <= 5
  );

-- Preserve every existing emergency number. Old rows simply have an empty
-- name until the account holder adds one in the app.
update public.divie_emergency_contacts
set contacts = coalesce(
  (
    select jsonb_agg(
      jsonb_build_object('name', '', 'phone', btrim(number))
    )
    from unnest(numbers) as number
    where btrim(number) <> ''
  ),
  '[]'::jsonb
)
where contacts = '[]'::jsonb and coalesce(array_length(numbers, 1), 0) > 0;
