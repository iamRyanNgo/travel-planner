-- WhereToNext — Load Boolean's Bachelor Barty official itinerary
-- Run in: Supabase Dashboard → SQL Editor.
--
-- Finds Julian's bach party trip, REPLACES its activities with the official
-- PDF itinerary (Chicago, Aug 20–23 2026), and adds the Airbnb. Flights are
-- NEVER touched — this only deletes/inserts wtn_events (and adds a stay if
-- none exists). Runs as one transaction, so a mismatch rolls everything back.

do $$
declare
  tid uuid;
begin
  -- ── Find the trip (most recent one whose name mentions "bach") ──
  select id into tid from wtn_trips
    where name ilike '%bach%'
    order by created_at desc limit 1;
  if tid is null then
    raise exception 'No trip with "bach" in its name found — rename the trip or adjust the match.';
  end if;

  -- ── Align trip meta with the official list (dates/destination only) ──
  update wtn_trips
     set start_date='2026-08-20', end_date='2026-08-23',
         destination=coalesce(nullif(destination,''),'Chicago'),
         country=coalesce(nullif(country,''),'United States')
   where id=tid;

  -- ── Airbnb — add only if the trip has no accommodation yet (don't clobber) ──
  if not exists (select 1 from wtn_stays where trip_id=tid) then
    insert into wtn_stays (trip_id,name,type,check_in,check_out,address,confirmed,notes)
    values (tid,'Bachelor Barty Airbnb','Airbnb','2026-08-20','2026-08-23',
            '1419 N Paulina St, Chicago, IL 60622',true,'Home base — Wicker Park');
  end if;

  -- ── Replace the itinerary with the official list (flights untouched) ──
  delete from wtn_events where trip_id=tid;

  insert into wtn_events (trip_id,title,category,date,time,location,confirmed,notes) values
    -- ══ DAY 01 · Thu Aug 20 — Ep. 01: Touchdown ══
    (tid,'Arrive Airbnb','other','2026-08-20','14:00','1419 N Paulina St, Chicago, IL 60622',true,'Ep. 01 — Touchdown'),
    (tid,'Sterling Food Hall','food','2026-08-20','15:00','Sterling Food Hall, Chicago, IL',true,null),
    (tid,'Shopping — Magnificent Mile','shopping','2026-08-20','16:00','Magnificent Mile, Chicago, IL',true,null),
    (tid,'Architecture Boat Tour','sightseeing','2026-08-20','18:00','Chicago Riverwalk, Chicago, IL',true,null),
    (tid,'Dinner at The VIG Old Town','food','2026-08-20','20:00','The VIG, Old Town, Chicago, IL',true,null),
    (tid,'Roast Battle at Zanies Comedy Club','activity','2026-08-20','21:30','Zanies Comedy Club, Chicago, IL',true,null),

    -- ══ DAY 02 · Fri Aug 21 — Ep. 02: Full Throttle ══
    (tid,'Gym — Bucktown Fitness Club','activity','2026-08-21','10:30','Bucktown Fitness Club, Chicago, IL',true,null),
    (tid,'Chicago Bath House','activity','2026-08-21','12:00','Chicago, IL',true,null),
    (tid,'Lunch — Wicker Park','food','2026-08-21','14:00','Wicker Park, Chicago, IL',true,'Location TBD'),
    (tid,'Go-Kart Racing — K1 Speed','activity','2026-08-21','15:30','K1 Speed, Addison, IL',true,null),
    (tid,'Emporium Arcade Bar','activity','2026-08-21','19:45','839 W Fulton Market, Chicago, IL',true,null),
    (tid,'Dinner at Duck Duck Goat','food','2026-08-21','21:15','Duck Duck Goat, Chicago, IL',true,null),
    (tid,'River North Bar Crawl','activity','2026-08-21','23:00','River North, Chicago, IL',true,
      'STOP 1 — options:
• Three Dots and a Dash (435 N Clark St) — underground tiki bar behind a wall of skulls; theatrical, memorable-entrance pick.
• Storyville Chicago (712 N Clark St) — Cajun cocktail bar, downstairs Lulu''s for a late-night change of scene. Open till 3 AM.
• The Green Door Tavern (678 N Orleans St) — historic dive with live jazz + a Malört shot wheel; low-key opener.

STOP 2 — options:
• Ghost Donkey (415 N Dearborn St) — Latin music bar that shifts into a dance-floor nightclub later.
• Arbella Cocktail Bar (112 W Grand Ave) — deep old fashioned menu; loud & packed by 11 PM. Till 2–3 AM.
• Spybar (646 N Franklin St) — underground house/EDM club with real DJ sets. Cash-only, mandatory coat check. Till 4–5 AM.'),
    (tid,'Karaoke','activity','2026-08-21','23:59','Chicago, IL',true,
      '1:00 AM — options:
• Mom''s Place (650 N Dearborn St) — sign-up-sheet karaoke, festive; 30+ min waits on busy nights.
• Kitchen Karaoke (109 W Hubbard St) — late-night Korean food + karaoke, open till 4 AM.'),

    -- ══ DAY 03 · Sat Aug 22 — Ep. 03: The Finale ══
    (tid,'Brunch — Bongo Room','food','2026-08-22','11:00','1470 N Milwaukee Ave, Chicago, IL',true,null),
    (tid,'Adler Planetarium','sightseeing','2026-08-22','13:00','Adler Planetarium, Chicago, IL',true,null),
    (tid,'North Avenue Beach — Spikeball & Volleyball','activity','2026-08-22','15:30','North Avenue Beach, Chicago, IL',true,null),
    (tid,'Drinks at Paradise Park Pizza and Patio','food','2026-08-22','19:30','Paradise Park, Chicago, IL',true,null),
    (tid,'Dinner at Alla Vita','food','2026-08-22','21:15','Alla Vita, Chicago, IL',true,null),

    -- ══ DAY 04 · Sun Aug 23 — Depart Chicago ══
    (tid,'Check out & depart Chicago 🛫','other','2026-08-23',null,'Chicago, IL',true,'Next episode: the wedding — Mallorca, España');

  raise notice 'Loaded official itinerary into trip %', tid;
end $$;
