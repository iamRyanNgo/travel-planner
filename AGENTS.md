# WhereToNext — orientation for an AI agent

Read this before touching the code. It explains what this project is, the
handful of rules that are easy to violate by accident, and the workflow that
gets a change in front of the user.

*(Claude Code users: this is the project's agent brief — same content you'd
expect in CLAUDE.md.)*

---

## 1. What this is

**WhereToNext** is a collaborative travel planner. A user creates a trip, then
fills in an itinerary, flights/trains, accommodations, a map, packing lists, a
budget with expense splitting, traveler documents and a journal. Trips can be
shared with other people (editor/viewer) with live sync, or published as a
read-only public link.

It was built for a specific group of people planning real trips (a wedding in
Jeju, a bachelor party in Chicago, a wedding in Mallorca). It is in **real use**
by non-technical people — treat production breakage as a genuine problem, not a
hypothetical one.

### The stack, in one breath

- **Frontend:** one file. `index.html` (~6,500 lines) contains *all* the HTML,
  CSS and JavaScript. Vanilla JS. **No framework, no build step, no bundler, no
  npm install.** You edit the file, commit it, and it's live.
- **Backend:** Supabase — Postgres with Row Level Security, Google OAuth (plus
  a username/password path), Storage, and Realtime.
- **Hosting:** Vercel, deploying from the `main` branch. `vercel.json` holds
  headers, CSP and rewrites.
- **Offline:** `sw.js` service worker + a `localStorage` data cache + an outbox
  of pending writes.
- **Vendored:** `supabase.js` (the client) and `vendor/leaflet/` (maps, lazy
  loaded only when the Map tab opens). Both self-hosted on purpose — do not
  swap them for CDN links, the CSP forbids it.

### The other docs

| File | What it's for |
|---|---|
| `DESIGN.md` | The visual design system — color tokens, typography, the "liquid glass" treatment, component specs. Read before any visual change. |
| `MOBILE.md` | The mobile/PWA system — safe areas, bottom nav, gestures, service worker. Written to be portable to other projects. |
| `supabase/wheretonext.sql` | The base schema: tables, RLS policies, triggers. |
| `supabase/migration_v*.sql` | Incremental schema changes, v2 → v17. |
| `supabase/seed_*.sql` | One-off data scripts the user runs by hand. |

---

## 2. The rules that matter most

These are the ones an agent gets wrong without realising.

### 2.1 You cannot write to the database. Ship SQL instead.

RLS blocks direct writes from this environment, and there is no service key
here. **Never try to insert/update the user's data yourself.** When the task is
"add these trips / fix this data", the deliverable is a **SQL script in
`supabase/`** that the user runs in the Supabase SQL Editor. Established
conventions for those scripts:

- Wrap logic in `do $$ ... end $$;` so it runs as one transaction and a failure
  rolls everything back cleanly.
- Be **idempotent where you can**, and say in a header comment whether
  re-running is safe (seeds usually create duplicates — say so).
- **Guard every optional column** you touch with
  `alter table X add column if not exists ...`, mirroring the migration that
  introduced it. Not every migration has been applied to the live database —
  this has bitten us before (`lat`/`lng` from v10 were missing).
- **Never put a secret in a committed script.** Passwords and keys are set in
  the Supabase dashboard; committed SQL may only reference the account (e.g. by
  email). Git history is forever.
- Prefer **additive** scripts. If a script deletes rows, say so loudly in both
  the header comment and your message to the user.

### 2.2 Never break the single-file architecture

No build tooling, no module splitting, no framework, no new runtime
dependencies. Everything inline in `index.html`. This is a deliberate choice:
the user can read and host the whole app as one file. If a change seems to need
a bundler, it is the wrong change.

### 2.3 Schema feature flags — the app must run against an older database

Optional columns/tables are detected at boot and gated behind flags, so the app
degrades gracefully when a migration hasn't been run:

