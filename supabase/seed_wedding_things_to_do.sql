-- WhereToNext — Things to do for the Julian + Devin wedding trip (Mallorca)
-- Run in: Supabase Dashboard → SQL Editor.
--
-- PURELY ADDITIVE: nothing is deleted or modified. It finds the wedding trip,
-- walks its actual days, and drops a day's worth of Mallorca suggestions on
-- each free day — skipping the wedding day itself and any day that already
-- has 3+ things on it. Leftover suggestions land as undated 💭 ideas.
--
-- Everything goes in UNCONFIRMED so it reads as "potential" in the budget and
-- is obvious to delete/reshuffle. Re-running adds a second copy, so run once.

do $$
declare
  tid uuid; d0 date; dlast date; dest text; ctry text;
  wedding_day date;
  cur_date date;
  plan_idx int := 0;
  plans jsonb; this_plan jsonb; item jsonb;
  added int := 0; skipped int := 0;
begin
  -- ── Find the wedding trip (not the bachelor party) ──
  select id, start_date, end_date, destination, country
    into tid, d0, dlast, dest, ctry
    from wtn_trips
   where name ilike '%julian%'
     and (name ilike '%devin%' or name ilike '%wedding%')
     and name not ilike '%bach%'
   order by created_at desc limit 1;

  if tid is null then
    raise exception 'No Julian + Devin wedding trip found. Check the trip name, or edit the WHERE clause above.';
  end if;
  if d0 is null or dlast is null then
    raise exception 'That trip has no start/end dates yet — set them in the app first so days can be filled.';
  end if;

  -- ── Safety: these suggestions are Mallorca-specific ──
  if coalesce(dest,'') <> '' and
     not (dest ilike '%mallorca%' or dest ilike '%majorca%' or dest ilike '%palma%'
          or coalesce(ctry,'') ilike '%spain%' or coalesce(ctry,'') ilike '%espa%') then
    raise exception 'Trip destination is "%" — this script is written for Mallorca. Delete this guard block if that is intentional.', dest;
  end if;
  -- Fill in destination/country if blank (powers weather + emergency info)
  update wtn_trips
     set destination = coalesce(nullif(destination,''),'Mallorca'),
         country     = coalesce(nullif(country,''),'Spain')
   where id = tid;

  -- ── Don't schedule over the wedding ──
  select min(date) into wedding_day from wtn_events
   where trip_id = tid and date is not null
     and (title ilike '%wedding%' or title ilike '%ceremony%' or title ilike '%reception%');

  -- ── A day's worth of Mallorca, in a sensible order ──
  plans := $json$[
    [
      {"t":"Settle in + Palma old town stroll","c":"sightseeing","time":"17:00","loc":"Casco Antiguo, Palma de Mallorca","n":"Easy first evening — wander the lanes around Placa Major and Carrer Sant Miquel."},
      {"t":"Tapas in Santa Catalina","c":"food","time":"20:30","loc":"Santa Catalina, Palma de Mallorca","n":"The old fishermen's quarter, now the best eating-and-drinking blocks in Palma."}
    ],
    [
      {"t":"La Seu — Palma Cathedral","c":"sightseeing","time":"10:00","loc":"Catedral de Mallorca, Palma","n":"Gaudi reworked the interior and Miquel Barcelo did the extraordinary ceramic chapel. Best light through the rose window mid-morning."},
      {"t":"Lunch at Mercat de l'Olivar","c":"food","time":"13:00","loc":"Mercat de l'Olivar, Palma","n":"Buy seafood at a stall and have it cooked for you on the spot."},
      {"t":"Bellver Castle + sunset over the bay","c":"sightseeing","time":"18:00","loc":"Castell de Bellver, Palma","n":"A round hilltop castle (rare in Europe) with the best view back over Palma."}
    ],
    [
      {"t":"Valldemossa village","c":"sightseeing","time":"09:30","loc":"Valldemossa, Mallorca","n":"Chopin and George Sand spent a winter at the Real Cartuja here. Go early — the coaches arrive around 11."},
      {"t":"Deia + Cala Deia cove","c":"activity","time":"13:00","loc":"Deia, Mallorca","n":"Pebble cove at the bottom of the ravine. Ca's Patro March sits right on the rocks (The Night Manager filmed there) — book lunch ahead."},
      {"t":"Sunset at Port de Soller","c":"sightseeing","time":"19:30","loc":"Port de Soller, Mallorca","n":null}
    ],
    [
      {"t":"Vintage wooden train to Soller","c":"transport","time":"10:00","loc":"Estacio Soller, Placa d'Espanya, Palma","n":"A 1912 train through orange groves and thirteen mountain tunnels, about an hour. Sit on the right heading out."},
      {"t":"Soller old town + fresh orange juice","c":"food","time":"11:30","loc":"Placa Constitucio, Soller","n":"The valley is wall-to-wall orange groves — the juice is the point."},
      {"t":"Open-sided tram down to the port","c":"activity","time":"14:00","loc":"Port de Soller, Mallorca","n":"The little wooden tram rattles through town and along the bay."},
      {"t":"Fornalutx detour","c":"sightseeing","time":"17:00","loc":"Fornalutx, Mallorca","n":"Regularly called the prettiest village in Spain — stone houses stacked up the hillside."}
    ],
    [
      {"t":"Es Trenc beach day","c":"activity","time":"11:00","loc":"Platja des Trenc, Mallorca","n":"The Caribbean-looking one: white sand, shallow turquoise water, protected dunes. Paid parking, bring cash, and an umbrella — there is no shade."},
      {"t":"Seafood lunch in Colonia de Sant Jordi","c":"food","time":"14:30","loc":"Colonia de Sant Jordi, Mallorca","n":null}
    ],
    [
      {"t":"Boat day along the coast","c":"activity","time":"10:00","loc":"Port de Palma, Mallorca","n":"Half or full-day catamaran charter with swim stops in coves you cannot reach by road. Book a few days ahead in season."},
      {"t":"Sunset drinks at Portixol","c":"food","time":"20:00","loc":"Portixol, Palma","n":"Seafront former fishing village, ten minutes from the centre."}
    ],
    [
      {"t":"Cap de Formentor lighthouse","c":"sightseeing","time":"09:00","loc":"Cap de Formentor, Mallorca","n":"Cliff road out to the lighthouse at the island's northern tip. There are seasonal mid-day car restrictions — check before you drive, or take the shuttle bus."},
      {"t":"Swim at Platja de Formentor","c":"activity","time":"12:00","loc":"Platja de Formentor, Mallorca","n":"Pine trees growing right down to the sand."},
      {"t":"Alcudia old town + walls","c":"sightseeing","time":"16:00","loc":"Alcudia Old Town, Mallorca","n":"Medieval walled town; Tuesday and Sunday are the big market days."}
    ],
    [
      {"t":"Coves del Drac + underground concert","c":"sightseeing","time":"10:30","loc":"Coves del Drac, Porto Cristo","n":"One of the largest underground lakes in the world, with a short live classical concert played from boats. Book your time slot online."},
      {"t":"Lunch in Porto Cristo","c":"food","time":"13:30","loc":"Porto Cristo, Mallorca","n":null},
      {"t":"Cala Mondrago + Cala s'Amarador","c":"activity","time":"15:30","loc":"Parc Natural de Mondrago, Mallorca","n":"Two protected coves joined by a short coastal path."}
    ],
    [
      {"t":"Sa Calobra + Torrent de Pareis","c":"activity","time":"09:00","loc":"Sa Calobra, Mallorca","n":"The road coils back under itself at the Nus de sa Corbata. Walk the tunnels through to the mouth of the gorge. Go early or late to miss the coaches — and skip it if anyone gets carsick."},
      {"t":"Celler lunch in Caimari or Selva","c":"food","time":"14:30","loc":"Caimari, Mallorca","n":"Proper inland village cellers — pa amb oli, tumbet, sobrassada."}
    ],
    [
      {"t":"Binissalem wine tasting","c":"activity","time":"11:00","loc":"Binissalem, Mallorca","n":"Mallorca's main wine region. Ask for the local grapes: Manto Negro for red, Prensal Blanc for white."},
      {"t":"Rooftop sunset drinks in Palma","c":"food","time":"19:30","loc":"Palma de Mallorca","n":null},
      {"t":"Farewell dinner","c":"food","time":"21:30","loc":"Palma de Mallorca","n":null}
    ]
  ]$json$::jsonb;

  -- ── Walk the trip's real days and fill the free ones ──
  cur_date := d0;
  while cur_date <= dlast loop
    if wedding_day is not null and cur_date = wedding_day then
      skipped := skipped + 1;                                  -- the big day stays clear
    elsif (select count(*) from wtn_events where trip_id = tid and date = cur_date) >= 3 then
      skipped := skipped + 1;                                  -- already a full day
    else
      this_plan := plans -> plan_idx;
      if this_plan is not null then
        for item in select value from jsonb_array_elements(this_plan) loop
          insert into wtn_events (trip_id,title,category,date,time,location,confirmed,notes)
          values (tid, item->>'t', item->>'c', cur_date, item->>'time', item->>'loc', false, item->>'n');
          added := added + 1;
        end loop;
        plan_idx := plan_idx + 1;
      end if;
    end if;
    cur_date := cur_date + 1;
  end loop;

  -- ── Anything that didn't fit becomes an undated idea ──
  while plans -> plan_idx is not null loop
    for item in select value from jsonb_array_elements(plans -> plan_idx) loop
      insert into wtn_events (trip_id,title,category,date,time,location,confirmed,notes)
      values (tid, item->>'t', 'idea', null, null, item->>'loc', false, item->>'n');
      added := added + 1;
    end loop;
    plan_idx := plan_idx + 1;
  end loop;

  -- ── Extra ideas to slot in anywhere ──
  insert into wtn_events (trip_id,title,category,date,confirmed,location,notes)
  select tid, x.t, 'idea', null, false, x.loc, x.n from (values
    ('Ensaimada at Ca''n Joan de s''Aigo','Palma de Mallorca','The oldest cafe in Palma — ensaimada and thick hot chocolate.'),
    ('Coasteering / cliff jumping at Cala Varques','Cala Varques, Mallorca','Wild unspoilt cove, a short walk in from the road. Go with a guide for the jumps.'),
    ('Walk a stretch of the GR221 Dry Stone Route','Serra de Tramuntana, Mallorca','The long-distance path through the UNESCO mountain range — pick a single section.'),
    ('Sant Elm + boat to Sa Dragonera island','Sant Elm, Mallorca','Uninhabited island nature reserve; lizards everywhere and a lighthouse walk.'),
    ('Sunset at Port d''Andratx','Port d''Andratx, Mallorca','The yacht-harbour end of the island — go for the light, stay for dinner.'),
    ('Saturday market in Soller','Soller, Mallorca','Produce, leather and crafts around the main square.'),
    ('Rent a car for the Tramuntana days','Mallorca','The mountain villages and coves are hard to reach otherwise. Book early in summer.'),
    ('Eat your way through: pa amb oli, tumbet, sobrassada, frit mallorqui','Mallorca','The island classics to tick off at some point.')
  ) as x(t,loc,n);
  added := added + 8;

  raise notice 'Added % suggestions to trip % (% days left alone)', added, tid, skipped;
end $$;
