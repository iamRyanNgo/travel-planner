-- WhereToNext — v12 migration: authorization hardening (security audit fixes)
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- Fixes from the security review:
--   C1 — wtn_members_self let ANY authenticated user insert themselves as
--        editor into ANY trip (and viewers self-promote to editor).
--   H2 — editors could UPDATE wtn_trips.owner_id to seize ownership and
--        thereby read owner-only traveler/passport data.
--   H1 — approval was only enforced on trip creation; all item writes were
--        ungated. Now enforced centrally in wtn_can_write + friends.
--   M3 — ensure member management is owner-only.

-- ── C1: members may only READ their own membership and LEAVE a trip ──
-- Inserts/role changes now happen exclusively via the owner policy
-- (wtn_members_owner) or the SECURITY DEFINER invite RPC (wtn_join_by_invite),
-- never by the user editing their own row.
drop policy if exists wtn_members_self on wtn_trip_members;
create policy wtn_members_self_read  on wtn_trip_members
  for select using (user_id = auth.uid());
create policy wtn_members_self_leave on wtn_trip_members
  for delete using (user_id = auth.uid());

-- ── M3: member management is owner-only, both directions ──
drop policy if exists wtn_members_owner on wtn_trip_members;
create policy wtn_members_owner on wtn_trip_members
  for all
  using      (wtn_is_owner(trip_id))
  with check (wtn_is_owner(trip_id));

-- ── H2: nobody but the current owner may reassign owner_id ──
create or replace function wtn_guard_trip_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is distinct from old.owner_id and old.owner_id <> auth.uid() then
    raise exception 'only the trip owner may transfer ownership';
  end if;
  return new;
end $$;
drop trigger if exists wtn_trips_guard on wtn_trips;
create trigger wtn_trips_guard before update on wtn_trips
  for each row execute function wtn_guard_trip_update();

-- ── H1: require approval for ALL writes, centrally ──
-- wtn_can_write backs every item insert/update/delete policy, so adding the
-- approval check here gates events, flights, stays, packing, budget, journal
-- and docs in one place. (wtn_is_approved from migration_v11.)
create or replace function wtn_can_write(trip uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select wtn_is_approved() and exists (
    select 1 from wtn_trips t where t.id = trip and (
      t.owner_id = auth.uid() or
      exists (
        select 1 from wtn_trip_members m
        where m.trip_id = t.id and m.user_id = auth.uid() and m.role = 'editor'
      )
    )
  )
$$;

-- Comments, votes and saved travelers don't route through wtn_can_write —
-- gate them explicitly on approval too.
drop policy if exists wtn_cmt_i on wtn_comments;
create policy wtn_cmt_i on wtn_comments for insert
  with check (wtn_can_read(trip_id) and author_id = auth.uid() and wtn_is_approved());

drop policy if exists wtn_vote_w on wtn_votes;
create policy wtn_vote_w on wtn_votes for all
  using      (user_id = auth.uid() and wtn_can_read(trip_id))
  with check (user_id = auth.uid() and wtn_can_read(trip_id) and wtn_is_approved());

drop policy if exists wtn_saved_trav on wtn_saved_travelers;
create policy wtn_saved_trav on wtn_saved_travelers
  for all
  using      (owner_id = auth.uid())
  with check (owner_id = auth.uid() and wtn_is_approved());
