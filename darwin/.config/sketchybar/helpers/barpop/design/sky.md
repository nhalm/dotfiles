# Illustrated sky — weather hero backdrop

Extracted from the "Tidepool" (playful) direction; only the sky survived into Quiet Native. Implementation: `Kit/Sky.swift` (`SkyScene`), colours in `Kit/Theme.swift` (`Theme.Sky`), used through `HeroHeader(backdrop: .sky(condition, isNight:))`.

## Colours

The only literal hues in barpop, each pulled toward a matugen role with `Color.mix(with:by:in: .perceptual)` so the sky follows the wallpaper palette.

```swift
var skyDayTop: Color      { Color(hex: 0x3A7DE0).mix(with: primaryContainer, by: 0.52) }
var skyDayBottom: Color   { Color(hex: 0x8CBCEC).mix(with: primaryContainer, by: 0.60) }
var skyNightTop: Color    { Color(hex: 0x060A1C).mix(with: surface, by: 0.30) }
var skyNightBottom: Color { Color(hex: 0x2A3860).mix(with: primaryContainer, by: 0.50) }
var sun: Color            { Color(hex: 0xFFCB52).mix(with: tertiary, by: 0.22) }
var cloud: Color          { Color.white.mix(with: onSurface, by: 0.40) }
var cloudNight: Color     { Color(hex: 0x4B5772).mix(with: outlineVariant, by: 0.40) }
var rain: Color           { Color(hex: 0x9CC6FF).mix(with: primary, by: 0.45) }
```

## Scene

- Backdrop: vertical gradient `skyDayTop → skyDayBottom`, or the night pair.
- One `Canvas` layer behind the hero content draws:
  - Sun: radial gradient, two halo rings that breathe over 5s.
  - Moon: a circle masked by an offset circle.
  - Clouds: a `Path` of three arcs, drifting ±10pt over 7s.
  - Rain: 34 slanted 8pt strokes on a 0.9s loop.
  - Stars: 7 dots twinkling over 3s.
- Low hills along the bottom (the tide at a fixed 0.02 level in the original). Night hills use `primaryContainer.mix(with: surface, by: 0.45)`.
- Day clear: sun. Night: moon and stars. Rain at night: `.sky(.rain, isNight: true)`.

## Motion

- Drive everything with `TimelineView(.animation(minimumInterval:paused:))` + `Canvas`, paused when not visible.
- Reduce Motion: draw once at phase 0, no drift, particles off.
- Everything is opaque: no `Material`.

Quiet Native's adaptations (bleed to the card edges, hills settling into `card`, storm and snow) are in `DESIGN.md` → Sky.
