-- WhereToNext — v13 migration: public read-only share links
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- Lets a trip owner publish a read-only itinerary anyone can VIEW via a
-- secret link, without signing in. Implemented as a SECURITY DEFINER RPC
-- that returns a curated JSON snapshot only when the token matches — it
-- deliberately EXCLUDES travelers (passport/visa), documents, comments,
-- votes and member emails. Revoking = clearing the token.

alter table wtn_trips add column if not exists share_token uuid;
create unique index if not exists wtn_trips_share_token_idx on wtn_trips(share_token) where share_token is not null;

-- Owner toggles sharing on/off (returns the token or null)
create or replace function wtn_set_share(p_trip uuid, p_on boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare tok uuid;
begin
  if not exists (select 1 from wtn_trips where id = p_trip and owner_id = auth.uid()) then
    raise exception 'not the owner';
  end if;
  if p_on then
    update wtn_trips set share_token = coalesce(share_token, gen_random_uuid())
      where id = p_trip returning share_token into tok;
  else
    update wtn_trips set share_token = null where id = p_trip;
    tok := null;
  end if;
  return tok;
end $$;

-- Anonymous read of a shared trip by token — curated, read-only, no PII
create or replace function wtn_get_shared_trip(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public
stable as $$
declare t wtn_trips; result jsonb;
begin
  select * into t from wtn_trips where share_token = p_token;
  if not found then return null; end if;
  select jsonb_build_object(
    'trip', jsonb_build_object(
      'id', t.id, 'name', t.name, 'emoji', t.emoji, 'destination', t.destination,
      'country', t.country, 'destinations', t.destinations, 'start_date', t.start_date,
      'end_date', t.end_date, 'currency', t.currency, 'gradient_idx', t.gradient_idx,
      'banner_url', t.banner_url, 'notes', t.notes),
    'events',  coalesce((select jsonb_agg(to_jsonb(e) - 'created_at') from wtn_events e  where e.trip_id = t.id), '[]'),
    'flights', coalesce((select jsonb_agg(to_jsonb(f) - 'created_at') from wtn_flights f where f.trip_id = t.id), '[]'),
    'stays',   coalesce((select jsonb_agg(to_jsonb(s) - 'created_at' - 'confirm_num' - 'phone') from wtn_stays s where s.trip_id = t.id), '[]')
  ) into result;
  return result;
end $$;

-- Let the anon (logged-out) role call the read RPC; owner RPC stays auth-only
grant execute on function wtn_get_shared_trip(uuid) to anon, authenticated;
grant execute on function wtn_set_share(uuid, boolean) to authenticated;
