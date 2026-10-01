# Quiet Native — barpop SwiftUI spec

Control Center restraint on a black bar. One opaque card, one left edge, regular weights; hierarchy from size and color only. Every popup is a composition of the kit below — **no popup-local styling**. If a popup needs something missing, add a general component to the kit.

**Signature — anchor light.** The card's top hairline is lit in `primary` directly under the bar icon that opened it (fading ±120 pt), with a faint `primary` wash falling into the card. It draws outward from the icon on open. The bar icon turns `primary` with a 4 pt dot beneath it.

---

## 1. Tokens

`Palette` (existing, file-watched) supplies raw matugen roles. A `Theme` struct derives semantic tokens and is injected via `.environment(\.theme, …)`. Components read only `Theme`, never `Palette`.

### Color

| Token | matugen role | Use |
|---|---|---|
| `bg.card` | `surface_container` | card fill |
| `bg.raised` | `surface_container_high` | StatTile, tracks, hover pill, neutral IconTile, SearchField |
| `bg.pressed` | `surface_container_highest` **(add)** | pressed row, IconButton hover, IconTile inside hovered row |
| `bg.deep` | `surface` | night ClockFace dial |
| `text.primary` | `on_surface` | hero, titles, values |
| `text.secondary` | `on_surface_variant` | eyebrow, labels, subtitles, glyphs |
| `text.tertiary` | `on_surface_variant.opacity(0.4)` | out-of-month days, inactive symbol layers |
| `accent` | `primary` | on-toggle, fills, today, now-marker, anchor light |
| `onAccent` | `on_primary` | content on `accent` |
| `accentSoft` | `primary_container` | selected IconTile, accent Chip |
| `onAccentSoft` | `on_primary_container` **(add)** | content on `accentSoft` |
| `accentAlt` | `tertiary` | second series, event marks, sun/moon, personal events |
| `hairline` | `outline_variant.opacity(0.7)` (separators 0.6) | card stroke, separators, chart base |
| `critical` | `error` **(add)** | battery ≤ 20 % only |
| `bar` | `#000` fixed | SketchyBar |

Add `surface_container_highest`, `on_primary_container`, `error` (and `secondary` for SwatchStrip) to `matugen/templates/barpop.json` and `Palette.load()`.

### Type (`Theme.Font`)

| Token | SwiftUI | Use |
|---|---|---|
| `display` | `.system(size: 44, weight: .light, design: .rounded).monospacedDigit()`, `tracking(-0.9)` | HeroHeader numeric |
| `title` | `.system(size: 22)`, `tracking(-0.2)` | HeroHeader text |
| `headline` | `.system(size: 17, design: .rounded).monospacedDigit()` | StatTile value |
| `body` | `.system(size: 13)` | rows, values, footer |
| `label` | `.system(size: 12)` | eyebrow, SectionLabel, hero subtitle |
| `caption` | `.system(size: 11)` | row subtitles, chips, chart axes |

Weight is `.regular` everywhere except `display` (`.light`). No bold, no uppercase, no tracked caps. Units (`%`, `mph`, `MB/s`) render at half size in `text.secondary`.

### Spacing, radii, elevation

- Spacing (4 pt grid): `s1 4` · `s2 8` · `s3 12` · `s4 16` · `s5 20`.
- Radii (all `.continuous`): `card 22` · `tile 14` · `row 10` · `icon 8` · capsule.
- `elev.card`: `.shadow(.black.opacity(0.55), radius: 12, y: 8)` + `.shadow(.black.opacity(0.3), radius: 3, y: 1)`; 1 pt `hairline` `strokeBorder`; 1 pt inner top highlight `white.opacity(0.035)`.
- `elev.knob`: `.shadow(.black.opacity(0.45), radius: 1, y: 1)`.
- Nothing inside the card casts a shadow; depth comes from `bg.raised`. Fully opaque; no `Material`.

---

## 2. Components (the kit)

All live in `Kit/`. Signatures are the public API; everything visual is internal to the component.

