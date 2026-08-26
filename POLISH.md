# What still stands between this and a top-tier phone nav app

Target: Google Maps / Apple Maps / Magic Earth **ease of use and eye candy**, on a Linux phone (Phosh / Droidian / postmarketOS, ~720×1440, thumb, OSK, GeoClue, speech-dispatcher).

v0.2 already has real TBT, voice, bike/truck, GPX, night HUD, Flatpak GPS. It still *looks and feels* like a capable prototype, not a consumer nav app. Below is everything that would close that gap. Items marked **now** are in this pass.

Impossible in this stack (already failed in GOAL.md, kept here so they are not forgotten): live traffic, 3D tilt/buildings, bundled offline router, transit, MapLibre vector tiles.

---

## A. Ease of use (the “I can drive with this” bar)

| ID | Gap | Why it matters | What it takes |
|---|---|---|---|
| A1 **now** | Search is a top pill; FABs fight the preview sheet | Google/Apple put search in the thumb zone; our 4-mode preview is ~280px and covers the map | Bottom search while browsing; compact preview; FABs sit *above* the sheet, not a magic `280` |
| A2 **now** | Too many equal FABs (compass, zoom, locate, tracks, offline, settings) | Organic Maps: locate + one overflow. Linux-phone thumbs miss small stacks | Recenter is primary; zoom/compass nearby; the rest in a single **More** sheet |
| A3 **now** | Camera jumps every GPS tick | Apple/Google lerp + look *ahead* of the car; we `moveAndRotate` onto the puck | Smooth lerp, lookahead along heading, zoom-by-speed (walk 18, highway 15) |
| A4 **now** | HUD is a dense Material card, not a driving instrument | At 50 km/h you need a 56dp arrow + huge meters, not two icon buttons beside the text | Billboard: giant maneuver, huge distance, mute/stop as a bottom tray |
| A5 **now** | Roundabouts say “Enter the roundabout” | Apple says “take the 3rd exit” | OSRM `maneuver.exit` → ordinal in text + voice |
| A6 **now** | Arrival is a banner + Done | Last 50 m should tighten zoom, say the place name, big check | Arrival choreography |
| A7 | First-run is a thin permission strip | Google has a full-screen “enable location” with illustration | First-launch panel: why GPS, GeoClue copy for Linux, retry |
| A8 | Preview is not peekable | Google: drag up for steps, drag down to see the map | DraggableSheet with peek (ETA only) / half (modes) / full (steps) |
| A9 | No “report an issue” / “still on route?” after a bad snap | Off-route just recalculates | “Recalculating…” toast + undo-ish “stay on this route” |
| A10 | Settings are raw enums and a long list | iOS Maps: grouped, plain language, search | Sectioned, human labels (already partly done) |
| A11 | Can’t start from Home/Work in one tap on the map | Widget-level shortcuts | Map chips: Home, Work, Parked when set |
| A12 | No volume-key zoom, no hardware mute | Librem/Pine have keys | Map volume to zoom optional; mute key toggles TTS |
| A13 | Search results have no distance / walk time | Google shows “1.2 km · 14 min” | Haversine + mode estimate on each row |
| A14 | Long-press sheet is three stacked buttons | Apple: peek card with photo-less name, Navigate, Save | Compact card + favorite heart |
| A15 | No recent destinations on the map itself | Empty map feels dead | Recents as small dots or a bottom carousel |
| A16 | Keyboard covers results (mitigated, still tall sheet) | OSK on Phosh is huge | Search as a full route (`/search`), not 88% sheet |
| A17 | Landscape nav is a split, browse landscape is portrait chrome | Car dock / Librem landscape | Browse: FABs on the right, search still thumb-side |
| A18 | No “audio only” / screen-off confidence | Google keeps speaking in a pocket | Persistent Linux notification with next turn + mute |

## B. Eye candy (the “this is a product” bar)