| Flag | Detects | Feature |
|---|---|---|
| `SCHEMA_V2` | `wtn_budget_items.paid_by` | expense splitting, documents |
| `SCHEMA_V3` | `wtn_flights.paid_by` | splits on flights/stays/events |
| `SCHEMA_V4` | `wtn_flights.mode` | train/bus/ferry/car transport modes |
| `SCHEMA_V5` | `wtn_events.transport` | per-event transport |
| `SCHEMA_V6` | `wtn_trips.destinations` | multi-destination + region filtering |
| `SCHEMA_V7` | `wtn_journal` | journal, saved travelers, realtime |
| `SCHEMA_V8` | `wtn_comments` | comments + votes |
| `SCHEMA_V9` | `wtn_travelers.known_traveler_number` | traveler docs |
| `SCHEMA_V10` | `wtn_events.lat` | exact coordinates / Google Maps import |
| `SCHEMA_V13` | `wtn_trips.share_token` | public read-only share links |
| `SCHEMA_V14` | `wtn_trips.emergency_contacts` | custom emergency contacts |
| `SCHEMA_V15` | `wtn_stays.cancel_by` | cancellation windows, travel insurance |

**If you add a column, add a flag**, detect it in the boot `Promise.all`, and
gate both the UI and the save path on it. Never assume a column exists.

### 2.4 Security is enforced in the database, not the client

`isAdmin()` and the `/admin` route are **conveniences**. The real boundaries are
the RLS policies. A past audit found and fixed genuinely serious holes here, so:

- Don't "fix" a permission problem by hiding a button — fix the policy.
- **Escape everything** that reaches `innerHTML`. `esc()` is the helper. Two
  stored-XSS bugs have already been found in this codebase (an unescaped emoji
  field, and a URL interpolated into a `style` attribute — see
  `safeBannerUrl()`, which percent-encodes characters that could break out).
  User-controlled data in an **attribute** context needs more than `esc()`.
- **Check Supabase errors.** `await DB.from(...).update(...)` returns
  `{error}`; ignoring it and toasting success caused silent data loss. Always
  destructure and handle it.

### 2.5 Verify by actually running it

There is no test suite. Two checks are cheap and expected before you commit:

```bash
# 1. every inline <script> parses
node -e '
const fs=require("fs");const html=fs.readFileSync("index.html","utf8");
const re=/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;let m,i=0,bad=0;
while((m=re.exec(html))){i++;try{new Function(m[1]);}catch(e){bad++;console.log("Block #"+i+":",e.message);}}
console.log("blocks:",i,"errors:",bad);'
```

```bash
# 2. boot it for real — Chromium + Playwright are preinstalled
python3 -m http.server 8777 &   # then drive http://127.0.0.1:8777/index.html
```

Playwright can render the signed-out screen directly. To exercise the
**signed-in** paths without a network, assign the app's state in page context
and call the renderers. Note the app uses top-level `let` bindings, so
`window.TRIPS = ...` does **not** work — assign `TRIPS = ...` (no `window.`)
inside `page.evaluate`, then call `renderDashboard()`, `renderTripShell()` and
`renderTab()` for each tab. This has caught real regressions.

---

## 3. How the code is laid out

`index.html` is one file but it is sectioned with banner comments. Search for
these to navigate (line numbers drift — search, don't trust them):

```
CONFIG · SUPABASE CLIENT · STATE · UTILITIES · ROUTER · AUTH FLOW
DATA LOADING · ADMIN PANEL · DASHBOARD RENDER · TRIP VIEW RENDER
MODAL SYSTEM · TRIP JOURNAL · KEYBOARD SHORTCUTS · PWA · BOOT
```

### Core state (top-level `let`)

- `ME` — the signed-in profile; `TRIPS` — the user's trips;
  `TD[tripId]` — one trip's loaded detail (`events`, `flights`, `stays`,
  `packItems`, `budgetItems`, `members`, `travelers`, `journal`, `docs`,
  `comments`, `votes`, `ownerProfile`).
- `CUR` — `{view, tripId, tab}`, the current location in the app.
- `REGION_FILTER` — the selected destination, when filtering a multi-city trip.

### Rendering model

Full re-render into `innerHTML`, not a virtual DOM. `renderTab()` dispatches to
`renderOverview / renderItinerary / renderFlights / renderStays / renderPacking
/ renderBudget / renderTravelers / renderMapShell`. Async enrichment (weather,
nearest hospital, flight durations) is fired *after* the synchronous render and
fills in placeholder elements by id — always re-query the element after an
`await`, because the user may have navigated away.

### Saving

