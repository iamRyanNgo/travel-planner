-- WhereToNext — v8 migration: comments & voting on trip items
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- Requires migration_v3 (wtn_is_owner). The app feature-detects this.

-- ── Comments ──────────────────────────────────────────────────────
create table if not exists wtn_comments (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid references wtn_trips(id) on delete cascade not null,
  target_kind text not null check (target_kind in ('event','flight','stay','budget','trip')),
  target_id   uuid not null,
  author_id   uuid references wtn_profiles(id) not null,
  content     text not null,
  created_at  timestamptz default now()
);
alter table wtn_comments enable row level security;
drop policy if exists wtn_cmt_r on wtn_comments;
drop policy if exists wtn_cmt_i on wtn_comments;
drop policy if exists wtn_cmt_d on wtn_comments;
-- Any trip member (viewers included) can read and write comments;
-- delete your own, or anything as the trip owner
create policy wtn_cmt_r on wtn_comments for select using (wtn_can_read(trip_id));
create policy wtn_cmt_i on wtn_comments for insert with check (wtn_can_read(trip_id) and author_id = auth.uid());
create policy wtn_cmt_d on wtn_comments for delete using (author_id = auth.uid() or wtn_is_owner(trip_id));

-- ── Votes (👍 / 👎, one per person per item) ──────────────────────
create table if not exists wtn_votes (
  trip_id     uuid references wtn_trips(id) on delete cascade not null,
  target_kind text not null,
  target_id   uuid not null,
  user_id     uuid references wtn_profiles(id) not null,
  vote        int not null check (vote in (1,-1)),
  primary key (target_kind, target_id, user_id)
);
alter table wtn_votes enable row level security;
drop policy if exists wtn_vote_r on wtn_votes;
drop policy if exists wtn_vote_w on wtn_votes;
create policy wtn_vote_r on wtn_votes for select using (wtn_can_read(trip_id));
create policy wtn_vote_w on wtn_votes for all
  using (user_id = auth.uid() and wtn_can_read(trip_id))
  with check (user_id = auth.uid() and wtn_can_read(trip_id));

-- ── Live sync for both ────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array['wtn_comments','wtn_votes'] loop
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
