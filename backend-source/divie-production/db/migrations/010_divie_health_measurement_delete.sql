-- Let a signed-in account remove an OCR result that was read incorrectly.
-- Confirmed readings remain private to the account through RLS.

drop policy if exists "Users can delete own health measurements"
  on public.health_measurement_sessions;
create policy "Users can delete own health measurements"
  on public.health_measurement_sessions for delete to authenticated
  using ((select auth.uid()) = user_id);

grant delete on table public.health_measurement_sessions to authenticated;
