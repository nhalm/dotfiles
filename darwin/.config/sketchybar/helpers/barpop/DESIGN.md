# barpop design kit — Quiet Native

One opaque card, one left edge, regular weights; hierarchy from size and colour only. A popup is a composition of `Kit/` components and sets no colour, font, padding or radius itself. If it needs something the kit lacks, add a general component to `Kit/`.

## Tokens (`Kit/Theme.swift`)

`Palette` loads matugen roles (`templates/barpop.json`, dark scheme) into `Roles`; `Theme(roles)` derives the tokens, injected by `Themed` as `\.theme`.

| Token | Role |
|---|---|
| `card` | `surface_container` |
| `raised` | `surface_container_high` — tiles, tracks, hover pill |
| `pressed` | `surface_container_highest` — pressed row, tile in hovered row |
| `deep` | `surface` |
| `text` / `textSecondary` / `textTertiary` | `on_surface` / `on_surface_variant` / `on_surface_variant` 40% |
| `accent` / `onAccent` | `primary` / `on_primary` — on, now, current only |
| `accentSoft` / `onAccentSoft` | `primary_container` / `on_primary_container` |
| `accentAlt` | `tertiary` — second series, markers |
| `hairline` / `separator` | `outline_variant` 70% / 60% |
| `critical` | `error` — only when the user should act |
| `sky.*` | literal sky hues mixed toward `primary_container`, `surface`, `tertiary`, `on_surface`, `outline_variant`, `primary` |

Type (`Theme.Font`): `display` 44 light rounded mono-digits, tracking −0.9 · `displayUnit` 22 light rounded · `title` 22, −0.2 · `headline` 17 rounded · `emptyTitle` 15 · `body` 13 · `label` 12 · `caption` 11. Regular weight otherwise; no bold, no caps. Units in `textSecondary` at about half size.

Space: `s1 4 · s2 8 · s3 12 · s4 16 · s5 20`. Radius (continuous): `card 22 · tile 14 · row 10 · icon 8`, capsule. Card shadow `black 55% r12 y8` + `black 30% r3 y1`, 1pt hairline, 1pt inner top highlight; nothing inside casts a shadow.

## Components (`Kit/`)

| Component | Purpose |
|---|---|
| `PopupCard(width: .regular 320 / .wide 340)` | The card: padding, spacing, emergence, anchor light, stagger |
| `HeroHeader(eyebrow:eyebrowSymbol:value:unit:subtitle:style:dimmed:backdrop:) { accessory }` | Headline value; accessory is one `HeaderToggle` or nothing; `backdrop: .sky(condition, isNight:)` |
| `HeaderToggle(symbol:variableValue:isOn:label:action:)` | The popup's one primary switch, 40pt circle |
| `LevelSlider(label:value:minSymbol:maxSymbol:isEnabled:dimmed:)` | Continuous level; `dimmed` = adjustable but not in effect |
| `Section(_:trailing:) { … }` / `SectionLabel` | Labelled group, 8pt to content, 2pt between rows |
| `ListItem(title:subtitle:symbol:isSelected:action:)` | Something to choose; hover pill bleeds 8pt, check when selected |
| `IconTile(symbol:tone:)` | 28pt leading glyph tile, neutral or accent |
| `ValueRow(_:symbol:note:) { value }` | A fact; consecutive rows in a `Section` get hairlines |
| `Meter(range:in:marker:labels:)` | A low…high range within wider bounds, marker = now |
| `StatTile(label:symbol:value:unit:detail:) { accessory }` / `StatGrid(columns:)` | Changing numbers on raised tiles, equal widths, 8pt gap |
| `Compass(degrees:)` | Direction arrow for a tile accessory |
| `TrendChart(values:bars:xLabels:format:)` | Swift Charts line + area, bars 0…100 along the bottom, now point with halo |
| `ArcProgress(progress:start:end:)` | Progress through a span of time as an arc; nil = track only |
| `EmptyState(symbol:title:message:action:)` / `Chip` | Replaces hero and sections when there is nothing to show |
| `FooterLink(_:detail:action:)` | Last line, hairline above; closes the popup |
| `LevelMeter(value:tone:isLive:)` | How full something is, 0…1, 8pt; `.critical` when the user should act; live sheen while rising |
| `AppIcon(image:)` | An app's own icon at `IconTile` size; `ListItem(icon:)` shows it in place of the tile |
| `HeroHeader(eyebrowChip:subtitleSymbol:)` · `HeaderToggle(attention:)` · `Chip(_:tone:)` | Chip beside the eyebrow; accent glyph before the subtitle; pulsing critical ring on a switch that is off but should be on; chip `.neutral` / `.accent` / `.critical` |
| `Section(_:content:trailing:)` / `SectionLabel(_:accessory:)` | Section whose label trails views (e.g. `IconButton`s) instead of text |
| `IconButton(symbol:label:action:)` | 24pt glyph-only action, `pressed` circle on hover |
| `MonthGrid(month:today:selected:marked:onSelect:)` | Month in locale weeks; today accent, selected accentSoft, marked midnights get an `accentAlt` dot, out-of-month `textTertiary` |
| `StripItem(title:subtitle:tone:chip:action:)` | `ListItem` for categorised things (events): 3pt `accent`/`accentAlt` strip leads, optional `Chip` trails |
| `ClockFace(date:timeZone:)` | 28pt analogue clock for a tile accessory; `text` dial by day, `deep` dial 18–06 |
| `Image(symbol:variableValue:)` | An SF Symbol by name, falling back to the ones macOS keeps private (`bluetooth`); `HeaderToggle` draws with it |
| `HeroHeader(…eyebrowImage:)` | An app icon (14pt) beside the eyebrow, e.g. what is playing |
| `Artwork(image:placeholder:)` | Cover art the content width, own aspect clamped 16:9…1:1, r.tile, hairline; placeholder glyph on raised 16:9 |
| `ScrubBar(duration:isPlaying:elapsed:seek:) { controls }` | Track position: symbol-less `LevelSlider` (symbols now optional), elapsed / −remaining caption, controls centred; ticks while playing, seeks when a drag settles |
| `Sparkline(values:tone: .accent / .alt)` | Recent values as a 28pt line and 12% area, 0 at the bottom; a `StatTile` `footer:` |
| `CopyRow(_:value:symbol:variableValue:)` | A `ValueRow` copied on click: copy glyph on hover, "Copied" in accent for 1.2s, pill covers adjacent hairlines |
| `.whileOpen { … }` | Runs async work (live sampling) from open until the popup starts closing |
| `HeaderToggle(searching:)` · `ListItem(variableValue:trailingSymbol:hoverChip:)` · `IconTile(variableValue:)` · `StatTile(…) {} footer: {}` | Searching animates the symbol's layers; a trailing glyph (lock) swaps for a chip ("Join") on hover |

