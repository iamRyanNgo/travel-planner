-- WhereToNext — v7 migration: live sync, trip journal, saved travelers
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- The app feature-detects this — new features stay hidden until run.

-- ── Trip journal (one entry per trip per day) ─────────────────────
create table if not exists wtn_journal (
  id         uuid primary key default gen_random_uuid(),
  trip_id    uuid references wtn_trips(id) on delete cascade not null,
  date       date not null,
  content    text default '',
  updated_by uuid references wtn_profiles(id),
  updated_at timestamptz default now(),
  unique(trip_id, date)
);
alter table wtn_journal enable row level security;
drop policy if exists wtn_journal_r on wtn_journal;
drop policy if exists wtn_journal_i on wtn_journal;
drop policy if exists wtn_journal_u on wtn_journal;
drop policy if exists wtn_journal_d on wtn_journal;
create policy wtn_journal_r on wtn_journal for select using      (wtn_can_read(trip_id));
create policy wtn_journal_i on wtn_journal for insert with check (wtn_can_write(trip_id));
create policy wtn_journal_u on wtn_journal for update using      (wtn_can_write(trip_id));
create policy wtn_journal_d on wtn_journal for delete using      (wtn_can_write(trip_id));

-- ── Saved travelers (account-level, reusable across trips) ────────
create table if not exists wtn_saved_travelers (
  id                      uuid primary key default gen_random_uuid(),
  owner_id                uuid references wtn_profiles(id) on delete cascade not null,
  name                    text not null,
  role                    text,
  email                   text,
  phone                   text,
  nationality             text,
  date_of_birth           date,
  passport_number         text,
  passport_country        text,
  passport_expiry         date,
  visa_type               text,
  visa_expiry             date,
  visa_notes              text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  seat_preference         text,
  meal_preference         text,
  notes                   text,
  created_at              timestamptz default now()
);
alter table wtn_saved_travelers enable row level security;
drop policy if exists wtn_saved_trav on wtn_saved_travelers;
create policy wtn_saved_trav on wtn_saved_travelers
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ── Live sync: put trip tables on the realtime publication ────────
-- (Postgres change events respect RLS, so members only receive rows
-- from trips they can already read.)
do $$
declare t text;
begin
  foreach t in array array[
    'wtn_events','wtn_flights','wtn_stays','wtn_pack_items',
    'wtn_budget_items','wtn_trip_members','wtn_journal','wtn_trip_docs'
  ] loop
    if exists (select 1 from pg_tables where schemaname='public' and tablename=t)
       and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