| Struct | API | Tokens |
|---|---|---|
| `PopupCard` | `PopupCard(width: .regular /*320*/ \| .wide /*340*/, anchorX: CGFloat) { content }` | bg.card, hairline, accent, r.card, s5 padding, elev.card |
| `HeroHeader` | `HeroHeader(eyebrow: String, eyebrowChip: Chip? = nil, value: String, unit: String? = nil, subtitle: String? = nil, style: .numeric \| .text, dimmed: Bool = false) { accessory }` | display/title, label, text.primary/secondary, s1, s4 |
| `HeaderToggle` | `HeaderToggle(symbol: String, variableValue: Double? = nil, isOn: Bool, attention: Bool = false, searching: Bool = false, action:)` | 40 pt circle; off bg.raised/text.secondary; on accent/onAccent; attention critical ring |
| `HeroGlyph` | `HeroGlyph(symbol: String)` — 40 pt, `.symbolRenderingMode(.palette)` with `text.primary, accentAlt, accent` | |
| `SectionLabel` | `SectionLabel(_ title: String, trailing: String? = nil)` / `SectionLabel(_ title:) { IconButton… }` | label, text.secondary |
| `ListItem` | `ListItem(title:, subtitle: String? = nil, leading: .tile(IconTile) \| .strip(Tone), trailing: .none \| .check \| .chip(Chip) \| .symbol(String) \| .text(String), isSelected: Bool = false, action: (() -> Void)?)` | body/caption, bg.raised hover, r.row, min 44 pt |
| `ValueRow` | `ValueRow(_ label: String, value: String, copyable: Bool = false)` / `ValueRow { label view } value: { view }` | body; label text.secondary; value text.primary; separator hairline; 36 pt |
| `IconTile` | `IconTile(symbol:) \| IconTile(letter:)`, `.tone(.neutral \| .accent \| .critical)` | 28 pt, r.icon |
| `LevelSlider` | `LevelSlider(value: Binding<Double>, minSymbol: String, maxSymbol: String, isEnabled: Bool)` | track bg.raised 6→8 pt, fill accent, knob text.primary 20→22 pt + elev.knob |
| `Meter` | `Meter(value: Double, tone: .accent \| .critical, isLive: Bool = false)` / `Meter(range: ClosedRange<Double>, in: ClosedRange<Double>, marker: Double?)`, `.size(.regular /*8*/ \| .thin /*4*/)` | track bg.raised, fill accent / critical / `accentAlt→accent` gradient |
| `StatTile` | `StatTile(label:, symbol: String?, value:, unit: String?, detail: String?) { accessory } footer: { Sparkline? }` | bg.raised, r.tile, s3 padding, caption/headline |
| `StatGrid` | `StatGrid(columns: 2 \| 3) { StatTile… }` — `Grid`, 8 pt gap | |
| `TrendChart` | `TrendChart(points: [Point], bars: [Double]? = nil, labeledIndices: [Int], xLabels: [String])` | Swift Charts; line accent 1.75, area accent 24 %→0, bars accent 35 %, axes caption |
| `Sparkline` | `Sparkline(values: [Double], tone: .accent \| .alt)` | 28 pt high, area 12 % |
| `ArcProgress` | `ArcProgress(progress: Double?, start: (symbol, String), end: (symbol, String))` | dashed track text.secondary 35 %, progress accent, dot accentAlt |
| `MonthGrid` | `MonthGrid(month: Date, today: Date, marked: Set<Int>, onSelect:)` | body rounded, today accent/onAccent, marks accentAlt, out-of-month text.tertiary |
| `Chip` | `Chip(_ text:, tone: .neutral \| .accent \| .critical)` | caption, 20 pt capsule |
| `ClockFace` | `ClockFace(date: Date, timeZone: TimeZone)` — day dial text.primary / night (18–6 h) dial bg.deep | 28 pt, Canvas |
| `IconButton` | `IconButton(symbol:, action:)` | 24 pt, hover bg.pressed |
| `FooterLink` | `FooterLink(_ title:, detail: String? = nil, action:)` | body, text.secondary, hairline above |
| `EmptyState` | `EmptyState(symbol:, title:, message:, action: (String, () -> Void)?)` | 48 pt bg.raised disc, 15 pt title, accent Chip |
| `SearchField` | `SearchField(text: Binding<String>, prompt:, resultCount: Int?)` | 32 pt, bg.raised, r.row, focus ring accent 70 % |
| `ThumbGrid` / `Thumbnail` | `ThumbGrid(columns: 3) { Thumbnail(image: NSImage, isCurrent: Bool, action:) }` | 16:10, r.row; hover scale 1.03 + text.primary ring; current 2 pt bg.card gap + accent ring + check badge |
| `SwatchStrip` | `SwatchStrip(_ swatches: [(role: String, color: Color)])` | 28 pt chips r.icon, role caption, hex mono caption |
| `Section` | `Section(_ label: String? = nil, trailing:) { content }` — SectionLabel + content, handles spacing | |

Implementation notes per component:

