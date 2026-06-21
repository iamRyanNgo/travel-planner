-- WhereToNext — Supabase schema (single file, ordered to avoid forward references)
-- Run in: Supabase Dashboard → SQL Editor

-- ── Profiles ─────────────────────────────────────────────────
create table if not exists wtn_profiles (
  id      uuid references auth.users on delete cascade primary key,
  email   text unique not null,
  name    text,
  picture text,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);
alter table wtn_profiles enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_profiles_self' and tablename='wtn_profiles') then
    create policy wtn_profiles_self on wtn_profiles for all using (id = auth.uid()) with check (id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_profiles_admin_select' and tablename='wtn_profiles') then
    create policy wtn_profiles_admin_select on wtn_profiles for select using (
      exists (select 1 from wtn_profiles p where p.id = auth.uid() and p.email = 'ryan.ngo94@gmail.com')
    );
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_profiles_admin_update' and tablename='wtn_profiles') then
    create policy wtn_profiles_admin_update on wtn_profiles for update using (
      exists (select 1 from wtn_profiles p where p.id = auth.uid() and p.email = 'ryan.ngo94@gmail.com')
    );
  end if;
end $$;

-- Trigger: auto-create profile on sign-up
create or replace function wtn_handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into wtn_profiles (id, email, name, picture, approved)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url',
    new.email = 'ryan.ngo94@gmail.com'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists wtn_on_auth_user_created on auth.users;
create trigger wtn_on_auth_user_created
  after insert on auth.users
  for each row execute procedure wtn_handle_new_user();

-- ── Access requests ───────────────────────────────────────────
create table if not exists wtn_access_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references wtn_profiles(id) on delete cascade not null,
  message text default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz
);
alter table wtn_access_requests enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_req_self' and tablename='wtn_access_requests') then
    create policy wtn_req_self on wtn_access_requests for all using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_req_admin' and tablename='wtn_access_requests') then
    create policy wtn_req_admin on wtn_access_requests for all using (
      exists (select 1 from wtn_profiles p where p.id = auth.uid() and p.email = 'ryan.ngo94@gmail.com')
    );
  end if;
end $$;

-- ── Trips ─────────────────────────────────────────────────────
create table if not exists wtn_trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references wtn_profiles(id) on delete cascade not null,
  name text not null,
  emoji text default '🌍',
  destination text default '',
  country text default '',
  start_date date,
  end_date date,
  currency text default '$',
  gradient_idx int default 0,
  travelers jsonb default '[]',
  notes text default '',
  emergency_contacts text default '',
  created_at timestamptz not null default now()
);
alter table wtn_trips enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_trips_owner' and tablename='wtn_trips') then
    create policy wtn_trips_owner on wtn_trips for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
  end if;
end $$;

-- ── Trip members ──────────────────────────────────────────────
create table if not exists wtn_trip_members (
  trip_id    uuid references wtn_trips(id) on delete cascade,
  user_id    uuid references wtn_profiles(id) on delete cascade,
  role       text not null default 'editor' check (role in ('editor','viewer')),
  invited_by uuid references wtn_profiles(id),
  joined_at  timestamptz not null default now(),
  primary key (trip_id, user_id)
);
alter table wtn_trip_members enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_members_owner' and tablename='wtn_trip_members') then
    create policy wtn_members_owner on wtn_trip_members for all using (
      exists (select 1 from wtn_trips t where t.id = trip_id and t.owner_id = auth.uid())
    );
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_members_read' and tablename='wtn_trip_members') then
    -- wtn_can_read is SECURITY DEFINER so it bypasses RLS — no infinite recursion.
    -- Do NOT use a sub-SELECT on wtn_trip_members here; that causes infinite recursion
    -- when wtn_profiles_member_read joins this table.
    create policy wtn_members_read on wtn_trip_members for select using (
      user_id = auth.uid() or
      wtn_can_read(trip_id)
    );
  end if;
end $$;

-- ── Trip policies that reference wtn_trip_members (added after table exists) ──
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_trips_member_read' and tablename='wtn_trips') then
    create policy wtn_trips_member_read on wtn_trips for select using (
      exists (select 1 from wtn_trip_members m where m.trip_id = id and m.user_id = auth.uid())
    );
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_trips_editor_update' and tablename='wtn_trips') then
    create policy wtn_trips_editor_update on wtn_trips for update using (
      exists (select 1 from wtn_trip_members m where m.trip_id = id and m.user_id = auth.uid() and m.role = 'editor')
    );
  end if;
  -- Profile visibility across shared trips
  if not exists (select 1 from pg_policies where policyname='wtn_profiles_member_read' and tablename='wtn_profiles') then
    create policy wtn_profiles_member_read on wtn_profiles for select using (
      exists (
        select 1 from wtn_trip_members a
        join wtn_trip_members b on b.trip_id = a.trip_id
        where a.user_id = auth.uid() and b.user_id = id
      )
    );
  end if;
end $$;

-- ── RLS helper functions ──────────────────────────────────────
create or replace function wtn_can_read(trip uuid) returns boolean
language sql security definer as $$
  select exists (
    select 1 from wtn_trips t where t.id = trip and (
      t.owner_id = auth.uid() or
      exists (select 1 from wtn_trip_members m where m.trip_id = t.id and m.user_id = auth.uid())
    )
  )
