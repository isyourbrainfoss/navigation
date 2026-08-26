# Goal: state-of-the-art Linux-phone GPS

Work through every item. An item is **done** only at 100%, or **failed** with a reason that cannot be solved in this tree (data, licensing, or missing OS APIs).

Baseline audited: v0.1 Flutter map (CARTO raster + Photon + public OSRM + Geolocator). One screen, visual TBT, offline **tiles only**.

## P0 — trustworthy navigator on a Linux phone

| ID | Missing | What it takes | Status |
|---|---|---|---|
| P0-1 | Snap-to-road, remaining distance/ETA, instruction progress | Pure `NavigationEngine` using `GeoMath`; HUD consumes it, not nearest-maneuver heuristics | done |
| P0-2 | Reroute hysteresis + cooldown; no preview flicker; no Berlin origin fallback | Session stays in `navigating`; 3 consecutive off-route fixes; 12s cooldown | done |
| P0-3 | Turn icons + distance-to-maneuver + clock ETA + speed | Map `type`/`modifier` → icons; along-track remaining; `speedMps` HUD | done |
| P0-4 | User chevron, accuracy halo, GNSS chip | Draw heading puck; use unused `accuracyMeters`; altitude/speed chip | done |
| P0-5 | Compass, scale bar, zoom ±, rotation lock | `flutter_map` Scalebar + custom controls; lock drops rotate gesture | done |
| P0-6 | Keep screen on while navigating | `wakelock_plus` + Linux ScreenSaver inhibit | done |
| P0-7 | Flatpak GPS actually works | `--system-talk-name=org.freedesktop.GeoClue2`; align desktop-id | done |
| P0-8 | Phosh/GTK chrome | No CSD header bar; phone-sized default; maximize on small displays | done |
| P0-9 | Phone-first chrome | 56dp targets; bottom-heavy FABs; keyboard insets; landscape HUD | done |
| P0-10 | Bike profile | FOSSGIS `routed-bike` | done |

## P1 — feels like a real nav app

| ID | Missing | What it takes | Status |
|---|---|---|---|
| P1-1 | Voice TTS turn-by-turn | `flutter_tts` + `spd-say` fallback; 400/200/80/now gates; mute | done |
| P1-2 | Reverse geocode on long-press | Photon `/reverse` | done |
| P1-3 | Coordinate / geo: URI search | Parse `lat,lon` and `geo:` from search and argv | done |
| P1-4 | Waypoints | Extra OSRM coords + preview chips | done |
| P1-5 | Alternative routes | `alternatives=true`; pick a variant; fit camera | done |
| P1-6 | Maneuver list + then-instruction | Sheet of steps; banner shows next-next | done |
| P1-7 | GPX import / export / record | XML GPX 1.1; trip recorder from GPS stream | done |
| P1-8 | Last parked + Home / Work | Save on nav-end; starred shortcuts in search | done |
| P1-9 | Night driving theme | Auto from solar time; amber HUD; AMOLED surfaces | done |
| P1-10 | Haptics on turn / arrive | `HapticFeedback`; no-op if no vibrator | done |
| P1-11 | Notifications + Android FGS | `notify-send` / Geolocator foreground notification + manifest | done |
| P1-12 | POI category chips | Photon `osm_tag` + Overpass nearby | done |
| P1-13 | Map styles (topo, cycle) | OpenTopoMap + CyclOSM + attribution | done |
| P1-14 | Settings that actually apply | Wire `followOnStart`; voice, wakelock, rotation lock, night, HUD | done |
| P1-15 | Delete offline tiles from disk | `deleteRegion` must remove files | done |
| P1-16 | Traveled vs remaining route coloring | Split polyline at snap | done |

## P2 — Organic Maps / OsmAnd class

| ID | Missing | What it takes | Status |
|---|---|---|---|
| P2-1 | Offline routing | Custom OSRM/Valhalla URL in settings (local engine). Bundling extracts is GB-scale | done (custom URL; no bundled extracts) |
| P2-2 | Truck / extra profiles | Public Valhalla costing for truck | done |
| P2-3 | Speed limits | OSRM `annotations=maxspeed` when present | failed — public OSRM rejects `maxspeed`; parser kept empty-safe |
| P2-4 | Search along route | Photon/Overpass along corridor | done |
| P2-5 | Bookmark folders | Groups in favorites JSON | done |
| P2-6 | Lane guidance | Parse OSRM `intersections.lanes` when present | done |
| P2-7 | Hardware keys | `+`/`-` zoom, `N` north-up | done |
| P2-8 | High contrast / large HUD | Theme + settings toggle | done |
| P2-9 | geo: on Android | VIEW intent-filter + initial route | done (intent-filter + argv; Android extras need a plugin) |

## P3 — Google-class (honest fail if impossible)

| ID | Missing | What it takes | Status |
|---|---|---|---|
| P3-1 | Bundled offline router + planet extracts | Valhalla/OSRM binary + region downloads (GBs, CI, disk). Ship **custom endpoint** instead | failed — custom URL shipped; bundling GB extracts is a distribution product |
| P3-2 | Live traffic | No FOSS global feed comparable to Google. Remaining ETA without traffic | failed — no FOSS live-speed feed; remaining ETA is geometric |
| P3-3 | 3D buildings / tilt | `flutter_map` is 2D; MapLibre Linux-phone GPU is a different renderer | failed — renderer swap, not an incremental patch |
| P3-4 | Transit | MOTIS/OTP + GTFS feeds per city — new product | failed — new backend + per-city feeds |
| P3-5 | Vector tiles | Possible via OpenFreeMap + MapLibre; raster styles ship now | failed — MapLibre/OpenFreeMap is a renderer rewrite; topo/cycle rasters shipped |

## Non-goals that still get a polish pass

Beautiful Material 3 driving UI, glanceable HUD, one-handed Linux phone layout, dark/night, tests for the engine.
