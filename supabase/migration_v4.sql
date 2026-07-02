-- WhereToNext — v4 migration: multi-modal travel (trains, buses, ferries, cars)
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- The app feature-detects this migration — until it runs, everything in the
-- Travel tab is treated as a flight.

alter table wtn_flights add column if not exists mode text default 'flight';
