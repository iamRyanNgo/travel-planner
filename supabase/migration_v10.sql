-- WhereToNext — v10 migration: exact coordinates on places
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- Lets Google Maps links/imports pin items exactly instead of geocoding.

alter table wtn_events add column if not exists lat double precision;
alter table wtn_events add column if not exists lng double precision;
alter table wtn_stays  add column if not exists lat double precision;
alter table wtn_stays  add column if not exists lng double precision;