| ID | Gap | Why it matters | What it takes |
|---|---|---|---|
| B1 **now** | Puck is a flat chevron | Google: pulsing accuracy, heading cone, white casing | Animated pulse + cone + 3-stop gradient chevron |
| B2 **now** | Route is two flat polylines | Apple: glow casing, direction chevrons, faded past | Outer glow, inner color, chevrons every ~80 m |
| B3 **now** | Chrome is opaque Material cards | Maps use frosted glass over the tiles | `BackdropFilter` 20px blur, hairline border, 0.72 alpha |
| B4 **now** | Compass is a rotated `Icons.navigation` | Real compass rose, red-N, tap-to-north with a spring | Custom painter + `AnimatedRotation` |
| B5 **now** | Maneuver icons are generic Material, 40px | Driving HUD uses a 64–80px white-on-color glyph | Billboard icon well |
| B6 | No camera easing on Go / Fit / Recenter | The map *pops* | 280–400 ms lerp (in A3) |
| B7 | Night theme is GitHub-amber on a card, tiles are CARTO dark_all | Roads vanish, HUD glare | Thicker route, dimmer chrome, no pure white |
| B8 | Attribution + scale + GNSS chip clutter the bottom-left | Apple hides attribution until tap | Collapse attribution to ©, scale only while zooming |
| B9 | No destination flag animation / no via dots with numbers | Multi-stop looks cheap | Numbered via badges 1…n |
| B10 | Alternative routes are ChoiceChips in the sheet, not on the map | Google draws ghost routes; tap the line | Draw all alternatives faded; selected is bold |
| B11 | Empty search is a paragraph | Illustration + “Long-press the map” | Simple custom painter / icon cluster |
| B12 | No splash / branded launch | Linux phones flash a black GTK window | Match GTK background to theme; better 512 icon |
| B13 | Sheets have no snap physics | iOS maps sheets feel expensive | `DraggableScrollableSheet` + `ClampingScrollPhysics` |
| B14 | Speed HUD is a tiny pill | Analog-ish speed well while driving | Bottom-trailing speed capsule, 28sp tabular |
| B15 | Lane strip uses the same arrow both ways | Lanes should fan | Per-indication rotation |

## C. Navigation quality (still not Google, but can be Organic-class)

| ID | Gap | What it takes |
|---|---|---|
| C1 **now** | Voice has no road-name emphasis, no “then” | Speak then-instruction when < 80 m |
| C2 | No zoom-to-maneuver in the last 80 m | Temporarily zoom in at the junction |
| C3 | Walking uses the driving camera | Walk: north-up default, tighter zoom, no course-up unless moving |
| C4 | Speed limits failed (OSRM) | Optional Overpass `maxspeed` along remaining, cached; best-effort |
| C5 | No junction schematic | Simple “keep left” diagram from modifier |
| C6 | Reroute is silent except TTS | Banner flash + route crossfade |
| C7 | Compass heading when stopped | GPS heading is 0; show last route heading, don’t spin |
| C8 | Instruction list not reachable while driving | Swipe HUD down for steps, auto-collapse |

## D. Linux-phone specific

| ID | Gap | What it takes |
|---|---|---|
| D1 | Fractional scaling (150–200%) | Don’t assume 1.0; use `MediaQuery.devicePixelRatio` for puck/halo |
| D2 | Phosh top panel + gesture bar | Extra padding beyond `SafeArea` (`viewPadding`) |
| D3 | speech-dispatcher inside Flatpak | Document + runtime check; in-app “Voice unavailable” not a silent fail |
| D4 | First GPS fix on a cold PinePhone is 30–90 s | Sky-search UI (accuracy + “waiting for satellites”) |
| D5 | GeoClue “navigation” accuracy vs “city” | Request high-accuracy desktop-id; surface GeoClue errors |
| D6 | App icon is Android mipmap | Dedicated 128/512 symbolic + color |
| D7 | `geo:` on Android still doesn’t parse extras | `app_links` (Linux argv already works) |
| D8 | Battery: `bestForNavigation` always | Coarse when browsing, fine when navigating (partially done) |

## E. Won’t do here (honest)

3D, live traffic, GTFS, planet extracts, AR walking, satellite imagery (licensing), Google-quality POI photos.

---

Priority for a Linux-phone daily driver: **A1–A6, B1–B5, C1, D4**. That is the Apple-Maps-in-the-car delta.

## Linux-phone P0 (GeoClue actually works)

