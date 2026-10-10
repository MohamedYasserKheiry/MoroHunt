-- =====================================================================
-- MoroHunt (قناص المغرب) — Initial Database Migration
-- Supabase / PostgreSQL + PostGIS
-- =====================================================================

create extension if not exists postgis;
create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------
-- 1. PROFILES
-- ---------------------------------------------------------------------
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    username text not null unique,
    avatar_url text,
    gender text check (gender in ('male', 'female')),
    city text,
    birthdate date,
    rank_points int default 0 not null,
    perdrix_count int default 0 not null,
    lievre_count int default 0 not null,
    sanglier_count int default 0 not null,
    caille_count int default 0 not null,
    tourtereau_count int default 0 not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ---------------------------------------------------------------------
-- 2. DOGS
-- ---------------------------------------------------------------------
create table public.dogs (
    id uuid default gen_random_uuid() primary key,
    owner_id uuid references public.profiles(id) on delete cascade not null,
    dog_name text not null,
    breed text,
    avatar_url text,
    total_distance_km double precision default 0.0 not null,
    avg_speed_kmh double precision default 0.0 not null,
    dog_points int default 0 not null,
    imei_gps_tracker text unique,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ---------------------------------------------------------------------
-- 3. MAP ZONES (GeoJSON polygons: permitted / forbidden)
--    Created before hunt_sessions since hunt_sessions references it.
-- ---------------------------------------------------------------------
create table public.map_zones (
    id uuid default gen_random_uuid() primary key,
    zone_name text not null,
    zone_type text not null check (zone_type in ('permitted', 'forbidden')),
    geom geometry(Polygon, 4326) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ---------------------------------------------------------------------
-- 4. HUNT SESSIONS (Active Rooms)
-- ---------------------------------------------------------------------
create table public.hunt_sessions (
    id uuid default gen_random_uuid() primary key,
    creator_id uuid references public.profiles(id) on delete cascade not null,
    room_code text not null unique,
    zone_id uuid references public.map_zones(id),
    is_active boolean default true not null,
    ended_at timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ---------------------------------------------------------------------
-- 5. SESSION PARTICIPANTS (who joined which room)
-- ---------------------------------------------------------------------
create table public.session_participants (
    session_id uuid references public.hunt_sessions(id) on delete cascade not null,
    user_id uuid references public.profiles(id) on delete cascade not null,
    dog_id uuid references public.dogs(id) on delete set null,
    joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (session_id, user_id)
);

-- ---------------------------------------------------------------------
-- 6. LIVE LOCATIONS (WebSocket / Realtime tracking)
-- ---------------------------------------------------------------------
create table public.live_locations (
    id uuid default gen_random_uuid() primary key,
    session_id uuid references public.hunt_sessions(id) on delete cascade not null,
    user_id uuid references public.profiles(id) on delete cascade not null,
    geom geometry(Point, 4326) not null,
    speed_kmh double precision default 0.0,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(session_id, user_id)
);

-- ---------------------------------------------------------------------
-- 7. CATCHES (طوثيق / Catch log)
-- ---------------------------------------------------------------------
create table public.catches (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references public.profiles(id) on delete cascade not null,
    session_id uuid references public.hunt_sessions(id) on delete set null,
    prey_type text not null check (prey_type in ('perdrix', 'lievre', 'sanglier', 'caille', 'tourtereau')),
    image_url text not null,
    geom geometry(Point, 4326) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ---------------------------------------------------------------------
-- INDEXES
-- ---------------------------------------------------------------------
create index if not exists idx_live_locations_geom on public.live_locations using gist(geom);
create index if not exists idx_catches_geom on public.catches using gist(geom);
create index if not exists idx_map_zones_geom on public.map_zones using gist(geom);
create index if not exists idx_dogs_owner on public.dogs(owner_id);
create index if not exists idx_catches_user on public.catches(user_id);
create index if not exists idx_sessions_room_code on public.hunt_sessions(room_code);

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.dogs enable row level security;
alter table public.hunt_sessions enable row level security;
alter table public.session_participants enable row level security;
alter table public.live_locations enable row level security;
alter table public.catches enable row level security;
alter table public.map_zones enable row level security;

create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);

-- ---------------------------------------------------------------------
-- AUTO-CREATE PROFILE ON SIGN-UP
-- Populates username/gender/city/birthdate straight from the `data:`
-- map passed to supabase.auth.signUp on the client, so the app never
-- needs a separate "create my profile" round trip after registering.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, username, gender, city, birthdate)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
        nullif(new.raw_user_meta_data->>'gender', ''),
        nullif(new.raw_user_meta_data->>'city', ''),
        nullif(new.raw_user_meta_data->>'birthdate', '')::date
    )
    on conflict (id) do update set
        username = excluded.username,
        gender = coalesce(excluded.gender, public.profiles.gender),
        city = coalesce(excluded.city, public.profiles.city),
        birthdate = coalesce(excluded.birthdate, public.profiles.birthdate);
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

create policy "dogs_select_all" on public.dogs for select using (true);
create policy "dogs_insert_own" on public.dogs for insert with check (auth.uid() = owner_id);
create policy "dogs_update_own" on public.dogs for update using (auth.uid() = owner_id);
create policy "dogs_delete_own" on public.dogs for delete using (auth.uid() = owner_id);

create policy "sessions_select_all" on public.hunt_sessions for select using (true);
create policy "sessions_insert_own" on public.hunt_sessions for insert with check (auth.uid() = creator_id);
create policy "sessions_update_creator" on public.hunt_sessions for update using (auth.uid() = creator_id);

create policy "participants_select_all" on public.session_participants for select using (true);
create policy "participants_insert_self" on public.session_participants for insert with check (auth.uid() = user_id);

create policy "locations_select_session_members" on public.live_locations for select
    using (
        exists (
            select 1 from public.session_participants sp
            where sp.session_id = live_locations.session_id
              and sp.user_id = auth.uid()
        )
    );
create policy "locations_upsert_own" on public.live_locations for insert with check (auth.uid() = user_id);
create policy "locations_update_own" on public.live_locations for update using (auth.uid() = user_id);

create policy "catches_select_all" on public.catches for select using (true);
create policy "catches_insert_own" on public.catches for insert with check (auth.uid() = user_id);
create policy "catches_delete_own" on public.catches for delete using (auth.uid() = user_id);

create policy "map_zones_select_all" on public.map_zones for select using (true);

-- ---------------------------------------------------------------------
-- FUNCTIONS: automatic dog score + rank points
-- ---------------------------------------------------------------------

-- Dog score formula: (TotalDistanceKM * 10) + (AvgSpeedKMH * 5)
create or replace function public.calculate_dog_score(distance_km double precision, avg_speed_kmh double precision)
returns int
language sql
immutable
as $$
    select round((distance_km * 10) + (avg_speed_kmh * 5))::int;
$$;

create or replace function public.trg_update_dog_points()
returns trigger
language plpgsql
as $$
begin
    new.dog_points := public.calculate_dog_score(new.total_distance_km, new.avg_speed_kmh);
    new.updated_at := timezone('utc'::text, now());
    return new;
end;
$$;

create trigger dogs_before_update
    before update of total_distance_km, avg_speed_kmh on public.dogs
    for each row execute function public.trg_update_dog_points();

create or replace function public.trg_increment_prey_counter()
returns trigger
language plpgsql
as $$
begin
    update public.profiles
    set
        perdrix_count = perdrix_count + (case when new.prey_type = 'perdrix' then 1 else 0 end),
        lievre_count = lievre_count + (case when new.prey_type = 'lievre' then 1 else 0 end),
        sanglier_count = sanglier_count + (case when new.prey_type = 'sanglier' then 1 else 0 end),
        caille_count = caille_count + (case when new.prey_type = 'caille' then 1 else 0 end),
        tourtereau_count = tourtereau_count + (case when new.prey_type = 'tourtereau' then 1 else 0 end)
    where id = new.user_id;
    return new;
end;
$$;

create trigger catches_after_insert
    after insert on public.catches
    for each row execute function public.trg_increment_prey_counter();

create or replace function public.award_rank_points(p_user_id uuid, p_points int)
returns void
language sql
as $$
    update public.profiles set rank_points = rank_points + p_points where id = p_user_id;
$$;

-- ---------------------------------------------------------------------
-- VIEW: Dog of the Month (highest dog_points overall — filter by month
-- in the app query layer using dogs.updated_at if you want a rolling window)
-- ---------------------------------------------------------------------
create or replace view public.dog_of_the_month as
select d.*
from public.dogs d
order by d.dog_points desc
limit 1;

-- ---------------------------------------------------------------------
-- STORAGE BUCKET
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('catches_photos', 'catches_photos', true)
on conflict (id) do nothing;

create policy "catches_photos_public_read" on storage.objects
    for select using (bucket_id = 'catches_photos');

create policy "catches_photos_auth_upload" on storage.objects
    for insert with check (bucket_id = 'catches_photos' and auth.role() = 'authenticated');
