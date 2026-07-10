-- WhereToNext — v17 migration: stop leaking every user's email/name
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- Before: policy wtn_profiles_approved_read let ANY signed-in user
-- SELECT * FROM wtn_profiles and harvest id/email/name/picture for every
-- approved user — a full directory dump. This scopes profile reads to
-- yourself + people you actually share a trip with, and moves the
-- invite-by-email lookup behind a SECURITY DEFINER RPC that returns only
-- the single matched account (no table-wide read).

-- ── Do two users share any trip? (SECURITY DEFINER bypasses RLS inside,
--    so it can't recurse with the trip/member policies) ──
create or replace function wtn_shares_trip_with(p_other uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select p_other = auth.uid() or exists (
    -- a trip I own where they are a member
    select 1 from wtn_trips t join wtn_trip_members m on m.trip_id = t.id
      where t.owner_id = auth.uid() and m.user_id = p_other
    union all
    -- a trip they own where I am a member
    select 1 from wtn_trips t join wtn_trip_members m on m.trip_id = t.id
      where t.owner_id = p_other and m.user_id = auth.uid()
    union all
    -- a trip we are both members of
    select 1 from wtn_trip_members a join wtn_trip_members b on a.trip_id = b.trip_id
      where a.user_id = auth.uid() and b.user_id = p_other
  )
$$;

-- ── Replace the blanket approved-read with a self + co-member policy ──
drop policy if exists wtn_profiles_approved_read on wtn_profiles;
drop policy if exists wtn_profiles_comember_read on wtn_profiles;
create policy wtn_profiles_comember_read on wtn_profiles
  for select using (id = auth.uid() or wtn_shares_trip_with(id));
-- (the admin select/update policies from the base schema stay in place)

-- ── Invite-by-email lookup: return only the one matched account, never
--    the whole table. Exact-email match, so it can't be used to enumerate. ──
create or replace function wtn_find_user_by_email(p_email text)
returns table(id uuid, name text, approved boolean)
language sql security definer stable set search_path = public as $$
  select p.id, p.name, p.approved
  from wtn_profiles p
  where lower(p.email) = lower(trim(p_email))
  limit 1
$$;
grant execute on function wtn_find_user_by_email(text) to authenticated;
