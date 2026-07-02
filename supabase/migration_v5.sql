-- WhereToNext — v5 migration: per-activity transport method ("getting there")
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- The app feature-detects this — the "Getting there" picker stays hidden
-- until this has been run.

alter table wtn_events add column if not exists transport text;
