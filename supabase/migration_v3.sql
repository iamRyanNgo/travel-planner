-- WhereToNext — v3 migration: split any expense + travelers privacy hardening
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; everything is idempotent)
-- Requires migration_v2.sql to have been run first.

-- ── Expense splitting on every cost source ────────────────────────
alter table wtn_flights add column if not exists paid_by    uuid references wtn_profiles(id);
alter table wtn_flights add column if not exists split_with uuid[];
alter table wtn_stays   add column if not exists paid_by    uuid references wtn_profiles(id);
alter table wtn_stays   add column if not exists split_with uuid[];
alter table wtn_events  add column if not exists paid_by    uuid references wtn_profiles(id);
alter table wtn_events  add column if not exists split_with uuid[];

-- ── Travelers: owner-only at the database level ───────────────────
-- Previously any trip member could read passport/visa rows through the
-- API even though the UI hid the tab. These policies enforce owner-only
-- access server-side, matching what the UI promises.
create or replace function wtn_is_owner(trip uuid) returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (select 1 from wtn_trips t where t.id = trip and t.owner_id = auth.uid())
$$;

drop policy if exists wtn_trav_r on wtn_travelers;
drop policy if exists wtn_trav_i on wtn_travelers;
drop policy if exists wtn_trav_u on wtn_travelers;
drop policy if exists wtn_trav_d on wtn_travelers;
create policy wtn_trav_r on wtn_travelers for select using      (wtn_is_owner(trip_id));
create policy wtn_trav_i on wtn_travelers for insert with check (wtn_is_owner(trip_id));
create policy wtn_trav_u on wtn_travelers for update using      (wtn_is_owner(trip_id));
create policy wtn_trav_d on wtn_travelers for delete using      (wtn_is_owner(trip_id));

-- ── Documents bucket: enforce the 10 MB cap server-side ───────────
-- (was only enforced in the client)
update storage.buckets set file_size_limit = 10485760 where id = 'wtn-docs';
