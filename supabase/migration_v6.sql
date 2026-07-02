-- WhereToNext — v6 migration: multiple destinations per trip + region tags
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- The app feature-detects this — multi-destination UI stays hidden until run.

-- Extra destinations beyond the primary one (array of strings,
-- e.g. ["Barcelona, Spain", "Lisbon, Portugal"])
alter table wtn_trips add column if not exists destinations jsonb default '[]';

-- Region tag on items so tabs can be filtered per destination
alter table wtn_events  add column if not exists region text;
alter table wtn_stays   add column if not exists region text;
alter table wtn_flights add column if not exists region text;
