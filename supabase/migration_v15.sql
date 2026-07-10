-- WhereToNext — v15 migration: cancellation windows + travel insurance
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run; idempotent)
--
-- cancel_by: the "free cancellation until" date on a stay — the app warns
--            as the deadline approaches so refundable bookings aren't missed.
-- insurance: per-trip travel-insurance details { provider, policy, phone },
--            surfaced on the Emergency card next to local numbers.

alter table wtn_stays add column if not exists cancel_by date;
alter table wtn_trips add column if not exists insurance jsonb;
