-- WhereToNext — Example-itinerary clone of the "our wedding<3" trip
-- Run in: Supabase Dashboard → SQL Editor (safe to re-run: each run creates
-- a fresh "… — Example" copy; delete extras from the dashboard if you re-run).
--
-- What it does:
--   1. Finds your wedding trip (name contains "wedding"; prefers the one
--      with "<3") and clones it — same dates, destinations, cover, currency.
--   2. Copies YOUR hotels (stays) and flights exactly as you entered them.
--   3. Fills in a full example Vietnam honeymoon itinerary day by day —
--      Hanoi street food + Train Street, an overnight HA LONG BAY CRUISE
--      (added as its own stay), Bà Nà Hills' Golden Bridge, Hội An lanterns,
--      a cooking class, beach time, and a wedding-day placeholder.
--   4. Adds pre-trip budget items (international flights, insurance, visas)
--      so the new "Spend by day" chart has a Pre-trip bucket to show.
-- Day offsets scale to your real trip length (everything is clamped inside
-- start_date..end_date), so nothing lands outside the trip.

alter table wtn_trips add column if not exists banner_url text;  -- exists in prod; guard for safety

do $$
declare
  src wtn_trips;
  new_id uuid;
  d0 date; dlast date; len int;
  d2 date; d3 date; d4 date; d5 date; d6 date; d7 date; dwed date;