## Sky (`Kit/Sky.swift`)

`SkyScene(condition: .clear | .partlyCloudy | .cloudy | .rain | .snow | .storm, isNight:)`, drawn behind `HeroHeader` and bled 20pt to the card's top and sides, 16pt below; the card's shape clips it.
- Gradient `sky.day*`/`sky.night*`, mixed toward `sky.cloudDark` when overcast (0.35 day / 0.15 night; storm 0.55 / 0.3).
- Sun (day clear/partly): halo rings breathe ±6% over 5s. Moon crescent + glow and 7 twinkling stars (3s) at night unless cloudy/storm.
- Clouds drift ±10pt over 7s each way; dark clouds for rain/storm and at night. Rain: 34 slanted strokes, 0.9s loop. Snow: 22 flakes, 4s. Storm: flash every 5s.
- Hills: far hill `sky.farHill*`, near hill `card`, so the sky settles into the card. No liquid motion.
- Text over the sky uses `text` 85% for secondary lines. Reduce Motion freezes the scene.

## Composition

1. `HeroHeader` → controls / `Section`s → `FooterLink`.
2. All text on the 20pt content edge; hover pills bleed outward, nothing indents.
3. Card padding 20 · top-level children 20 apart · last section → footer 16.
4. Accent fill means on / now / current; never decoration.
5. Choosable → `ListItem`; facts → `ValueRow`; changing numbers → `StatTile`; spans of time → `ArcProgress` / `TrendChart`. `.regular` for lists, `.wide` for charts and grids.

## Motion (`Motion`)

- Emerge: panel is final size from the start; `EmergeShape` morphs 28×4 tab at the icon (y −6, touching the bar) → 112×26 pill (0.2) → full width × 42% (0.6) → card (1), `spring(0.38, 0.84)`. Fill mixes `accent` 22% × (1 − progress); shadow opacity = progress; content masked by the shape.
- Anchor light: top seam lit under the icon (±120pt) scales out from it, accent 10% wash, `easeOut(0.5).delay(0.06)`.
- Stagger: each top-level child fades and rises 4pt, `easeOut(0.22).delay(0.1 + 0.035·i)`, i ≤ 4.
- Collapse: content `easeIn(0.08)`, then shape → 0 `easeIn(0.16)`, then `orderOut` at 0.26s.
- Numeric `snappy(0.22)` · hover `easeOut(0.12)` · slider engage `spring(0.25, 0.8)` · toggle `spring(0.3, 0.7)` + bounce · selection `spring(0.3, 0.75)` · palette change `easeInOut(0.45)`.
- Reduce Motion: shape starts full, card fades `easeOut(0.15)` in and out, no stagger, no halo, sky frozen.
