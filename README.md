# MoroHunt (قناص المغرب)

Foundational structural code for a Flutter + Supabase mobile app for
Morocco's hunting community: offline-first zone mapping, real-time team
tracking, dog performance scoring, and a community catch map with
gamified ranks.

## Project layout

```
morohunt/
├── pubspec.yaml
├── supabase/
│   └── migrations/
│       └── 0001_init.sql        # PostGIS schema, RLS, triggers, storage bucket
└── lib/
    ├── main.dart                 # App entry point / navigation shell
    ├── models/
    │   ├── hunter_profile.dart   # profiles + rank tiers (Bronze→Diamond)
    │   ├── hunting_dog.dart      # dogs + dog-score formula
    │   ├── map_zone.dart         # permitted/forbidden polygons + point-in-polygon
    │   └── hunt_catch.dart       # catches, hunt_sessions, live positions
    ├── services/
    │   ├── supabase_service.dart # rooms, realtime, uploads, dog score sync
    │   └── zone_check_service.dart # offline zone cache + local warnings
    ├── screens/
    │   ├── map_screen.dart       # offline tiles, zone overlay, live tracking
    │   └── profile_screen.dart   # badges, prey counter, dog of the month
    └── widgets/
        ├── rank_badge.dart       # gold glow / diamond aura badge
        ├── prey_counter.dart     # 5-species catch grid
        └── dog_of_the_month_card.dart
```

## Getting started

1. **Supabase project**
   - Create a project, enable the PostGIS extension is handled by the
     migration itself.
   - Run `supabase/migrations/0001_init.sql` via the SQL editor or
     `supabase db push`.
   - Confirm the `catches_photos` storage bucket was created (public read).

2. **Flutter app**
   - `flutter pub get`
   - Set your Supabase URL/anon key and Mapbox access token:
     - Replace the placeholders in `lib/main.dart`, or better, wire them
       through `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
     - Add your Mapbox token to `android/gradle.properties` /
       `ios/Runner/Info.plist` per `mapbox_maps_flutter` setup docs.
   - `flutter run`

3. **Auth**
   - `_SignInPlaceholder` in `main.dart` is a stub — wire up
     `supabase_flutter`'s email/OTP or OAuth screens there.

## Notes on the "single formula, no shortcuts" pieces

- **Dog score**: implemented both server-side (Postgres trigger,
  `calculate_dog_score`) and mirrored client-side
  (`HuntingDog.calculateScore`) so the UI can preview it before syncing.
- **Offline zone check**: `ZoneCheckService` caches the `map_zones`
  GeoJSON to local disk and runs a pure-Dart ray-casting
  point-in-polygon test — no network call needed once cached.
- **Live tracking**: `SupabaseService.startBroadcastingLocation` pushes
  a position every 10 seconds via `upsert`, and `subscribeToRoom` uses
  Supabase Realtime Postgres Changes over WebSockets to keep every
  client's map in sync.

## What's stubbed / left for you to finish

- Real auth UI (sign-up/sign-in screens).
- Server-side (Edge Function) re-validation of "legal session in a
  permitted zone" before awarding the +50 rank points, so a client can't
  self-report a fake location.
- Community voting flow for the +100 environmental cleanup points.
- Mapbox custom pin icons (`hunter-pin`) need to be registered with the
  style before `iconImage: 'hunter-pin'` will render.