begin
  -- ── 1. Find the source trip ──
  select * into src from wtn_trips
    where name ilike '%wedding%'
    order by (name like '%<3%') desc, created_at desc
    limit 1;
  if not found then
    raise exception 'No trip with "wedding" in its name was found';
  end if;

  d0    := coalesce(src.start_date, current_date);
  dlast := coalesce(src.end_date, d0 + 9);
  len   := greatest(1, dlast - d0 + 1);

  -- plan-day anchors, clamped into the trip window
  d2   := least(d0 + 2, dlast);            -- cruise embark
  d3   := least(d0 + 3, dlast);            -- cruise morning / fly south
  d4   := least(d0 + 4, dlast);            -- Da Nang
  d5   := least(d0 + 5, dlast);            -- Bà Nà Hills
  d6   := least(d0 + 6, dlast);            -- Hội An old town
  d7   := least(d0 + 7, dlast);            -- cooking class + beach
  dwed := greatest(d0, dlast - 1);         -- wedding day: second-to-last

  -- ── 2. Clone the trip shell ──
  insert into wtn_trips (owner_id, name, emoji, destination, country, destinations,
                         start_date, end_date, currency, gradient_idx, travelers,
                         notes, banner_url)
  values (src.owner_id, src.name || ' — Example', src.emoji, src.destination,
          src.country, src.destinations, src.start_date, src.end_date,
          src.currency, src.gradient_idx, src.travelers,
          'Example itinerary — generated as a filled-in template. Edit anything!',
          src.banner_url)
  returning id into new_id;

  -- ── 3. Copy YOUR hotels + flights untouched ──
  insert into wtn_stays (trip_id, name, type, check_in, check_in_time, check_out,
                         check_out_time, address, confirm_num, phone, cost, confirmed,
                         notes, region, paid_by, split_with, lat, lng, cancel_by)
    select new_id, name, type, check_in, check_in_time, check_out, check_out_time,
           address, confirm_num, phone, cost, confirmed, notes, region, paid_by,
           split_with, lat, lng, cancel_by
    from wtn_stays where trip_id = src.id;

  insert into wtn_flights (trip_id, from_airport, to_airport, airline, flight_num,
                           depart_date, depart_time, arrive_date, arrive_time, seat,
                           terminal, confirm_num, cost, confirmed, notes, paid_by,
                           split_with, mode, region)
    select new_id, from_airport, to_airport, airline, flight_num, depart_date,
           depart_time, arrive_date, arrive_time, seat, terminal, confirm_num, cost,
           confirmed, notes, paid_by, split_with, mode, region
    from wtn_flights where trip_id = src.id;

  -- ── 4. The requested Ha Long Bay overnight cruise (its own stay) ──
  insert into wtn_stays (trip_id, name, type, check_in, check_in_time, check_out,
                         check_out_time, address, cost, confirmed, notes, region)
  values (new_id, 'Ha Long Bay Overnight Cruise — Heritage Line', 'Other',
          d2, '12:00', least(d2 + 1, dlast), '10:30',
          'Tuan Chau Marina, Ha Long, Quang Ninh, Vietnam',
          340, false,
          'Junk-boat cruise: kayaking in Luon Cave, Sung Sot grotto, Ti Top island, sunset tai chi on deck. Book the terrace cabin!',
          'Ha Long');

  -- ── 5. Example itinerary events ──
  insert into wtn_events (trip_id, title, category, date, time, location, cost, confirmed, notes) values
    -- Day 0 — arrive Hanoi
    (new_id, 'Arrive & check in',                              'other',       d0, '15:00', 'Hanoi',            null, true,  'Grab e-visa printouts + dong from the airport ATM'),
    (new_id, 'Old Quarter evening walk',                       'sightseeing', d0, '18:00', 'Hoan Kiem, Hanoi', null, true,  'Get lost on purpose — 36 guild streets'),
    (new_id, 'Bún chả dinner',                                 'food',        d0, '19:30', 'Bún Chả Hương Liên, Hanoi', 15, true, 'The Obama–Bourdain table is upstairs 😄'),
    -- Day 1 — Hanoi
    (new_id, 'Egg coffee at Café Giảng',                       'food',        least(d0+1,dlast), '09:00', 'Hanoi', 5,  true,  'Cà phê trứng — order two immediately'),
    (new_id, 'Hoàn Kiếm Lake & Ngọc Sơn Temple',               'sightseeing', least(d0+1,dlast), '10:30', 'Hanoi', 3,  true,  null),
    (new_id, 'Train Street café',                              'activity',    least(d0+1,dlast), '15:00', 'Hanoi', 6,  false, 'Check the train timetable with the café'),
    (new_id, 'Water Puppet Theatre',                           'activity',    least(d0+1,dlast), '18:00', 'Thang Long Theatre, Hanoi', 16, false, null),
    -- Day 2 — Ha Long Bay cruise
    (new_id, 'Transfer Hanoi → Ha Long (shuttle)',             'transport',   d2, '08:00', 'Tuan Chau Marina', 40, true, '~2.5h limousine van, booked via cruise line'),
    (new_id, 'Cruise embarkation + lunch on deck 🚢',          'activity',    d2, '12:30', 'Ha Long Bay',      null, true, null),
    (new_id, 'Kayaking Luon Cave lagoon',                      'activity',    d2, '15:30', 'Ha Long Bay',      null, true, 'Monkeys on the cliffs — hold onto sunglasses'),
    (new_id, 'Sunset tai chi + dinner on board',               'food',        d2, '18:00', 'Ha Long Bay',      null, true, null),
    -- Day 3 — cruise morning, head south
    (new_id, 'Sung Sot cave at sunrise',                       'sightseeing', d3, '06:30', 'Ha Long Bay',      null, true, 'Before the day boats arrive'),
    (new_id, 'Ti Top Island viewpoint + swim',                 'activity',    d3, '08:30', 'Ha Long Bay',      null, true, '400 steps — worth every one'),
    (new_id, 'Fly Hanoi → Da Nang',                            'transport',   d3, '18:00', 'HAN → DAD',        95,  false, '~1h20m, book VietJet or Bamboo'),
    -- Day 4 — Da Nang
    (new_id, 'Mỹ Khê Beach morning',                           'activity',    d4, '09:00', 'Da Nang',          null, true, null),
    (new_id, 'Marble Mountains caves & pagodas',               'sightseeing', d4, '14:00', 'Da Nang',          7,   true, 'Elevator up, walk down'),
    (new_id, 'Dragon Bridge fire show 🐉',                     'activity',    d4, '21:00', 'Da Nang',          null, false, 'Weekends only — 9pm sharp'),
    -- Day 5 — Golden Bridge
    (new_id, 'Bà Nà Hills + Golden Bridge day trip',           'sightseeing', d5, '08:30', 'Ba Na Hills, Da Nang', 62, false, 'Go EARLY — the hands photo needs no crowds. Cable car is the world''s longest'),
    (new_id, 'Seafood dinner on the beach',                    'food',        d5, '19:00', 'Bé Mặn, Da Nang',  35, false, 'Point at the tank, they grill it'),
    -- Day 6 — Hội An
    (new_id, 'Hội An Ancient Town + Japanese Bridge',          'sightseeing', d6, '10:00', 'Hoi An',           5,  true, 'Buy the 5-ticket old-town pass'),
    (new_id, 'Tailor fitting (24h suits & dresses)',           'shopping',    d6, '14:00', 'Hoi An',           null, false, 'Bebe or Yaly — bring reference photos'),
    (new_id, 'Lantern boat on the Thu Bồn river 🏮',           'activity',    d6, '19:00', 'Hoi An',           10, true, 'Full-moon nights are magic'),
    -- Day 7 — cooking + beach
    (new_id, 'Cooking class + Trà Quế herb village by bike',   'activity',    d7, '09:00', 'Hoi An',           48, false, 'Market tour → basket boat → cook 4 dishes'),
    (new_id, 'An Bàng Beach afternoon',                        'activity',    d7, '14:30', 'Hoi An',           null, true, null),
    -- Wedding day (second-to-last day)
    (new_id, 'Hair & makeup / get ready 💄',                   'other',       dwed, '10:00', null,             null, true, null),
    (new_id, 'Wedding ceremony 💍',                            'other',       dwed, '16:00', 'Ceremony venue', null, true, 'THE day!'),
    (new_id, 'Sunset reception dinner 🥂',                     'food',        dwed, '18:30', null,             null, true, null),
    -- Last day
    (new_id, 'Souvenir run: coffee, silk, lanterns',           'shopping',    dlast, '10:00', null,            30, false, 'Phin filters + weasel coffee for gifts'),
    (new_id, 'Fly home ✈️',                                    'transport',   dlast, '17:00', null,            null, true, null);

  -- ── 6. Pre-trip budget items (dateless → the chart's Pre-trip bucket) ──
  insert into wtn_budget_items (trip_id, name, category, planned, actual, notes) values
    (new_id, 'International flights',   'Flights',       1400, 1380, 'Booked 4 months out'),
    (new_id, 'Travel insurance',        'Misc',           180,  172, 'Annual multi-trip policy'),
    (new_id, 'Vietnam e-visas (x2)',    'Misc',            50,   50, 'evisa.gov.vn — official site only'),
    (new_id, 'Wedding outfits & rings', 'Shopping',      1200,  950, null);

  raise notice 'Created example trip % (id %)', src.name || ' — Example', new_id;
end $$;