- `geolocator_linux` reports `unableToDetermine` and `requestPermission` is unimplemented — we used to map that to **denied**, so GPS never started. **Fixed:** Linux treats GeoClue as granted and only fails if the stream throws.
- Extra `navigation.desktop` for GeoClue `DesktopId` from `PackageInfo.appName` (now in Flatpak install).
- Maximize on 1080-tall Phosh (not only width≤900); fake top/bottom insets when GTK padding is 0.
- Volume keys zoom; Esc closes preview; M mutes.
- PowerManagement inhibit in addition to ScreenSaver (PinePhone suspend).
- Retina tiles when DPR ≥ 1.5; text scale cap 1.8 (was 1.4).
- Still open: Location **portal**, `spd-say` missing in the GNOME 48 runtime, `geo:` single-instance Open, browse GPS duty-cycle, CMake-installed `.desktop` for `flutter run`.

## Visual (sunlight + night) still open

- Custom maneuver **glyphs** (not Material turn icons) and a Vienna-Convention speed-limit roundel
- Teardrop destination pin + search empty-state illustration
- `ColorFiltered` warm night tiles (now done); black route casing at night (now done); puck no longer a white glare disc (now done)
- Opaque HUD on 400-nit Linux panels (glass now 0.88–0.94; blur is garnish)
- Hide scale + zoom while driving (now done)
- Zoom-adaptive route width; topo/cycle-specific inner hue
- Don’t use BackdropFilter as the readability strategy on Mali/Adreno

## Nav-quality deltas vs Google/Organic (behavior, not new APIs)

- Speed-adaptive voice (seconds, not fixed 400/200/80 m) — drive at 120 km/h otherwise announces too late
- Windowed snap (don’t jump to a parallel road); inflate thresholds by GPS accuracy
- Skip speaking `continue` / `new name` (now done); HUD shows the next real turn (now done)
- “Now, turn left” prefix (now done); non-blocking `spd-say` (now done)
- Walk/bike start north-up (now done); GeoClue heading 0-when-stopped ignored (now done)
- Mute button actually re-enables voice if settings.voice is off (now done)
- Reroute HTTP not blocked on TTS (now done)
- `ref` / highway shields on the HUD; Overpass or Valhalla for legal maxspeed
- Approaching-destination (last 80 m) keep follow + “on the left”
- Audio-only dimmed map; Linux lockscreen TBT is a shell feature (fail)
- Windowed snap + live FGS notification text still open

## Extra scars from a later UX pass

Still prototype if these stay: persist last camera (no Berlin flash); OSK-glued search field; peek sheet 0.22/0.38/0.9; confirm Exit nav; undo deletes; default Drive (now done); lane left/right icons (now done); recenter must not reset zoom (now done); hide compass at north-up (now done); preview close must keep the pin (now done); live-apply courseUp; open system location settings on deniedForever.

## Shipped in the polish pass (2026-08-25)

Done now: A1 (bottom search, compact preview, More menu), A2, A3 (lerp + lookahead + speed zoom), A4 (billboard HUD), A5 (roundabout nth exit), A6 (arrival check + tray), B1 (pulse + cone puck), B2 (glow + chevrons), B3 (glass chrome), B4 (compass rose), B5 (72px glyph well), C1 (voice speaks “then”), D4 (waiting-for-GPS chip), A11 chips, A13 distances, B10 ghost alternatives, B9 numbered vias.

## Shipped in the goal pass (2026-08-25)

Daily-driver rows that were still OPEN after the polish pass:

- **A7** full-screen first-run location intro (GeoClue copy on Linux; no longer skipped just because `geolocator_linux` reports granted).
- **A8 / B13** peekable route preview (0.22 ETA+Go / 0.38 modes / 0.88 steps).
- **Persist camera** — last view is `MapOptions.initial*` (no Berlin/zoom-14 flash); saved on pan-end, pause, dispose.
- **A15** recents as map dots; **A14** compact long-press peek; **A16** search is a full-screen page so the Phosh OSK cannot cover the field.
- **Confirm Exit** navigation dialog; **undo** on track / offline / favorite deletes.
- **A9** off-route + Recalculating banner, with Stay to hold the current path.
- **Windowed snap** (hint window, 70 m fallback) + off-route enter grows with GPS accuracy.
- **VoiceTiming** seconds-by-speed (walk ≠ 30 m/s drive); last-80 m `approaching` + destination side; HUD tap → remaining steps (**C8**).
- **D3** in-app “Voice unavailable”; **D8** browse GPS stops after 60 s of no UI activity (GPS ticks do not count); GeoClue stream errors surface in the permission banner.
- **B8 / B11 / B14** attribution © chip, empty-search illustration, speed capsule, teardrop destination pin.
