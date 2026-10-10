-- =====================================================================
-- MoroHunt — Migration 0009: Hunting Zones Layer Control
--
-- The "Map Layers Filter" panel needs three independent zone
-- categories instead of the old permitted/forbidden pair, plus a new
-- points-of-interest (Repères) table for the markers layer. Both are
-- exposed as GeoJSON-ready views so the Flutter client can select
-- ready-to-parse `geometry` JSON instead of hand-rolling EWKB parsing
-- for polygons (which — unlike the single-point EWKB parser already
-- in lib/utils/ewkb_parser.dart — would need full ring/hole handling).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. RE-CATEGORIZE map_zones: permitted/forbidden -> reserve/amodie/open
-- ---------------------------------------------------------------------
alter table public.map_zones drop constraint if exists map_zones_zone_type_check;

-- Best-effort migration of any existing rows: previously "forbidden"
-- zones map to the new "reserve" (protected) category; previously
-- "permitted" zones map to "open" (no leased zones existed before,
-- so none become "amodie" automatically — re-tag those manually).
update public.map_zones set zone_type = 'reserve' where zone_type = 'forbidden';
update public.map_zones set zone_type = 'open' where zone_type = 'permitted';

alter table public.map_zones rename column zone_type to category;
alter table public.map_zones
    add constraint map_zones_category_check
    check (category in ('reserve', 'amodie', 'open'));

comment on column public.map_zones.category is
    'reserve = محمية/forbidden (red), amodie = مكري/leased (blue), open = مفتوحة (yellow/green)';

-- ---------------------------------------------------------------------
-- 2. map_zones as ready-to-consume GeoJSON (id, name, category, geometry)
--    RLS on the underlying table still applies to the view's rows.
-- ---------------------------------------------------------------------
create or replace view public.map_zones_geojson as
select
    id,
    zone_name,
    category,
    st_asgeojson(geom)::json as geometry
from public.map_zones;

grant select on public.map_zones_geojson to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. MAP POIs (Repères / معالم) — landmarks layer: water points, camps,
--    parking, warden posts, etc. Rendered as a MarkerLayer, not polygons.
-- ---------------------------------------------------------------------
create table public.map_pois (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    poi_type text not null default 'landmark'
        check (poi_type in ('landmark', 'water_point', 'camp', 'parking', 'warden_post')),
    geom geometry(Point, 4326) not null,
    created_by uuid references public.profiles(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_map_pois_geom on public.map_pois using gist(geom);

alter table public.map_pois enable row level security;

create policy "map_pois_select_all" on public.map_pois for select using (true);

create policy "map_pois_insert_authenticated" on public.map_pois
    for insert with check (auth.uid() = created_by);

create or replace view public.map_pois_geojson as
select
    id,
    name,
    poi_type,
    st_asgeojson(geom)::json as geometry
from public.map_pois;

grant select on public.map_pois_geojson to anon, authenticated;
