-- WhereToNext — Three guest-scenario trips for the May 22, 2027 wedding
-- Run in: Supabase Dashboard → SQL Editor. Re-running creates fresh copies;
-- delete extras from the dashboard if you run it twice.
--
--   Trip A 🇯🇵→🇰🇷  Japan week first (Tokyo→Kyoto), into Jeju 3 days early,
--                    wedding May 22, then a Korea week (Jeju→Seoul).
--   Trip B 🇰🇷→🇯🇵  Korea week first (Seoul→Jeju 4 days early), wedding
--                    May 22, then a Japan week (Osaka→Nara→Kyoto→Tokyo).
--   Trip C 🇰🇷      All Korea: Seoul→Busan→Jeju (2 days early), wedding
--                    May 22, then Jeju + Seoul.
--
-- Everyone lands in Asia May 15 (one week before). Wedding-day events are
-- fixed; everything else is an editable suggestion (left unconfirmed).
-- Suggested hotels carry rough costs so the Spend-by-Day chart demos well.

-- Optional columns (idempotent guards, mirroring migrations v2/v3/v4/v6/v10/v15)
alter table wtn_trips   add column if not exists destinations jsonb default '[]';
alter table wtn_trips   add column if not exists banner_url text;
alter table wtn_stays   add column if not exists region text;
alter table wtn_stays   add column if not exists cancel_by date;
alter table wtn_flights add column if not exists mode text default 'flight';
alter table wtn_flights add column if not exists region text;
alter table wtn_events  add column if not exists region text;

do $$
declare
  owner uuid;
  ta uuid; tb uuid; tc uuid;
