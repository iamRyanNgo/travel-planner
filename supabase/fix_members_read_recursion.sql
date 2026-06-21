-- Fix: infinite recursion in wtn_trip_members RLS policy
--
-- The wtn_members_read policy contained a sub-SELECT on wtn_trip_members itself.
-- When wtn_profiles_member_read (on wtn_profiles) joined wtn_trip_members, it
-- triggered wtn_members_read, which queried wtn_trip_members again → recursion.
--
-- Fix: use wtn_can_read(), which is SECURITY DEFINER and bypasses RLS.
--
-- Run this in: Supabase Dashboard → SQL Editor

drop policy if exists wtn_members_read on wtn_trip_members;

create policy wtn_members_read on wtn_trip_members for select using (
  user_id = auth.uid() or
  wtn_can_read(trip_id)
);