$$;

create or replace function wtn_can_write(trip uuid) returns boolean
language sql security definer as $$
  select exists (
    select 1 from wtn_trips t where t.id = trip and (
      t.owner_id = auth.uid() or
      exists (select 1 from wtn_trip_members m where m.trip_id = t.id and m.user_id = auth.uid() and m.role = 'editor')
    )
  )
$$;

-- ── Events ────────────────────────────────────────────────────
create table if not exists wtn_events (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references wtn_trips(id) on delete cascade not null,
  title text not null,
  category text default 'activity',
  date date,
  time text,
  duration int,
  location text,
  address text,
  cost numeric,
  currency text,
  confirmed boolean default false,
  confirm_num text,
  url text,
  notes text,
  created_at timestamptz default now()
);
alter table wtn_events enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_events_r' and tablename='wtn_events') then
    create policy wtn_events_r on wtn_events for select using (wtn_can_read(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_events_i' and tablename='wtn_events') then
    create policy wtn_events_i on wtn_events for insert with check (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_events_u' and tablename='wtn_events') then
    create policy wtn_events_u on wtn_events for update using (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_events_d' and tablename='wtn_events') then
    create policy wtn_events_d on wtn_events for delete using (wtn_can_write(trip_id));
  end if;
end $$;

-- ── Flights ───────────────────────────────────────────────────
create table if not exists wtn_flights (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references wtn_trips(id) on delete cascade not null,
  from_airport text, to_airport text, airline text, flight_num text,
  depart_date date, depart_time text, arrive_date date, arrive_time text,
  seat text, terminal text, confirm_num text, cost numeric,
  confirmed boolean default false, notes text,
  created_at timestamptz default now()
);
alter table wtn_flights enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_flights_r' and tablename='wtn_flights') then
    create policy wtn_flights_r on wtn_flights for select using (wtn_can_read(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_flights_i' and tablename='wtn_flights') then
    create policy wtn_flights_i on wtn_flights for insert with check (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_flights_u' and tablename='wtn_flights') then
    create policy wtn_flights_u on wtn_flights for update using (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_flights_d' and tablename='wtn_flights') then
    create policy wtn_flights_d on wtn_flights for delete using (wtn_can_write(trip_id));
  end if;
end $$;

-- ── Stays ─────────────────────────────────────────────────────
create table if not exists wtn_stays (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references wtn_trips(id) on delete cascade not null,
  name text not null, type text default 'Hotel',
  check_in date, check_in_time text, check_out date, check_out_time text,
  address text, confirm_num text, phone text, cost numeric,
  confirmed boolean default false, notes text,
  created_at timestamptz default now()
);
alter table wtn_stays enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_stays_r' and tablename='wtn_stays') then
    create policy wtn_stays_r on wtn_stays for select using (wtn_can_read(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_stays_i' and tablename='wtn_stays') then
    create policy wtn_stays_i on wtn_stays for insert with check (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_stays_u' and tablename='wtn_stays') then
    create policy wtn_stays_u on wtn_stays for update using (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_stays_d' and tablename='wtn_stays') then
    create policy wtn_stays_d on wtn_stays for delete using (wtn_can_write(trip_id));
  end if;
end $$;

-- ── Packing items ─────────────────────────────────────────────
create table if not exists wtn_pack_items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references wtn_trips(id) on delete cascade not null,
  name text not null, category text default 'Misc',
  qty int default 1, notes text, packed boolean default false,
  created_at timestamptz default now()
);
alter table wtn_pack_items enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_pack_r' and tablename='wtn_pack_items') then
    create policy wtn_pack_r on wtn_pack_items for select using (wtn_can_read(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_pack_i' and tablename='wtn_pack_items') then
    create policy wtn_pack_i on wtn_pack_items for insert with check (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_pack_u' and tablename='wtn_pack_items') then
    create policy wtn_pack_u on wtn_pack_items for update using (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_pack_d' and tablename='wtn_pack_items') then
    create policy wtn_pack_d on wtn_pack_items for delete using (wtn_can_write(trip_id));
  end if;
end $$;

-- ── Budget items ──────────────────────────────────────────────
create table if not exists wtn_budget_items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references wtn_trips(id) on delete cascade not null,
  name text not null, category text default 'Misc',
  planned numeric default 0, actual numeric default 0, notes text,
  created_at timestamptz default now()
);
alter table wtn_budget_items enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wtn_budget_r' and tablename='wtn_budget_items') then
    create policy wtn_budget_r on wtn_budget_items for select using (wtn_can_read(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_budget_i' and tablename='wtn_budget_items') then
    create policy wtn_budget_i on wtn_budget_items for insert with check (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_budget_u' and tablename='wtn_budget_items') then
    create policy wtn_budget_u on wtn_budget_items for update using (wtn_can_write(trip_id));
  end if;
  if not exists (select 1 from pg_policies where policyname='wtn_budget_d' and tablename='wtn_budget_items') then
    create policy wtn_budget_d on wtn_budget_items for delete using (wtn_can_write(trip_id));
  end if;
end $$;
