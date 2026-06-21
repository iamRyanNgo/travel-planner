-- ════════════════════════════════════════════════════════════════════
-- WhereToNext — Complete policy reset (all table data is preserved)
-- Run in: Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════════

-- ── 1. Drop every policy by name across all runs ─────────────────

drop policy if exists wtn_profiles_self           on wtn_profiles;
drop policy if exists wtn_profiles_admin_select   on wtn_profiles;
drop policy if exists wtn_profiles_admin_update   on wtn_profiles;
drop policy if exists wtn_profiles_admin          on wtn_profiles;
drop policy if exists wtn_profiles_admin_read     on wtn_profiles;
drop policy if exists wtn_profiles_admin_write    on wtn_profiles;
drop policy if exists wtn_profiles_member_read    on wtn_profiles;

drop policy if exists wtn_req_self   on wtn_access_requests;
drop policy if exists wtn_req_admin  on wtn_access_requests;

drop policy if exists wtn_trips_owner         on wtn_trips;
drop policy if exists wtn_trips_member_read   on wtn_trips;
drop policy if exists wtn_trips_editor_update on wtn_trips;

drop policy if exists wtn_members_owner on wtn_trip_members;
drop policy if exists wtn_members_read  on wtn_trip_members;
drop policy if exists wtn_members_self  on wtn_trip_members;

drop policy if exists wtn_events_r  on wtn_events;
drop policy if exists wtn_events_i  on wtn_events;
drop policy if exists wtn_events_u  on wtn_events;
drop policy if exists wtn_events_d  on wtn_events;

drop policy if exists wtn_flights_r on wtn_flights;
drop policy if exists wtn_flights_i on wtn_flights;
drop policy if exists wtn_flights_u on wtn_flights;
drop policy if exists wtn_flights_d on wtn_flights;

drop policy if exists wtn_stays_r on wtn_stays;
drop policy if exists wtn_stays_i on wtn_stays;
drop policy if exists wtn_stays_u on wtn_stays;
drop policy if exists wtn_stays_d on wtn_stays;

drop policy if exists wtn_pack_r on wtn_pack_items;
drop policy if exists wtn_pack_i on wtn_pack_items;
drop policy if exists wtn_pack_u on wtn_pack_items;
drop policy if exists wtn_pack_d on wtn_pack_items;

drop policy if exists wtn_budget_r on wtn_budget_items;
drop policy if exists wtn_budget_i on wtn_budget_items;
drop policy if exists wtn_budget_u on wtn_budget_items;
drop policy if exists wtn_budget_d on wtn_budget_items;

-- ── 2. Recreate helper functions ──────────────────────────────────
-- SECURITY DEFINER + search_path means these run as the postgres
-- superuser and bypass RLS, so they can safely read wtn_trips and
-- wtn_trip_members without triggering the policies on those tables.

create or replace function wtn_can_read(trip uuid) returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from wtn_trips t where t.id = trip and (
      t.owner_id = auth.uid() or
      exists (
        select 1 from wtn_trip_members m
        where m.trip_id = t.id and m.user_id = auth.uid()
      )
    )
  )
$$;

create or replace function wtn_can_write(trip uuid) returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from wtn_trips t where t.id = trip and (
      t.owner_id = auth.uid() or
      exists (
        select 1 from wtn_trip_members m
        where m.trip_id = t.id and m.user_id = auth.uid() and m.role = 'editor'
      )
    )
  )
$$;

-- ── 3. Recreate all policies ──────────────────────────────────────
--
-- Admin checks use (auth.jwt() ->> 'email') — reads from the JWT
-- token in memory, never queries wtn_profiles, zero recursion risk.
--
-- Cross-table checks use wtn_can_read/wtn_can_write (SECURITY DEFINER)
-- so they bypass RLS when reading wtn_trips/wtn_trip_members.

-- wtn_profiles
create policy wtn_profiles_self on wtn_profiles
  for all
  using (id = auth.uid())
  with check (id = auth.uid());

create policy wtn_profiles_admin_select on wtn_profiles
  for select
  using ((auth.jwt() ->> 'email') = 'ryan.ngo94@gmail.com');

create policy wtn_profiles_admin_update on wtn_profiles
  for update
  using ((auth.jwt() ->> 'email') = 'ryan.ngo94@gmail.com');

