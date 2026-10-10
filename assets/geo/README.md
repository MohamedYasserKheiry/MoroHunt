# Reserve / Amodiation GeoJSON assets

These two files back the محميات (reserve) and مكري (amodiation) layers
on the map screen (`lib/screens/map_screen.dart`, loaded through
`GeoReserveService` / `lib/providers/reserve_layers_provider.dart`).

| File                          | Source layer     | Category   | Features |
|--------------------------------|-------------------|------------|----------|
| `JEU_RESERVE.geojson`          | Protected reserves | محميات (reserve)   | 354  |
| `AMODIATIONS_part1.geojson`    | Leased grounds      | مكري (amodiation)  | 1,815 |

## Why these aren't the original files

The original uploads were **117MB combined** (~2.9M coordinate
points, some rings 60k+ points long) — far too large to bundle as
Flutter assets or parse smoothly on a phone. They were simplified with
a Douglas-Peucker line-simplification pass (tolerance ≈ 0.0008°, ~90m)
plus coordinate rounding to 5 decimal places (~1.1m precision):

| File                        | Before  | After   | Points kept |
|------------------------------|---------|---------|-------------|
| `JEU_RESERVE.geojson`        | 47.4 MB | 1.40 MB | 5.7%        |
| `AMODIATIONS_part1.geojson`  | 70.2 MB | 1.95 MB | 5.1%        |

Every feature and every `properties` field was preserved — only the
polygon vertex density was reduced. Perimeter length is retained to
within ~1-4% of the original on spot-checked features, which is well
within what's visually distinguishable on a mobile map.

If you receive updated source files with more precision than the app
actually needs, re-run the same kind of simplification before
re-bundling — don't drop the raw files in as-is, or you'll reintroduce
the original size/performance problem.
