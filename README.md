# Navigation

> **Note**
> This is very experimental. Assume nothing here is written, or necessarily read through or fully understood, by a human unless stated, and that includes this text. Use it at your own risk, but you're encouraged to reuse any parts you find useful. The human work here is mainly ideas, testing in reality, and persistence with a vision.


Phone-first **maps + turn-by-turn** for **Android**, **Linux desktop**, and **Linux mobile** (Phosh, Droidian, postmarketOS).

OpenStreetMap basemap, Photon search, OSRM/Valhalla routing, voice guidance, GPX, GPS follow, and offline map region downloads. No API keys required for the default setup.

## Features

- **Glanceable HUD** — large distance-to-turn, then-instruction, remaining ETA, speed
- **Voice + haptics** — speech-dispatcher / TTS, mute, keep-screen-on
- **Walk, bike, drive, truck** — FOSSGIS OSRM + public Valhalla
- **Waypoints and alternative routes** — add stops, pick a variant
- **Fuzzy search** — Photon, coordinates, `geo:` URIs, POI chips, along-route
- **GPX** — record tracks, import/export, overlay on the map
- **Offline regions** — download tiles around the map for offline browse
- **Linux-phone chrome** — 56dp targets, compass, scale bar, zoom ±, rotation lock, no GTK header bar

> Offline **routing** still needs a network (or a custom local OSRM/Valhalla URL in Settings). Tiles can be used offline.

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