-- wtn_access_requests
create policy wtn_req_self on wtn_access_requests
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy wtn_req_admin on wtn_access_requests
  for all
  using ((auth.jwt() ->> 'email') = 'ryan.ngo94@gmail.com');

-- wtn_trips
create policy wtn_trips_owner on wtn_trips
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy wtn_trips_member_read on wtn_trips
  for select
  using (wtn_can_read(id));

create policy wtn_trips_editor_update on wtn_trips
  for update
  using (wtn_can_write(id));

-- wtn_trip_members
create policy wtn_members_self on wtn_trip_members
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy wtn_members_owner on wtn_trip_members
  for all
  using (wtn_can_read(trip_id));

-- wtn_events
create policy wtn_events_r on wtn_events for select using      (wtn_can_read(trip_id));
create policy wtn_events_i on wtn_events for insert with check (wtn_can_write(trip_id));
create policy wtn_events_u on wtn_events for update using      (wtn_can_write(trip_id));
create policy wtn_events_d on wtn_events for delete using      (wtn_can_write(trip_id));

-- wtn_flights
create policy wtn_flights_r on wtn_flights for select using      (wtn_can_read(trip_id));
create policy wtn_flights_i on wtn_flights for insert with check (wtn_can_write(trip_id));
create policy wtn_flights_u on wtn_flights for update using      (wtn_can_write(trip_id));
create policy wtn_flights_d on wtn_flights for delete using      (wtn_can_write(trip_id));

-- wtn_stays
create policy wtn_stays_r on wtn_stays for select using      (wtn_can_read(trip_id));
create policy wtn_stays_i on wtn_stays for insert with check (wtn_can_write(trip_id));
create policy wtn_stays_u on wtn_stays for update using      (wtn_can_write(trip_id));
create policy wtn_stays_d on wtn_stays for delete using      (wtn_can_write(trip_id));

-- wtn_pack_items
create policy wtn_pack_r on wtn_pack_items for select using      (wtn_can_read(trip_id));
create policy wtn_pack_i on wtn_pack_items for insert with check (wtn_can_write(trip_id));
create policy wtn_pack_u on wtn_pack_items for update using      (wtn_can_write(trip_id));
create policy wtn_pack_d on wtn_pack_items for delete using      (wtn_can_write(trip_id));

-- wtn_budget_items
create policy wtn_budget_r on wtn_budget_items for select using      (wtn_can_read(trip_id));
create policy wtn_budget_i on wtn_budget_items for insert with check (wtn_can_write(trip_id));
create policy wtn_budget_u on wtn_budget_items for update using      (wtn_can_write(trip_id));
create policy wtn_budget_d on wtn_budget_items for delete using      (wtn_can_write(trip_id));

-- ── 4. Fix trigger ────────────────────────────────────────────────
-- Fire on INSERT *and* UPDATE so the profile is created/refreshed
-- on every Google OAuth login (not just the very first one).
-- ON CONFLICT DO UPDATE keeps name/picture current without touching
-- the approved flag (which is managed separately).

create or replace function wtn_handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.wtn_profiles (id, email, name, picture, approved)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url',
    new.email = 'ryan.ngo94@gmail.com'
  )
  on conflict (id) do update set
    email   = excluded.email,
    name    = excluded.name,
    picture = excluded.picture;
  return new;
end;
$$;

drop trigger if exists wtn_on_auth_user_created on auth.users;
create trigger wtn_on_auth_user_created
  after insert or update on auth.users
  for each row execute procedure wtn_handle_new_user();

-- ── 5. Backfill: ensure your profile row exists ───────────────────
-- The trigger only fires on auth.users INSERT/UPDATE, so if your
-- account was created before the trigger existed the profile row
-- may be missing. This inserts/updates it now.

insert into wtn_profiles (id, email, name, picture, approved)
select
  id,
  email,
  raw_user_meta_data->>'full_name',
  raw_user_meta_data->>'avatar_url',
  true
from auth.users
where email = 'ryan.ngo94@gmail.com'
on conflict (id) do update set
  email    = excluded.email,
  name     = excluded.name,
  picture  = excluded.picture,
  approved = true;
