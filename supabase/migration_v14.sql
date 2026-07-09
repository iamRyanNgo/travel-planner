-- WhereToNext — v14 migration: custom emergency contacts per trip
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- Lets a trip store personalised emergency contacts (embassy, hotel front
-- desk, a local friend, travel-insurance hotline…) alongside the built-in
-- country emergency numbers shown on the overview. Stored as a JSON array of
-- { name, phone } objects on the trip, so it inherits the existing trip RLS
-- (owner + members can read; owner/editors can write).

alter table wtn_trips add column if not exists emergency_contacts jsonb;
