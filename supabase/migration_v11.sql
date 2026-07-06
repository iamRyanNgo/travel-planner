-- WhereToNext — v11 migration: approval enforcement + seed-data cleanup
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- Context: unapproved users could still CREATE their own trips (the
-- owner policy had no approval check), and the old in-app demo seed
-- let anyone build a copy of the Ryan & Joy wedding itinerary. The
-- seed has been removed from the app; this locks the database side
-- and removes copies that were already created.

-- ── Only approved users may create trips ──────────────────────────
create or replace function wtn_is_approved() returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (select 1 from wtn_profiles p where p.id = auth.uid() and p.approved)
$$;

drop policy if exists wtn_trips_owner on wtn_trips;
create policy wtn_trips_owner on wtn_trips
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and wtn_is_approved());

-- ── Cleanup: remove seeded wedding copies not owned by the admin ──
-- (cascades to their events/flights/stays/packing via FK)
delete from wtn_trips
where name = 'Ryan & Joy — Jeju Wedding 💒'
  and owner_id <> (select id from wtn_profiles where email = 'ryan.ngo94@gmail.com');