After a write, call **`refreshTables(tripId, 'wtn_events')`** — it refetches
only the affected table and re-renders. Do **not** call `loadTripDetail()`
after a save; that re-runs ~11 queries and was deliberately replaced.

### Tables and RPCs

Tables: `wtn_profiles`, `wtn_access_requests`, `wtn_trips`, `wtn_trip_members`,
`wtn_events`, `wtn_flights`, `wtn_stays`, `wtn_pack_items`, `wtn_budget_items`,
`wtn_travelers`, `wtn_saved_travelers`, `wtn_trip_docs`, `wtn_journal`,
`wtn_comments`, `wtn_votes`.

RPCs: `wtn_clone_trip`, `wtn_join_by_invite`, `wtn_set_share`,
`wtn_get_shared_trip`, `wtn_find_user_by_email`.

### Access model

Invite-only. New users land on a **Request Access** screen; an admin approves
them (`wtn_profiles.approved`). Per trip, a user is **owner**, **editor** or
**viewer** — `canWrite(t)` gates every edit affordance. Traveler/passport data
is **owner-only**, by policy as well as UI.

### External APIs (all keyless, all in the CSP)

Open-Meteo (weather + geocoding + timezone offsets), Photon and Nominatim
(geocoding, amenity lookups — Nominatim is throttled to 1 req/sec via a shared
`GEO_LAST` gate), Frankfurter/open.er-api (currency), Unsplash (banner search).
**Adding any new host requires editing `connect-src` in `vercel.json`,** or the
browser will block it.

---

## 4. Workflow

The user works from a deployed site, so "done" means **deployed**, not
committed. The established sequence:

```bash
# work on the feature branch
git add -A && git commit -q -m "…"
git push -u origin claude/login-issue-a0z2ay
# then fast-forward main, which is what Vercel deploys
git checkout main -q && git merge --ff-only claude/login-issue-a0z2ay -q
git push origin main
git checkout claude/login-issue-a0z2ay -q
```

Conventions that have held throughout:

- **Deploy every change** unless told otherwise; the user tests on the live site.
- **Don't open pull requests** unless asked.
- After deploying, tell the user to **hard-refresh** — the service worker can
  hold the previous build for one load.
- When a change needs a migration, **say so prominently** and name the file.
  Migrations are run by the user, by hand, and are easy to forget.
- Comments in this codebase explain *why*, not *what*. Match that. Several
  non-obvious decisions (the geocoder's exact-match ordering, the realtime echo
  guard, the mousedown-origin modal check) are documented in-line — read the
  nearby comment before "simplifying" something that looks odd.

---

## 5. Known rough edges

Honest state of things, so you don't rediscover them the hard way:

- **CSP still allows `'unsafe-inline'`** for scripts, because the app is built
  from inline handlers. It's a known gap; tightening it means externalising all
  the JS, which conflicts with §2.2. Don't half-do it.
- **Reminders use device-local time**, not airport-local, so a check-in window
  can be off by the timezone offset for a traveler in another zone. The correct
  machinery (`tzOffsetFor`) exists and is used for flight durations.
- **No push notifications while the app is closed.** Alerts fire when the app is
  opened. Real push needs a server (Supabase Edge Functions) to send them.
- **The free-tier Supabase project auto-pauses** after about a week of
  inactivity. Symptom: the page shell loads but hangs forever. It is not a code
  bug — the fix is Resume in the Supabase dashboard.
- **`geoCache` in `localStorage` grows unbounded** and is re-parsed on every
  read. Fine for now, worth an in-memory layer plus a cap if it misbehaves.
- Some migrations were **not applied in order** on the live database. Assume
  nothing; guard columns (§2.1).

---

## 6. Working with this user

- They are **non-technical**. Explain in plain language, lead with the outcome,
  and keep implementation detail short unless asked.
- They iterate fast and in small steps, often from screenshots. Expect "make it
  nicer" — consult `DESIGN.md` rather than inventing a new direction.
- They will say when something looks wrong on the live site. **Believe the
  report and go reproduce it**; don't argue from the code. Several real bugs in
  this project were found exactly that way (a stray UI element, a popover
  painting behind a card, a geocoder landing in the wrong country).
- When something can't be done from here (database writes, dashboard settings),
  **say so plainly and hand over the exact steps or link** — don't pretend it's
  done.
