# ADR-0014 — Kenney CC0 asset integration

- **Status**: accepted
- **Date**: post-M13 art pass
- **Related ADR**: [ADR-0011](0011-ios-app-architecture.md) (iOS stack)

## Context

The SwiftUI scaffold shipped with pure-geometric visuals (coloured
circles, solid-colour buttons, plain text banners). The user wanted
Western-medieval 2D sprite art, ideally free and with a permissive
license for potential App Store submission later.

Constraints:
- Non-commercial today, possibly commercial tomorrow.
- Hobby project, zero art budget.
- Must work with our existing SwiftUI layer; no engine dependency on
  art.

## Decision

Adopt two Kenney packs, both under **Creative Commons Zero (CC0)**:

- [**Medieval RTS Pack**](https://kenney.nl/assets/medieval-rts) —
  top-down 64×64 sprites (also @2x Retina 128×128). Tiles,
  structures, units, environment.
- [**UI Pack Adventure**](https://kenney.nl/assets/ui-pack-adventure) —
  buttons, panels, banners, icons. PNG + SVG, @1x and Double.

Integrated **14 imagesets** into `iOSApp/Sources/SunTzu/Assets.xcassets/`
with `@1x` (Default) + `@2x` (Retina / Double) variants, each under a
semantic name rather than the raw Kenney numeric suffix:

| Imageset | Kenney source | Role |
|---|---|---|
| `board_texture` | Tile/medievalTile_01 | tiled parchment background |
| `province_qin` | Structure/20 | green-roof storehouse |
| `province_chu` | Structure/10 | green-roof tower |
| `province_jinyan` | Structure/01 | red tower |
| `province_hanqi` | Structure/22 | wooden palisade gate |
| `province_wu` | Structure/05 | grey stone tower |
| `unit_blue` | Unit/20 | human player's soldier |
| `unit_red` | Unit/05 | AI's soldier |
| `panel_brown` | UI panel_brown | card / panel 9-slice background |
| `button_brown` | UI button_brown | primary buttons |
| `button_red` | UI button_red | combat / reveal buttons |
| `banner_title` | UI banner_hanging | main-menu title |
| `marker_six` | UI minimap_icon_star_yellow | 6-marker icon |

### Rendering patterns

- **9-slice stretch** on panels and buttons via
  `Image.resizable(capInsets:resizingMode: .stretch)`. The wooden
  texture survives any size; saves us having to ship 10+ button
  variants.
- **Tinted overlay** on the hand card background (coloured rectangle
  with `.blendMode(.overlay)` over `panel_brown`) — keeps the wooden
  texture while colouring per player.
- **Tile mode** on the board texture so a single 64×64 tile fills the
  board regardless of device size.
- **High interpolation** (`.interpolation(.high)`) on small pixel-style
  sprites so they scale up without mosh. Sprites are drawn at ~28px
  (structure) / 18px (unit) — the @2x source file keeps them crisp.

### Thematic note

Sun Tzu historically maps to the Warring States period in ancient
China. The Kenney sprites are Western medieval. The user chose to
keep the anachronism rather than hunt for a Chinese-themed pack —
Sun Tzu becomes a rules engine under a generic medieval skin rather
than a historical simulation. Documented explicitly so whoever opens
the next iteration doesn't spend an afternoon looking for a
"consistent" look.

### Licensing

CC0 means no attribution is legally required, but we shipped a
`CREDITS.md` at the repo root that lists:
- Kenney's name
- Pack source URLs
- Which imageset maps to which raw asset

Attribution is good practice and makes swapping packs later
traceable.

## Consequences

**Positive**

- Entire art layer ships free, no licensing risk for App Store.
- The rendering helpers (9-slice, tile, tinted overlay) generalize to
  any replacement pack: swap `button_brown.imageset` contents and the
  rest of the app keeps working.
- No additional dependency; everything is stock SwiftUI + PNG.

**Negative**

- Sprites are tiny (64×64 at @1x) — zooming past `@2x`-worth of pixels
  starts to alias. iPad / Max-sized iPhone may show softer edges.
  Fix in a future iteration: either request a higher-res pack, or run
  the PNGs through a pixel-art-aware upscaler.
- Theme mismatch (Western castles on a game about Chinese warlords).
  Easy to swap later once a better-suited pack is found.
- Not every province structure is distinct at thumbnail size; the
  user may want to re-pick the Structure_XX indices once play-tested.