begin
  -- Owner: whoever owns the wedding trip; fall back to the admin account
  select owner_id into owner from wtn_trips where name ilike '%wedding%'
    order by (name like '%<3%') desc, created_at desc limit 1;
  if owner is null then
    select id into owner from wtn_profiles where email = 'ryan.ngo94@gmail.com';
  end if;
  if owner is null then raise exception 'No owner account found'; end if;

  -- ════════ TRIP A — Japan first, Korea after ════════
  insert into wtn_trips (owner_id,name,emoji,destination,country,destinations,start_date,end_date,currency,gradient_idx,notes)
  values (owner,'Guest Trip A — Japan → Korea 🇯🇵🇰🇷','🗼','Jeju','South Korea',
          '["Tokyo, Japan","Kyoto, Japan","Seoul, South Korea"]',
          '2027-05-15','2027-05-29','$',1,
          'Guest scenario A: a Japan week before the wedding, Korea week after. Land in Asia May 15; be on Jeju by May 19 (3 days before the big day).')
  returning id into ta;

  insert into wtn_stays (trip_id,name,type,check_in,check_out,address,cost,confirmed,notes,region) values
    (ta,'Shibuya area hotel (suggested)','Hotel','2027-05-15','2027-05-18','Shibuya, Tokyo',540,false,'Anything near the JR Yamanote loop works','Tokyo, Japan'),
    (ta,'Kyoto machiya or hotel (suggested)','Hotel','2027-05-18','2027-05-19','Gion / Kawaramachi, Kyoto',180,false,'One night — pack light','Kyoto, Japan'),
    (ta,'Yakmeul Resort (wedding block)','Resort','2027-05-19','2027-05-25','제주시 일주서로 6935, Jeju Island, South Korea',900,false,'The wedding resort — book with the group code','Jeju'),
    (ta,'Myeongdong hotel (suggested)','Hotel','2027-05-25','2027-05-29','Myeongdong, Seoul',560,false,null,'Seoul, South Korea');

  insert into wtn_flights (trip_id,from_airport,to_airport,airline,depart_date,depart_time,arrive_date,arrive_time,cost,confirmed,mode,notes) values
    (ta,'KIX','CJU',null,'2027-05-19','10:30','2027-05-19','12:15',120,false,'flight','Osaka → Jeju direct (or via ICN)'),
    (ta,'CJU','GMP',null,'2027-05-25','11:00','2027-05-25','12:10',60,false,'flight','Jeju → Seoul Gimpo');

  insert into wtn_events (trip_id,title,category,date,time,location,cost,confirmed,notes) values
    (ta,'Land in Tokyo ✈️ (arrive Asia)','transport','2027-05-15','15:00','HND/NRT, Tokyo',null,true,'One week before the wedding, as recommended'),
    (ta,'Shibuya Crossing + izakaya dinner','food','2027-05-15','19:00','Shibuya, Tokyo',30,false,null),
    (ta,'Senso-ji & Nakamise Street','sightseeing','2027-05-16','09:30','Asakusa, Tokyo',null,false,null),
    (ta,'teamLab Planets','activity','2027-05-16','14:00','Toyosu, Tokyo',28,false,'Book tickets ~2 weeks ahead'),
    (ta,'Shinjuku night: Omoide Yokocho','food','2027-05-16','19:30','Shinjuku, Tokyo',25,false,null),
    (ta,'Meiji Shrine + Harajuku','sightseeing','2027-05-17','10:00','Harajuku, Tokyo',null,false,null),
    (ta,'Golden Gai bar hop','activity','2027-05-17','20:00','Shinjuku, Tokyo',40,false,null),
    (ta,'Shinkansen to Kyoto 🚄','transport','2027-05-18','09:30','Tokyo → Kyoto',95,false,'~2h15m, reserve seats'),
    (ta,'Gion evening walk','sightseeing','2027-05-18','18:00','Gion, Kyoto',null,false,'Keep an eye out for geiko'),
    (ta,'Fushimi Inari at dawn','sightseeing','2027-05-19','06:30','Kyoto',null,false,'Beat the crowds — go EARLY'),
    (ta,'Jeju arrival + seafood dinner','food','2027-05-19','18:30','Jeju City',35,false,'Dongmun Market black pork alley'),
    (ta,'Seongsan Ilchulbong sunrise peak','sightseeing','2027-05-20','07:00','Jeju',5,false,null),
    (ta,'Welcome dinner with the families 🥂','food','2027-05-20','18:30','Jeju',null,true,null),
    (ta,'Beach + rest day (Hyeopjae)','activity','2027-05-21','11:00','Hyeopjae, Jeju',null,false,'Easy day before the wedding'),
    (ta,'Wedding ceremony 💍','other','2027-05-22','16:00','Yakmeul Resort, Jeju',null,true,'THE day — May 22, 2027'),
    (ta,'Reception dinner 🥂','food','2027-05-22','18:30','Jeju',null,true,null),
    (ta,'Recovery brunch ☕','food','2027-05-23','11:00','Jeju',20,false,null),
    (ta,'South coast loop: Cheonjeyeon Falls + Oedolgae','sightseeing','2027-05-23','14:00','Seogwipo, Jeju',null,false,null),
    (ta,'Udo Island by bike 🚲','activity','2027-05-24','10:00','Udo, Jeju',25,false,'Ferry from Seongsan port'),
    (ta,'N Seoul Tower at night','sightseeing','2027-05-25','19:30','Namsan, Seoul',12,false,null),
    (ta,'Gyeongbokgung in hanbok','activity','2027-05-26','10:00','Seoul',20,false,'Free palace entry in hanbok'),
    (ta,'Bukchon Hanok Village + Insadong tea','sightseeing','2027-05-26','14:00','Seoul',10,false,null),
    (ta,'Gwangjang Market food crawl','food','2027-05-27','12:00','Seoul',20,false,'Bindaetteok + mayak gimbap'),
    (ta,'Hongdae evening','activity','2027-05-27','19:00','Seoul',null,false,null),
    (ta,'Han River picnic + farewell KBBQ','food','2027-05-28','16:00','Seoul',40,false,null),
    (ta,'Fly home from ICN ✈️','transport','2027-05-29','12:00','Incheon, Seoul',null,true,null);

  -- ════════ TRIP B — Korea first, Japan after ════════
  insert into wtn_trips (owner_id,name,emoji,destination,country,destinations,start_date,end_date,currency,gradient_idx,notes)
  values (owner,'Guest Trip B — Korea → Japan 🇰🇷🇯🇵','🏯','Jeju','South Korea',
          '["Seoul, South Korea","Osaka, Japan","Kyoto, Japan","Tokyo, Japan"]',
          '2027-05-15','2027-05-30','$',3,
          'Guest scenario B: Korea week before the wedding (on Jeju 4 days early), Japan week after. Land in Asia May 15.')
  returning id into tb;

  insert into wtn_stays (trip_id,name,type,check_in,check_out,address,cost,confirmed,notes,region) values
    (tb,'Myeongdong hotel (suggested)','Hotel','2027-05-15','2027-05-18','Myeongdong, Seoul',420,false,null,'Seoul, South Korea'),
    (tb,'Yakmeul Resort (wedding block)','Resort','2027-05-18','2027-05-23','제주시 일주서로 6935, Jeju Island, South Korea',750,false,'The wedding resort — book with the group code','Jeju'),
    (tb,'Dotonbori hotel (suggested)','Hotel','2027-05-23','2027-05-26','Namba, Osaka',400,false,null,'Osaka, Japan'),
    (tb,'Kyoto hotel (suggested)','Hotel','2027-05-26','2027-05-28','Kawaramachi, Kyoto',300,false,null,'Kyoto, Japan'),
    (tb,'Shinjuku hotel (suggested)','Hotel','2027-05-28','2027-05-30','Shinjuku, Tokyo',380,false,null,'Tokyo, Japan');

  insert into wtn_flights (trip_id,from_airport,to_airport,airline,depart_date,depart_time,arrive_date,arrive_time,cost,confirmed,mode,notes) values
    (tb,'GMP','CJU',null,'2027-05-18','10:00','2027-05-18','11:10',60,false,'flight','Seoul Gimpo → Jeju'),
    (tb,'CJU','KIX',null,'2027-05-23','13:00','2027-05-23','14:40',130,false,'flight','Jeju → Osaka');

  insert into wtn_events (trip_id,title,category,date,time,location,cost,confirmed,notes) values
    (tb,'Land in Seoul ✈️ (arrive Asia)','transport','2027-05-15','15:00','ICN, Seoul',null,true,'One week before the wedding'),
    (tb,'Myeongdong street food night','food','2027-05-15','19:00','Seoul',20,false,null),
    (tb,'Gyeongbokgung in hanbok + Bukchon','sightseeing','2027-05-16','10:00','Seoul',20,false,null),
    (tb,'Insadong tea house + Cheonggyecheon walk','activity','2027-05-16','15:00','Seoul',10,false,null),
    (tb,'DMZ half-day tour','sightseeing','2027-05-17','08:00','Seoul',50,false,'Book ahead — passport required'),
    (tb,'Hongdae evening + noraebang','activity','2027-05-17','19:00','Seoul',25,false,'Karaoke!'),
    (tb,'Jeju: Dongmun Market dinner','food','2027-05-18','18:30','Jeju City',25,false,null),
    (tb,'East loop: Seongsan peak + Woljeongri Beach','sightseeing','2027-05-19','08:00','Jeju',5,false,null),
    (tb,'Udo Island by bike 🚲','activity','2027-05-20','10:00','Udo, Jeju',25,false,null),
    (tb,'Welcome dinner with the families 🥂','food','2027-05-20','18:30','Jeju',null,true,null),
    (tb,'Spa / jjimjilbang chill day','activity','2027-05-21','13:00','Jeju',15,false,'Rest up before the big day'),
    (tb,'Wedding ceremony 💍','other','2027-05-22','16:00','Yakmeul Resort, Jeju',null,true,'THE day — May 22, 2027'),
    (tb,'Reception dinner 🥂','food','2027-05-22','18:30','Jeju',null,true,null),
    (tb,'Recovery brunch ☕','food','2027-05-23','10:30','Jeju',20,false,null),
    (tb,'Dotonbori neon night + takoyaki','food','2027-05-23','19:30','Osaka',20,false,null),
    (tb,'Osaka Castle + Kuromon Market','sightseeing','2027-05-24','10:00','Osaka',15,false,null),
    (tb,'Umeda Sky Building sunset','sightseeing','2027-05-24','18:00','Osaka',12,false,null),
    (tb,'Nara day trip: deer park + Todai-ji','sightseeing','2027-05-25','09:30','Nara',15,false,'Deer crackers ¥200'),
    (tb,'Train to Kyoto + Gion evening','sightseeing','2027-05-26','16:00','Gion, Kyoto',null,false,null),
    (tb,'Fushimi Inari at dawn + Arashiyama bamboo','sightseeing','2027-05-27','06:30','Kyoto',null,false,null),
    (tb,'Kinkaku-ji (Golden Pavilion)','sightseeing','2027-05-27','14:00','Kyoto',5,false,null),
    (tb,'Shinkansen to Tokyo 🚄 + Shibuya night','transport','2027-05-28','10:00','Kyoto → Tokyo',95,false,null),
    (tb,'Senso-ji + Akihabara + farewell izakaya','activity','2027-05-29','10:00','Tokyo',40,false,null),
    (tb,'Fly home from HND/NRT ✈️','transport','2027-05-30','12:00','Tokyo',null,true,null);

  -- ════════ TRIP C — All Korea ════════
  insert into wtn_trips (owner_id,name,emoji,destination,country,destinations,start_date,end_date,currency,gradient_idx,notes)
  values (owner,'Guest Trip C — All Korea 🇰🇷','🌺','Jeju','South Korea',
          '["Seoul, South Korea","Busan, South Korea"]',
          '2027-05-15','2027-05-29','$',5,
          'Guest scenario C: the whole two weeks in Korea — Seoul, Busan, then Jeju 2 days before the wedding, and back to Seoul after.')
  returning id into tc;

  insert into wtn_stays (trip_id,name,type,check_in,check_out,address,cost,confirmed,notes,region) values
    (tc,'Myeongdong hotel (suggested)','Hotel','2027-05-15','2027-05-18','Myeongdong, Seoul',420,false,null,'Seoul, South Korea'),
    (tc,'Haeundae beachfront hotel (suggested)','Hotel','2027-05-18','2027-05-20','Haeundae, Busan',260,false,null,'Busan, South Korea'),
    (tc,'Yakmeul Resort (wedding block)','Resort','2027-05-20','2027-05-25','제주시 일주서로 6935, Jeju Island, South Korea',750,false,'The wedding resort — book with the group code','Jeju'),
    (tc,'Insadong hotel (suggested)','Hotel','2027-05-25','2027-05-29','Insadong, Seoul',520,false,null,'Seoul, South Korea');

  insert into wtn_flights (trip_id,from_airport,to_airport,airline,depart_date,depart_time,arrive_date,arrive_time,cost,confirmed,mode,notes) values
    (tc,'Seoul','Busan',null,'2027-05-18','09:00','2027-05-18','11:40',50,false,'train','KTX from Seoul Station — book seats ahead'),
    (tc,'PUS','CJU',null,'2027-05-20','10:30','2027-05-20','11:30',55,false,'flight','Busan → Jeju'),
    (tc,'CJU','GMP',null,'2027-05-25','11:00','2027-05-25','12:10',60,false,'flight','Jeju → Seoul Gimpo');

  insert into wtn_events (trip_id,title,category,date,time,location,cost,confirmed,notes) values
    (tc,'Land in Seoul ✈️ (arrive Asia)','transport','2027-05-15','15:00','ICN, Seoul',null,true,'One week before the wedding'),
    (tc,'Myeongdong street food night','food','2027-05-15','19:00','Seoul',20,false,null),
    (tc,'Gyeongbokgung in hanbok + Bukchon','sightseeing','2027-05-16','10:00','Seoul',20,false,null),
    (tc,'N Seoul Tower sunset','sightseeing','2027-05-16','18:00','Namsan, Seoul',12,false,null),
    (tc,'Gwangjang Market food crawl + Hongdae','food','2027-05-17','12:00','Seoul',25,false,null),
    (tc,'Haeundae Beach evening','activity','2027-05-18','17:00','Busan',null,false,null),
    (tc,'Gamcheon Culture Village','sightseeing','2027-05-19','10:00','Busan',null,false,'Rainbow hillside village — wear walking shoes'),
    (tc,'Jagalchi Fish Market lunch','food','2027-05-19','13:00','Busan',30,false,'Pick it downstairs, eat it upstairs'),
    (tc,'Haedong Yonggungsa seaside temple','sightseeing','2027-05-19','16:00','Busan',null,false,null),
    (tc,'Jeju: Dongmun Market dinner','food','2027-05-20','18:30','Jeju City',25,false,null),
    (tc,'East loop: Seongsan peak + Udo Island','sightseeing','2027-05-21','08:00','Jeju',30,false,null),
    (tc,'Rehearsal dinner 🥂','food','2027-05-21','18:30','Jeju',null,true,null),
    (tc,'Wedding ceremony 💍','other','2027-05-22','16:00','Yakmeul Resort, Jeju',null,true,'THE day — May 22, 2027'),
    (tc,'Reception dinner 🥂','food','2027-05-22','18:30','Jeju',null,true,null),
    (tc,'Recovery brunch + O''sulloc tea fields','food','2027-05-23','11:00','Jeju',25,false,null),
    (tc,'Hyeopjae Beach afternoon','activity','2027-05-23','14:30','Jeju',null,false,null),
    (tc,'Hallasan hike (Yeongsil trail) or waterfalls loop','activity','2027-05-24','08:00','Jeju',null,false,'Cheonjeyeon Falls + Oedolgae for the easy option'),
    (tc,'Back in Seoul: Insadong evening','sightseeing','2027-05-25','17:00','Seoul',null,false,null),
    (tc,'DMZ half-day tour','sightseeing','2027-05-26','08:00','Seoul',50,false,'Passport required'),
    (tc,'Korean BBQ night in Mapo','food','2027-05-26','19:00','Seoul',35,false,null),
    (tc,'Shopping: Myeongdong + Gangnam','shopping','2027-05-27','13:00','Seoul',60,false,null),
    (tc,'Han River picnic + farewell dinner','food','2027-05-28','16:00','Seoul',40,false,null),
    (tc,'Fly home from ICN ✈️','transport','2027-05-29','12:00','Incheon, Seoul',null,true,null);

  raise notice 'Created guest scenarios A(%), B(%), C(%)', ta, tb, tc;
end $$;
