# Navigation

Simple, user-friendly **maps + navigation** for **Android**, **Linux desktop**, and **Linux mobile**.

OpenStreetMap basemap, Photon fuzzy search, walk/drive routing (OSRM), GPS follow, and offline map region downloads. No API keys required for the default setup.

## Features

- **Beautiful maps** — light/dark CARTO basemaps with OSM data
- **Fuzzy place search** — Photon (Komoot), recents + favorites
- **Walk & drive routing** — FOSSGIS OSRM public profiles
- **Turn-by-turn guidance** — next instruction, ETA, re-route when off course
- **Offline regions** — download tiles around the map for offline browse
- **Few taps** — search → pick → Go; or long-press map → Navigate here
- **Adaptive UI** — Material 3, phone-friendly controls

> Offline **routing** is not included yet (online routing + offline tiles in v0.1).

## Install

### Android (Obtainium recommended)

1. Install [Obtainium](https://github.com/ImranR98/Obtainium/releases).
2. Add app → paste:

   ```
   https://raw.githubusercontent.com/isyourbrainfoss/navigation/gh-pages/version.json
   ```

One-tap (Obtainium installed):

```
https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://raw.githubusercontent.com/isyourbrainfoss/navigation/gh-pages/version.json
```

APKs are also attached to [GitHub Releases](https://github.com/isyourbrainfoss/navigation/releases).

### Linux (Flatpak — recommended)

```bash
flatpak remote-add --if-not-exists --user navigation \
  https://isyourbrainfoss.github.io/navigation/navigation.flatpakrepo
flatpak install --user navigation com.isyourbrainfoss.Navigation
flatpak run com.isyourbrainfoss.Navigation
```

CI publishes the ostree repo under `gh-pages/repo` on every push to `main`. Single-file `.flatpak` bundles are attached to releases when available.

**Build Flatpak locally:**

```bash
./flatpak/build-flatpak.sh          # current arch
./flatpak/build-flatpak.sh x86_64
./flatpak/build-flatpak.sh aarch64
```

### Linux (from source)

```bash
flutter pub get
flutter run -d linux
flutter build linux --release
# binary: build/linux/x64/release/bundle/navigation
```

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # Android device/emulator
flutter run -d linux   # desktop / Linux phone
```

### Project layout

```
lib/
  core/           # constants, theme, geometry helpers
  models/         # Place, RoutePlan, settings, offline regions
  services/       # GPS, Photon, OSRM, tile cache, settings
  providers/      # Riverpod state
  features/       # map, search, navigate, offline, settings
```

### Data & attribution

- Map tiles © [CARTO](https://carto.com/attributions) © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors
- Search: [Photon](https://github.com/komoot/photon) (Komoot)
- Routing: [FOSSGIS OSRM](https://routing.openstreetmap.de/)

Please use bulk offline downloads respectfully (rate-limited in-app).

## License

MIT — see [LICENSE](LICENSE).
