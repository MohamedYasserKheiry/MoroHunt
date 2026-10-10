-- =====================================================================
-- MoroHunt — OPTIONAL sample hunting-zone data for local dev/testing
--
-- This file is NEVER read by the Flutter app — `huntingZonesProvider`
-- always queries `map_zones_geojson` directly and shows nothing if
-- the table is empty (see lib/providers/map_layers_provider.dart).
-- Run this manually only if you want sample polygons to look at while
-- testing the Layer Filter panel locally.
--
-- Six sample zones spread across Morocco (2 per category) plus 4 POIs.
-- Safe to re-run: every row uses a fixed id + "on conflict do nothing".
--
-- Run with: supabase db reset   (auto-runs supabase/seed.sql)
-- or manually: psql "$DATABASE_URL" -f supabase/seed.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- RÉSERVE / محميات (red) — protected, hunting forbidden
-- ---------------------------------------------------------------------
insert into public.map_zones (id, zone_name, category, geom) values
(
    'a1111111-1111-4111-8111-111111111101',
    'محمية الأرز - إفران',                 -- Ifrane cedar forest reserve
    'reserve',
    st_geomfromtext(
        'POLYGON((-5.20 33.35, -4.95 33.35, -4.95 33.60, -5.20 33.60, -5.20 33.35))',
        4326
    )
),
(
    'a1111111-1111-4111-8111-111111111102',
    'محمية سوس ماسة',                       -- Souss-Massa nature reserve
    'reserve',
    st_geomfromtext(
        'POLYGON((-9.75 30.10, -9.50 30.10, -9.50 30.35, -9.75 30.35, -9.75 30.10))',
        4326
    )
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- AMODIÉ / مكري (blue) — privately leased hunting grounds
-- ---------------------------------------------------------------------
insert into public.map_zones (id, zone_name, category, geom) values
(
    'a1111111-1111-4111-8111-111111111103',
    'أرض مكرية - خنيفرة',                   -- Khenifra leased ground
    'amodie',
    st_geomfromtext(
        'POLYGON((-5.85 32.85, -5.55 32.85, -5.55 33.10, -5.85 33.10, -5.85 32.85))',
        4326
    )
),
(
    'a1111111-1111-4111-8111-111111111104',
    'أرض مكرية - بني ملال',                 -- Béni Mellal leased ground
    'amodie',
    st_geomfromtext(
        'POLYGON((-6.55 32.10, -6.25 32.10, -6.25 32.35, -6.55 32.35, -6.55 32.10))',
        4326
    )
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- ZONES OUVERTES / مفتوحة (yellow/green) — open to any licensed hunter
-- ---------------------------------------------------------------------
insert into public.map_zones (id, zone_name, category, geom) values
(
    'a1111111-1111-4111-8111-111111111105',
    'منطقة مفتوحة - الحوز مراكش',           -- Haouz plain near Marrakech
    'open',
    st_geomfromtext(
        'POLYGON((-8.15 31.45, -7.85 31.45, -7.85 31.70, -8.15 31.70, -8.15 31.45))',
        4326
    )
),
(
    'a1111111-1111-4111-8111-111111111106',
    'منطقة مفتوحة - الزعير الرباط',         -- Zaer plateau near Rabat
    'open',
    st_geomfromtext(
        'POLYGON((-6.95 33.75, -6.65 33.75, -6.65 34.00, -6.95 34.00, -6.95 33.75))',
        4326
    )
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- REPÈRES / معالم — sample POI markers
-- ---------------------------------------------------------------------
insert into public.map_pois (id, name, poi_type, geom) values
(
    'b2222222-2222-4222-8222-222222222201',
    'نقطة ماء - إفران',
    'water_point',
    st_geomfromtext('POINT(-5.08 33.48)', 4326)
),
(
    'b2222222-2222-4222-8222-222222222202',
    'مخيم - مراكش',
    'camp',
    st_geomfromtext('POINT(-8.00 31.58)', 4326)
),
(
    'b2222222-2222-4222-8222-222222222203',
    'موقف السيارات - الرباط',
    'parking',
    st_geomfromtext('POINT(-6.80 33.88)', 4326)
),
(
    'b2222222-2222-4222-8222-222222222204',
    'مركز حراسة - بني ملال',
    'warden_post',
    st_geomfromtext('POINT(-6.40 32.22)', 4326)
)
on conflict (id) do nothing;