- **PopupCard**: `VStack(alignment: .leading, spacing: 0)` padded 20, `.frame(width:)`, background = `EmergeShape` filled `bg.card` + `strokeBorder(hairline)`. Anchor light = overlay `Rectangle().frame(height: 1)` filled with `LinearGradient(stops: [.clear @ ax-120, accent.opacity(0.9) @ ax, .clear @ ax+120])` computed from `anchorX` in a `GeometryReader`; wash = `RadialGradient(accent.opacity(0.10) → .clear, center: UnitPoint(x: ax/width, y: 0), endRadius: 200)` scaled vertically `.scaleEffect(y: 0.6, anchor: .top)`. Clip everything with the card shape.
- **HeroHeader** numeric: `Text(value).contentTransition(.numericText(value:))`, unit as a second `Text` concatenated (`Text(value) + Text(unit).font(.system(size: 22, weight: .light, design: .rounded)).foregroundStyle(text.secondary)`).
- **HeaderToggle**: `Image(systemName:variableValue:)`, `.symbolEffect(.bounce, value: isOn)`, `.contentTransition(.symbolEffect(.replace))`; `searching` → `.symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing)`; `attention` → `.symbolEffect(.pulse)` + a `Circle().stroke(critical)` whose outer ring is driven by `PhaseAnimator([0,1])` (scale 1→1.25, opacity 0.45→0, 1.6 s).
- **ListItem / ValueRow hover pill**: `.padding(.horizontal, 8).background(RoundedRectangle(10).fill(hover ? bg.raised : .clear)).padding(.horizontal, -8)` so text stays on the card's content edge. `.onHover`, `.contentShape(Rectangle())`, `.buttonStyle(.plain)`.
- **ValueRow copyable**: click → `NSPasteboard.general.setString`; value swaps to `Label("Copied", systemImage: "checkmark")` in accent with `.contentTransition(.interpolate)`, reverts after 1.2 s via `Task.sleep`. Copy glyph (`doc.on.doc`, 13 pt) appears on hover only.
- **Separators**: a `ValueRow` list is `VStack(spacing: 0)` with `Divider`-like `Rectangle().fill(hairline).frame(height: 1)` between rows, hidden next to a hovered row.
- **Meter(isLive:)**: fill overlaid with a white 32 % `LinearGradient` band offset by `TimelineView(.animation)` phase (2.4 s linear), masked to the fill capsule.
- **TrendChart**: `Chart { AreaMark(...).foregroundStyle(gradient); LineMark(...).interpolationMethod(.catmullRom); BarMark(...) for bars; PointMark(now) }`, `.chartYAxis(.hidden)`, custom `.chartXAxis` with `AxisValueLabel` in caption. Point labels via `.annotation(position: .top)` on `labeledIndices`. Now-halo: `PhaseAnimator` circle behind the PointMark using `chartOverlay`.
- **Sparkline**: same Chart, no axes, `.chartPlotStyle { $0.frame(height: 28) }`; live values appended each second with `.animation(.linear(duration: 1))`.
- **ArcProgress**: `Canvas` or a custom `Shape` (half-ellipse, trimmed for progress) — `.trim(from: 0, to: progress)`, dashed track `StrokeStyle(lineWidth: 1.25, dash: [2, 4])`.
- **ClockFace**: `Canvas` with two rotated hand paths; `TimelineView(.everyMinute)`.
- **SearchField**: `TextField` with `.textFieldStyle(.plain)`, `@FocusState`. The panel returns `canBecomeKey = true` only while the field is focused (non-activating panel still receives keys).
- **Thumbnail**: `Image(nsImage:)` downsampled once via `CGImageSourceCreateThumbnailAtIndex` (max 400 px) and cached; `.scaleEffect(hover ? 1.03 : 1)`; current ring = `.overlay(RoundedRectangle(12).strokeBorder(accent, lineWidth: 1.5).padding(-3.5))`.

---

## 3. Composition rules

