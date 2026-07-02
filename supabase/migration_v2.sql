-- WhereToNext — v2 migration: expense splitting, per-item currency, documents vault
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; everything is idempotent)
-- The app feature-detects this migration — these features stay hidden until it runs.

-- ── Budget: expense splitting + per-item currency ─────────────────
alter table wtn_budget_items add column if not exists paid_by    uuid references wtn_profiles(id);
alter table wtn_budget_items add column if not exists split_with uuid[];
alter table wtn_budget_items add column if not exists currency   text;

-- ── Documents vault ───────────────────────────────────────────────
create table if not exists wtn_trip_docs (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid references wtn_trips(id) on delete cascade not null,
  name        text not null,
  path        text not null,
  mime        text,
  size        bigint,
  uploaded_by uuid references wtn_profiles(id),
  created_at  timestamptz default now()
);
alter table wtn_trip_docs enable row level security;

drop policy if exists wtn_docs_r on wtn_trip_docs;
drop policy if exists wtn_docs_i on wtn_trip_docs;
drop policy if exists wtn_docs_d on wtn_trip_docs;
create policy wtn_docs_r on wtn_trip_docs for select using      (wtn_can_read(trip_id));
create policy wtn_docs_i on wtn_trip_docs for insert with check (wtn_can_write(trip_id));
create policy wtn_docs_d on wtn_trip_docs for delete using      (wtn_can_write(trip_id));

-- ── Storage bucket for documents ──────────────────────────────────
-- Objects are stored as "<trip_id>/<uuid>-<filename>"; policies derive the
-- trip id from the first path segment and reuse the existing RLS helpers.
insert into storage.buckets (id, name, public)
values ('wtn-docs', 'wtn-docs', false)
on conflict (id) do nothing;

drop policy if exists wtn_docs_storage_r on storage.objects;
drop policy if exists wtn_docs_storage_i on storage.objects;
drop policy if exists wtn_docs_storage_d on storage.objects;
create policy wtn_docs_storage_r on storage.objects for select
  using (bucket_id = 'wtn-docs' and wtn_can_read((split_part(name, '/', 1))::uuid));
create policy wtn_docs_storage_i on storage.objects for insert
  with check (bucket_id = 'wtn-docs' and wtn_can_write((split_part(name, '/', 1))::uuid));
create policy wtn_docs_storage_d on storage.objects for delete
  using (bucket_id = 'wtn-docs' and wtn_can_write((split_part(name, '/', 1))::uuid));
