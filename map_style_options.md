# Map style options — hiding POIs / commercial labels

## What changed

`map_screen.dart`'s `_standardTileUrl` now points at CARTO's free,
keyless **"Positron no labels"** raster tile set instead of standard
OpenStreetMap tiles:

```dart
static const _standardTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png';
static const _standardTileSubdomains = ['a', 'b', 'c', 'd'];
```

```dart
TileLayer(
  urlTemplate: _standardTileUrl,
  subdomains: _standardTileSubdomains, // required for the {s} placeholder
  userAgentPackageName: 'com.morohunt.app',
  tileProvider: OfflineTileService.tileProvider,
)
```

Roads and terrain/land/water shading are kept; POI icons, shop/
business labels, and house-number clutter are gone. No API key, no
attribution requirement beyond the standard `© OpenStreetMap
contributors © CARTO` line (already covered by flutter_map's default
attribution control).

## Why this isn't a literal "Style JSON" toggle

Important distinction, since the ask mentioned "Map Style JSON": that
concept (declaratively hiding individual layers like `poi-label` or
`transit`) is a **vector tile** feature — it's how Mapbox GL/MapLibre
style specs work, and it's what I used for the earlier React/MapLibre
version of this map.

MoroHunt's `flutter_map` setup uses **raster XYZ tiles**
(`tile.openstreetmap.org/{z}/{x}/{y}.png`) — plain PNG images. POI
icons are baked into those images at the tile server; there's no
client-side property to switch off. The only way to "hide POIs" with
raster tiles is what's done here: point at a **different raster tile
provider** that doesn't draw them in the first place.

## Other raster options, if Positron's look doesn't fit

All free, no API key, same `{s}/{z}/{x}/{y}{r}` pattern — just swap
the URL:

| Style | URL |
|---|---|
| Positron (light, no labels) — **current** | `https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png` |
| Dark Matter (dark, no labels) | `https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png` |
| Voyager (more color/terrain feel, no labels) | `https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png` |

## If you actually want true vector-style layer control later

That would mean adding the `vector_map_tiles` package (or migrating
to `mapbox_maps_flutter`/`maplibre_gl`) so the basemap is real vector
tiles with a Mapbox Style Spec JSON you can filter layer-by-layer —
this is a bigger change than a URL swap, so it's not applied here
without you asking for it explicitly.
