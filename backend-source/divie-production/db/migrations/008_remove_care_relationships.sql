-- A DiVie account can switch between the elder and family interfaces.
-- Roles change the experience on a device, not the ownership of data.

drop policy if exists divie_care_reminders_read on public.medicine_reminders;
drop policy if exists divie_care_reminders_write on public.medicine_reminders;
drop policy if exists divie_care_reminder_events_read on public.medicine_reminder_events;
drop policy if exists divie_care_reminder_events_write on public.medicine_reminder_events;
drop policy if exists divie_care_health_read on public.health_measurement_sessions;
drop policy if exists divie_care_health_insert on public.health_measurement_sessions;
drop policy if exists divie_care_emergency_contacts_read on public.divie_emergency_contacts;
drop policy if exists divie_care_emergency_contacts_write on public.divie_emergency_contacts;

drop policy if exists "Users can read own medicine reminders" on public.medicine_reminders;
create policy "Users can read own medicine reminders"
  on public.medicine_reminders for select to authenticated
  using ((select auth.uid()) = account_id);
drop policy if exists "Users can create own medicine reminders" on public.medicine_reminders;
create policy "Users can create own medicine reminders"
  on public.medicine_reminders for insert to authenticated
  with check ((select auth.uid()) = account_id);
drop policy if exists "Users can update own medicine reminders" on public.medicine_reminders;
create policy "Users can update own medicine reminders"
  on public.medicine_reminders for update to authenticated
  using ((select auth.uid()) = account_id)
  with check ((select auth.uid()) = account_id);
drop policy if exists "Users can delete own medicine reminders" on public.medicine_reminders;
create policy "Users can delete own medicine reminders"
  on public.medicine_reminders for delete to authenticated
  using ((select auth.uid()) = account_id);

drop policy if exists "Users can read own medicine reminder events" on public.medicine_reminder_events;
create policy "Users can read own medicine reminder events"
  on public.medicine_reminder_events for select to authenticated
  using ((select auth.uid()) = account_id);
drop policy if exists "Users can create own medicine reminder events" on public.medicine_reminder_events;
create policy "Users can create own medicine reminder events"
  on public.medicine_reminder_events for insert to authenticated
  with check (
    (select auth.uid()) = account_id
    and exists (
      select 1 from public.medicine_reminders
      where medicine_reminders.id = reminder_id
        and medicine_reminders.account_id = (select auth.uid())
    )
  );
drop policy if exists "Users can update own medicine reminder events" on public.medicine_reminder_events;
create policy "Users can update own medicine reminder events"
  on public.medicine_reminder_events for update to authenticated
  using ((select auth.uid()) = account_id)
  with check (
    (select auth.uid()) = account_id
    and exists (
      select 1 from public.medicine_reminders
      where medicine_reminders.id = reminder_id
        and medicine_reminders.account_id = (select auth.uid())
    )
  );
drop policy if exists "Users can delete own medicine reminder events" on public.medicine_reminder_events;
create policy "Users can delete own medicine reminder events"
  on public.medicine_reminder_events for delete to authenticated
  using ((select auth.uid()) = account_id);

drop policy if exists "Users can read own health measurements" on public.health_measurement_sessions;
create policy "Users can read own health measurements"
  on public.health_measurement_sessions for select to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists "Users can insert own health measurements" on public.health_measurement_sessions;
create policy "Users can insert own health measurements"
  on public.health_measurement_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists divie_emergency_contacts_select_own on public.divie_emergency_contacts;
create policy divie_emergency_contacts_select_own
  on public.divie_emergency_contacts for select
  using ((select auth.uid()) = account_id);
drop policy if exists divie_emergency_contacts_insert_own on public.divie_emergency_contacts;
create policy divie_emergency_contacts_insert_own
  on public.divie_emergency_contacts for insert
  with check ((select auth.uid()) = account_id);
drop policy if exists divie_emergency_contacts_update_own on public.divie_emergency_contacts;
create policy divie_emergency_contacts_update_own
  on public.divie_emergency_contacts for update
  using ((select auth.uid()) = account_id)
  with check ((select auth.uid()) = account_id);
drop policy if exists divie_emergency_contacts_delete_own on public.divie_emergency_contacts;
create policy divie_emergency_contacts_delete_own
  on public.divie_emergency_contacts for delete
  using ((select auth.uid()) = account_id);

drop function if exists public.list_divie_care_invitations();
drop function if exists public.list_divie_care_recipients();
drop function if exists public.respond_divie_care_connection(uuid, boolean);
drop function if exists public.request_divie_care_connection(text);
drop function if exists public.is_active_caregiver_for(uuid);
drop table if exists public.divie_care_relationships;
drop function if exists public.touch_divie_care_relationship_updated_at();
