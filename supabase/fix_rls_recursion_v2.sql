-- Fix: remaining infinite recursion via wtn_members_owner <-> wtn_trips_member_read
--
-- wtn_members_owner reads wtn_trips directly. wtn_trips has wtn_trips_member_read
-- which reads wtn_trip_members, which triggers wtn_members_owner again — cycle.
--
-- Fix: replace the direct wtn_trips sub-select with a SECURITY DEFINER function
-- that reads wtn_trips without RLS, breaking the cycle.
--
-- Run in: Supabase Dashboard → SQL Editor

-- Helper: check trip ownership without RLS (SECURITY DEFINER bypasses row-level policies)
create or replace function wtn_is_owner(p_trip_id uuid) returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from wtn_trips where id = p_trip_id and owner_id = auth.uid()
  )
$$;

-- Recreate wtn_can_read with explicit search_path (belt-and-suspenders)
create or replace function wtn_can_read(trip uuid) returns boolean
language sql security definer stable
set search_path = public
as $$
  select exists (
    select 1 from wtn_trips t where t.id = trip and (
      t.owner_id = auth.uid() or
      exists (select 1 from wtn_trip_members m where m.trip_id = t.id and m.user_id = auth.uid())
    )
  )
$$;

-- Fix wtn_members_owner: was doing exists(select from wtn_trips) which triggered
-- wtn_trips_member_read → wtn_trip_members → wtn_members_owner → cycle
drop policy if exists wtn_members_owner on wtn_trip_members;
create policy wtn_members_owner on wtn_trip_members for all using (
  wtn_is_owner(trip_id)
);

-- Re-apply wtn_members_read fix (in case previous run didn't take)
drop policy if exists wtn_members_read on wtn_trip_members;
create policy wtn_members_read on wtn_trip_members for select using (
  user_id = auth.uid() or
  wtn_can_read(trip_id)
);

-- Remove wtn_profiles_member_read: it joins wtn_trip_members from within a wtn_profiles
-- query, which was another entry point into the recursion chain
drop policy if exists wtn_profiles_member_read on wtn_profiles;