1. **Order**: `HeroHeader` → `Section`s → `FooterLink`. Always. `EmptyState` may replace hero + sections.
2. **One left edge**: all text sits on the 20 pt content edge. Hover pills bleed 8 pt outward; nothing indents.
3. **Spacing**: card padding 20 · section↔section 20 · SectionLabel→content 8 · stacked ListItems 2 · StatGrid gap 8 · last section→FooterLink 16 (+12 above its text, hairline between).
4. **Accessory**: HeroHeader takes a `HeaderToggle` (the popup's one primary switch) or a `HeroGlyph` (display only) or nothing — never both.
5. **Accent budget**: `accent` fill means on / now / current (on toggle, today, now marker, meter fill, selected tile, current thumbnail). Never decorative.
6. **Which list**: choosable things → `ListItem`; facts → `ValueRow`; changing numbers → `StatTile`; spans of time → `ArcProgress` / `TrendChart`; images → `ThumbGrid`.
7. **Critical** only when the user should act (battery ≤ 20 %). It never tints the card.
8. **Widths**: `.regular` 320 for list-shaped popups, `.wide` 340 for chart/grid popups (weather, calendar, wallpaper).

---

## 4. Motion

| Moment | SwiftUI |
|---|---|
| Emerge (present) | see below · `.spring(response: 0.38, dampingFraction: 0.84)` |
| Anchor light | seam `scaleEffect(x: 0→1, anchor: UnitPoint(x: ax, y: 0))`, wash opacity 0→1 · `.easeOut(duration: 0.5).delay(0.06)` |
| Content stagger | each top-level child `opacity` + `offset(y: 4→0)` · `.easeOut(duration: 0.22).delay(0.035 * i)`, i ≤ 4 |
| Collapse (dismiss) | content `.easeIn(duration: 0.08)` → shape progress 1→0 `.easeIn(duration: 0.16)` → `orderOut` |
| Numeric change | `.contentTransition(.numericText(value:))` + `.snappy(duration: 0.22)` |
| Hover | `.easeOut(duration: 0.12)` |
| Slider engage | `.spring(response: 0.25, dampingFraction: 0.8)` |
| Toggle | `.spring(response: 0.3, dampingFraction: 0.7)` + `.symbolEffect(.bounce, value:)` |
| Selection check | `.transition(.scale(0.6).combined(with: .opacity))`, `.spring(response: 0.3, dampingFraction: 0.75)` |
| Palette change (wallpaper apply) | `Palette` publishes → wrap assignment in `withAnimation(.easeInOut(duration: 0.45))`; colors interpolate everywhere; bar recolors via sketchybar's own reload |

**Emergence** (Caelestia's grow-from-the-bar idea, told quietly). The `NSPanel` is sized to the final card from the start (plus shadow margin) and positioned 6 pt below the bar; only the SwiftUI shape morphs, so the window never resizes.

```swift
struct EmergeShape: Shape {
    var progress: CGFloat          // 0 = tab under icon, 1 = full card
    var anchorX: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in r: CGRect) -> Path {
        // keyframes interpolated piecewise on progress:
        // 0.0: 28×4 at (anchorX, -6), radius 2
        // 0.2: 112×26 at (anchorX, -2), radius 13
        // 0.6: full width × 42% height, radius 22
        // 1.0: full rect, radius 22
        let f = frame(for: progress, in: r)
        return Path(roundedRect: f.rect, cornerRadius: f.radius, style: .continuous)
    }
}
```

Card background = `EmergeShape(progress:, anchorX:).fill(bg.card.mix(accent, 0.22 * (1 - progress)))`; content uses `.mask(EmergeShape(...))`; `elev.card` shadow opacity = `progress`. Content stagger starts at progress ≈ 0.6 (hero first). Storyboard frames in the HTML: 0 ms seed · 70 ms drop · 150 ms unfold · 320 ms settle.

**Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): progress jumps to 1, card uses `.easeOut(duration: 0.15)` opacity only; live sheen, halo, pulse, searching loops off.

---

## 5. Popups (compositions)

Bar items pass their center x to barpop (`sketchybar --query <item>` → `bounding_rects`); barpop converts it to `anchorX` within the card after clamping the card 8 pt from the screen edge.

**Volume** — `.regular` · `HeroHeader(eyebrow: device, value: "64", unit: "%") { HeaderToggle("speaker.wave.3.fill", variableValue: volume, isOn: !muted) }` · `LevelSlider(min "speaker.fill", max "speaker.wave.3.fill")` · `Section("Output") { ListItem(.tile(IconTile(symbol, tone: selected ? .accent : .neutral)), trailing: selected ? .check : .none) ×N }` · `FooterLink("Sound Settings…")`. Muted: hero value "Muted" `dimmed`, toggle off with `speaker.slash.fill` (`.replace`), slider `isEnabled: false`. Device symbols: `laptopcomputer`, `airpodspro`, `display`, `waveform`.

**Weather** — `.wide` · `HeroHeader(eyebrow: "Lakeville, MN" + location.fill, value: "61°", subtitle: "Partly cloudy · H 67° L 49°") { HeroGlyph("cloud.sun.fill") }` · `Section("Next 12 hours", trailing: summary) { TrendChart(bars: precip when any > 0) }` · `StatGrid(3) { Feels like · Humidity · Wind (accessory: arrow rotated to bearing) }` · `Section("5-day") { ValueRow { day + symbol + precip caption } value: { lo · Meter(range:in:marker: current for today) · hi } ×5 }` · `Section("Daylight", trailing: duration) { ArcProgress }` · `FooterLink("Open Weather", detail: "Updated hh:mm")`. Night: `cloud.moon.rain.fill`, chart bars on, ArcProgress `progress: nil`, trailing "Sunrise in …". Offline: `EmptyState("cloud.slash", …, action: "Try again")` + footer.

**Battery** — `.regular` · `HeroHeader(eyebrow: "Battery", value: "72", unit: "%", subtitle: "4:12 remaining") { HeaderToggle("leaf", isOn: lowPowerMode) }` · `Meter(value:)` · `Section("Health") { ValueRow: Power source, Condition, Maximum capacity, Cycle count }` · `Section("Using significant energy") { ListItem(.tile(IconTile(letter or app icon)), trailing: .chip) }` · `FooterLink("Battery Settings…")`. Charging: subtitle with `bolt.fill` in accent, `Meter(isLive: true)`, adds `ValueRow("Charger", "96 W USB-C")`, energy section hidden. Low (≤ 20 %): `eyebrowChip: Chip("Low", .critical)`, `Meter(tone: .critical)`, `HeaderToggle(attention: true)`. Data: IOKit `IOPSCopyPowerSourcesInfo`, `AppleSmartBattery` for cycles/max capacity.

**Wi-Fi** — `.regular` · `HeroHeader(eyebrow: "Wi-Fi", value: ssid, style: .text, subtitle: "Secured · 5 GHz · Channel 149") { HeaderToggle("wifi", variableValue: signal, isOn: power) }` · `StatGrid(2) { StatTile(Download) footer: Sparkline(.accent); StatTile(Upload) footer: Sparkline(.alt) }` · `Section("Details", trailing: "Click to copy") { ValueRow Signal (cellularbars variable value + dBm), IP, Router, Hostname — copyable }` · `FooterLink("Wi-Fi Settings…")`. Disconnected: hero "Not connected" `dimmed`, toggle `searching: true`, `Section("Known networks")` / `Section("Other networks")` of `ListItem(.tile(IconTile("wifi", variableValue)), trailing: hover ? .chip(Chip("Join", .accent)) : .symbol("lock.fill"))`. Rates: `getifaddrs` byte deltas at 1 Hz; SSID via CoreWLAN.

**Calendar** — `.wide` · `HeroHeader(eyebrow: "Wednesday, September 30", value: "09:12", subtitle: "Week 40 · Day 273")` · `Section("September 2026") { IconButton chevrons } { MonthGrid(marked: days with events) }` · `Section("Up next", trailing: "3 today") { ListItem(.strip(calendar tone), subtitle: time · location, trailing: soon ? .chip("in 18 min", .accent) : .none) }` · `Section("World clocks") { StatGrid(3) { StatTile(city, value: time, detail: offset) { ClockFace } } }` · `FooterLink("Open Calendar")`. EventKit; `.strip` tone: accent for work calendars, accentAlt for personal.

**Wallpaper** (new bar item, `photo.on.rectangle`) — `.wide` · `HeroHeader(eyebrow: "Wallpaper", value: currentName, style: .text, subtitle: "Current · 3024 × 1964 · JPG")` · `SearchField(prompt: "Filter 15 wallpapers")` · `Section("Library", trailing: count) { ThumbGrid(3) }` · `Section("Palette from <hovered>", trailing: "Click to apply") { SwatchStrip(primary, secondary, tertiary, surface) }` · `FooterLink("Open Folder", detail: "~/.local/share/wallpapers")`.
- Source: enumerate `~/.local/share/wallpapers` (`jpg|jpeg|png|heic`), sorted by name; filter = case-insensitive fuzzy subsequence match (fzf-like); ↩ applies first match, ↑↓←→ move hover.
- Palette preview: on hover run matugen in JSON, no-write mode (`matugen image <path> --dry-run -j hex`; confirm flag names against the installed version) in a background `Task`, cache per path; show the previous swatches until ready (no spinner).
- Apply: run the existing wallpaper script (set wallpaper + `matugen image`). `Palette`'s file watcher picks up the new `barpop.json` and animates the change; the bar recolors via matugen's sketchybar hook. The popup stays open so the user sees it recolor.

### More bar items with no new components
Launcher (SearchField + ListItem), Power (ListItem ×4, last with `IconTile(.critical)`), Now playing (HeroHeader + HeaderToggle play/pause, Thumbnail art, LevelSlider scrub, IconButton ×2), Focus/DND (HeaderToggle + ListItem checks), Theme (SwatchStrip + ListItem + LevelSlider).
