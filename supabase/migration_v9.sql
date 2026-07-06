-- WhereToNext — v9 migration: trusted traveler + membership numbers
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
-- Adds Global Entry / Known Traveler, redress, and loyalty memberships
-- to both trip travelers and account-level saved travelers.

alter table wtn_travelers add column if not exists known_traveler_number text;
alter table wtn_travelers add column if not exists redress_number        text;
alter table wtn_travelers add column if not exists memberships           text;

alter table wtn_saved_travelers add column if not exists known_traveler_number text;
alter table wtn_saved_travelers add column if not exists redress_number        text;
alter table wtn_saved_travelers add column if not exists memberships           text;
