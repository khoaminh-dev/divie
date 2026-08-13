-- Keep reminder events bound to reminders owned by the same account.
-- This protects the shared-account model at the database boundary.

create index if not exists medicine_reminder_events_reminder_id_idx
  on public.medicine_reminder_events(reminder_id);

drop policy if exists "Users can create own medicine reminder events"
  on public.medicine_reminder_events;
create policy "Users can create own medicine reminder events"
  on public.medicine_reminder_events for insert to authenticated
  with check (
    (select auth.uid()) = account_id
    and exists (
      select 1
      from public.medicine_reminders
      where medicine_reminders.id = reminder_id
        and medicine_reminders.account_id = (select auth.uid())
    )
  );

drop policy if exists "Users can update own medicine reminder events"
  on public.medicine_reminder_events;
create policy "Users can update own medicine reminder events"
  on public.medicine_reminder_events for update to authenticated
  using ((select auth.uid()) = account_id)
  with check (
    (select auth.uid()) = account_id
    and exists (
      select 1
      from public.medicine_reminders
      where medicine_reminders.id = reminder_id
        and medicine_reminders.account_id = (select auth.uid())
    )
  );
