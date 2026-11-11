---
name: Skeval Timer
description: A menu bar work timer and dashboard — calm ledger surfaces, tactile timing controls.
colors:
  accent: "#E0B24C"
  accent-text: "#876B2E"
  accent-icon: "#B48F3D"
  on-accent: "#000000"
  danger: "#D6594F"
  danger-fill: "#C15047"
  danger-fill-deep: "#AA473F"
  on-danger: "#FFFFFF"
  paused: "#B87A1F"
  pause-orange: "#FF9500"
  pause-tint: "rgba(255, 149, 0, 0.15)"
  warning-text: "#995900"
  success-text: "#22774D"
  sleep-indigo: "#5856D6"
  window-ground: "#FFFAE6"
  card-surface: "#FFFFFF"
  hairline: "#E8E0BA"
  ink: "#38301C"
  ink-muted: "#807552"
  accent-wash: "rgba(224, 178, 76, 0.16)"
typography:
  live-timer:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "19px"
    fontWeight: 500
  popover-action:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "12px"
    fontWeight: 600
  goal-figure:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "28px"
    fontWeight: 600
  metric-figure:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "24px"
    fontWeight: 700
  page-title:
    fontFamily: "SF Pro, system-ui"
    fontSize: "17px"
    fontWeight: 700
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "13px"
    fontWeight: 400
  card-label:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "12px"
    fontWeight: 700
    letterSpacing: "0.8px"
  action-label-lg:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "13px"
    fontWeight: 700
    letterSpacing: "0.5px"
  action-label:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "11px"
    fontWeight: 700
    letterSpacing: "0.4px"
  data-mono:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "11px"
    fontWeight: 700
  caption:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "10px"
    fontWeight: 500
rounded:
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "10px"
  xl: "12px"
  full: "9999px"
spacing:
  hair: "2px"
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  card: "18px"
  page: "20px"
components:
  button-clock-in:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    typography: "{typography.popover-action}"
    rounded: "7px"
    padding: "10px 0"
  button-clock-out:
    backgroundColor: "{colors.danger-fill}"
    textColor: "{colors.on-danger}"
    typography: "{typography.popover-action}"
    rounded: "7px"
    padding: "10px 0"
  button-pause:
    backgroundColor: "{colors.pause-tint}"
    textColor: "{colors.warning-text}"
    typography: "{typography.popover-action}"
    rounded: "7px"
    padding: "10px 0"
  button-pause-active:
    backgroundColor: "{colors.pause-orange}"
    textColor: "{colors.on-accent}"
  button-pill:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    typography: "{typography.action-label}"
    rounded: "{rounded.full}"
    padding: "5px 10px"
  card:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    padding: "{spacing.card}"
  metric-card:
    backgroundColor: "{colors.card-surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "14px"
  tag-chip:
    backgroundColor: "{colors.accent-wash}"
    textColor: "{colors.accent-text}"
    rounded: "{rounded.full}"
    padding: "2.5px 7px"
  sidebar-item-selected:
    backgroundColor: "{colors.accent-wash}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
---

# Design System: Skeval Timer

## Overview

**Creative North Star: "The Quiet Ledger"**

Skeval Timer is a ledger first: an exact, trustworthy account of hours that feeds real pay and a real employer timesheet. Surfaces are soft paper, one tinted ground with white cards ruled by a single warm hairline. Numbers are set in monospaced type so columns line up and figures never jitter while they tick. The page stays quiet so the figures can be read in one glance, then the user goes back to work.

The popover uses the selected Layout B. A compact timer and its controls come first. Today's hours, earnings, daily goal, and finish-time forecast follow. Recent sprints have their own review date. **The popover is where you act; the dashboard is where you review full history.** Native focus, menus, alerts, and sheets keep the controls familiar.

Personality comes from the twelve pastel themes (each with a dark twin) and SF Rounded labels: approachable and warm, never clinical. Structure stays native to the Mac: a `NavigationSplitView` sidebar, system pickers and toggles, SF Symbols, and global keyboard shortcuts.

**Key Characteristics:**
- Twelve pastel themes, each with a light palette and a dark twin. The user picks Light or Dark in Settings; the app ignores the macOS appearance. Citrus is the default.
- Monospaced figures for every duration, timestamp, and amount.
- Small uppercase SF Rounded labels with tracking give the ledger-heading voice.
- Flat bordered cards on the dashboard; compact state-colored controls in the popover.
- Native Mac structure: sidebar navigation, system controls, SF Symbols, keyboard shortcuts.

## Colors

The palette is a warm pastel ground, white cards, and one theme accent that marks state and progress. Status hues stay outside the accent: orange for paused and recovery, red for stopping, and indigo for sleep.

The frontmatter records the default **Citrus** theme. Every theme in `AppTheme.swift` fills the same roles (`bgDark`, `cardBg`, `cardBorder`, `accentColor`, `softRed`, `textPrimary`, `textSecondary`). Treat those roles as the system, not Citrus's specific values. `ThemeManager.theme` returns the light palette or its dark twin according to the user's Light/Dark choice (`ThemeManager.appearance`, saved with the theme). The Dashboard and popover force the matching colour scheme, so native controls match the theme whatever macOS uses.

### Primary
- **Honey Accent** (Citrus `accent`): the live-state colour. It fills Clock In, the active status, progress bars, the sidebar selection wash (16%), tag chips (14% fill with a 35% stroke), and SF Symbol icons on card headers. It carries meaning (running, progress, selected) and is never decoration.
- **Readable Honey** (`accent-text`): the accent darkened until it reaches 5:1 against the card, computed by `PopoverTheme.accentText`. Use it whenever accent-coloured *text* is needed.
- **Icon Honey** (`accent-icon`): the accent adjusted to 3:1 on the card (`accentIcon`). Use it for SF Symbols and indicator lines.

### Secondary
- **Brick Stop** (`danger`, the theme's `softRed`): destructive actions and the Clock Out control. Red text uses `dangerText`.
- **Stop Fill** (`danger-fill` to `danger-fill-deep`): the Clock Out fill. It is `softRed` darkened until white reaches 4.5:1 (`dangerFill`, `dangerFillDeep`).
- **Amber Pause** (`pause-orange`, the system orange) for the Pause/Resume control and the "Paused for…" badge, and **Burnt Amber** (`paused`, which varies per theme; olive in Cloud and pale gold in Sky) for the paused state pill and the menu bar status.
- **Sleep Indigo** (`sleep-indigo`, the system indigo at 12%): only the "Your Mac was asleep" resolution banner.

### Tertiary
- **Behind Amber** (`warning-text`) and **On-track Green** (`success-text`): goal-pace text. Both are darkened at runtime from orange `#FF9400` and green `#2E9E66` until they reach 5:1 on the card.

### Neutral
- **Citrus Paper** (`window-ground`): the window and popover background (`bgDark`, a legacy name from the old dark themes).
- **Card White** (`card-surface`): every card, sidebar, and header bar.
- **Warm Hairline** (`hairline`): the 1px card stroke and the divider colour.
- **Ledger Ink** (`ink`): primary text and figures.
- **Faded Ink** (`ink-muted`): labels, subtitles, and idle state.

| Theme | Ground | Accent | Accent on card | Readable accent |
|---|---|---|---|---|
| Citrus (default) | #FFFAE6 | #E0B24C | 1.96:1 | #876B2E |
| Sand | #FAF2E6 | #C28A4F | 2.93:1 | #886037 |
| Sky | #EBF7FA | #52A3B5 | 2.86:1 | #39727F |
| Cloud | #F5F7FC | #6B99D1 | 2.96:1 | #4B6B92 |
| Matcha | #F2F5ED | #2B7A4C | 5.23:1 | same |
| Mint | #E8F7F0 | #4FA882 | 2.85:1 | #37765B |
| Rose | #FFF5F2 | #D1878C | 2.77:1 | #925F62 |
| Slate | #EBEDED | #4A595E | 7.10:1 | same |
| Confetti | #FFF7CC | #A35EA8 | 4.33:1 | #935597 |
| Lagoon | #E6F7F5 | #AB593B | 4.91:1 | #A25538 |
| Orchid | #F5EDFC | #7D5CAD | 5.09:1 | same |
| Terracotta | #FFF0EB | #336E6B | 5.77:1 | same |

### Dark twins
Every theme has a dark twin (`PopoverTheme.<name>Dark`, `isLight: false`) with the same name and roles. The Light/Dark picker in Settings › Theme & Color Palette switches between them. The twins are generated from the light theme in OKLCH:
- **Ground and card:** the light ground's hue, with chroma capped low (neutral themes such as Slate stay neutral). Ground is L 23% and card is L 27.5%, close to the macOS dark window greys.
- **Hairline:** L 38%, same hue.
- **Ink:** L 94%; muted ink L 77%. Both are at least 7:1 on the card.
- **Accent:** the light accent's hue and chroma, lifted to L 75–82% (Slate stays grey). It works as a fill (at least 6:1 on the card) and carries a black label, so `actionButtonForeground` is always black in dark.
- **Red:** the same `softRed` as light, so white Clock Out text is unchanged. Red text uses `dangerText`.
- **Status:** the paused pill and menu bar pill use one shared amber in dark, not the per-theme light values.

Text helpers (`accentText`, `warningText`, `successText`, `dangerText`) lighten toward white in dark instead of darkening. `ThemeContrastTests` enforces the floors for all 24 palettes: 4.5:1 for every text role, black-on-accent, and white on the Clock Out fill; 3:1 for accent fills and icons. The higher ratios above are the current margins, not guarantees.

| Theme (dark) | Ground | Card | Accent |
|---|---|---|---|
| Citrus | #1F1C14 | #29291F | #E0B24C |
| Sand | #1F1C17 | #2B2621 | #DBA166 |
| Sky | #1A1F1F | #24292B | #6BBDCF |
| Cloud | #1C1C1F | #26292B | #82B2EB |
| Matcha | #1C1F1A | #262924 | #75C28F |
| Mint | #171F1C | #212926 | #6BC29C |
| Rose | #211C1A | #2B2626 | #E0969C |
| Slate | #1C1C1C | #262929 | #A1B2B8 |
| Confetti | #1F1C14 | #29291F | #D98FDE |
| Lagoon | #171F1F | #212929 | #ED9473 |
| Orchid | #1F1C21 | #29262E | #BD99F2 |
| Terracotta | #211C1A | #2E2624 | #80BAB8 |

### Named Rules
**The Readable Accent Rule.** `accentColor` is for fills, bars, and strokes. Text in the accent hue uses `accentText`; icons use `accentIcon`. State words use `statusText(for:)`; system orange and green text use `warningText` and `successText`. Six of the twelve accents fall below 3:1 on a card, and eight fall below 5:1, so raw accent text is illegible in half the themes.

**The Fixed Status Hues Rule.** The theme accent means only "running". It never marks paused, recovery, or stopping. The Pause control, the paused timer digits, and recovery use the orange family: system orange for fills and strokes, `warningText` for text. Stopping uses each theme's red. Sleep uses indigo. The paused state pill uses a per-theme amber in light (`statusColor(for: .paused)`; Cloud's olive #8C874D is the one exception) and one shared amber in dark.

## Typography

**Display Font:** SF Mono (for figures)
**Body Font:** SF Pro, through the system text styles
**Label Font:** SF Pro Rounded

**Character:** Monospaced figures and soft rounded labels. A precise ledger column sits next to friendly tracked headings. Native text styles carry the dashboard chrome.

### Hierarchy
- **Live timer** (SF Mono Medium, 19px): the compact popover sprint figure. Paused work uses `warningText`; other states use ink. Idle shows "Ready". The sprint's start day appears beside its status.
- **Popover action** (SF Pro Rounded Semibold, 12px): sentence-case timer button labels.
- **Hero figure** (SF Mono Bold, 28px, `Font.dashboardHero`): the main duration on a dashboard card, such as Worked. Clock-time answers like the finish forecast use SF Pro Rounded Semibold 28px (`dashboardHeroTime`); amounts beside them use SF Mono Bold 18px in `successText` (`dashboardMoney`).
- **Page title** (`.title2.bold()`, 17px): the dashboard page header, with a `.subheadline` subtitle under it.
- **Body** (`.body` and `.headline`, 13px): dashboard prose, banners, and form rows.
- **Card label** (SF Pro Rounded Bold, 12px, 0.8px tracking, uppercase): card and section headings such as "TOTAL BREAKS".
- **Action label large** (SF Pro Rounded Bold, 13px, 0.5px tracking, uppercase): the "CLOCK IN" button.
- **Action label** (SF Pro Rounded Bold, 11px, 0.4px tracking, uppercase): other button text, such as "PAUSE" and "CLOCK OUT".
- **Data mono** (SF Mono Bold, 11–12px): timestamps, durations in rows, and the paused-for badge. The menu bar pill uses `monospacedDigitSystemFont` at 11px Bold.
- **Caption** (SF Pro Rounded 9–10px, or `.caption`): metadata, chart axes, and hints.

### Named Rules
**The Tabular Figures Rule.** Every duration, clock time, and amount uses SF Mono or `.monospacedDigit()`, so live values never shift width while they tick.

**The Two Voices Rule.** Dashboard chrome (page titles, sidebar, banners, forms) uses system text styles. Ledger content inside cards (labels, figures, actions) uses the rounded/mono pairing. Don't mix the two inside one element.

## Layout

The dashboard is a `NavigationSplitView` with a card-white sidebar (Today, Week, Month, Analytics, Settings, plus a keyboard-shortcut footer and the version number). The detail pane sits on the tinted ground, with a card-white header bar showing the page title on the left and the live status and elapsed time on the right. Content is a vertical stack of full-width cards, with metric cards in rows. The Month page is the exception: a Monday-first calendar card sits beside a 300-point column of Worked, Pace (or Result for past months), and Time by tag cards, and stacks below it in a narrow window. Pace is a structured list of label–value rows, not a sentence.

The popover is a 330-point column using selected Layout B: app header, compact timer with adjacent actions, today's work and earnings, daily goal and finish forecast, daily timesheet copy, and two recent sprints. The history picker changes only history. Today's summary and copy stay on today. Tags and discard are in More actions; the version is in About. The usual height is 680 points. The app bounds it to the visible screen; content scrolls when needed.

The spacing rhythm is tight and dense: 6px between a label and its value, 8–12px between elements inside a card, and 16px between cards. Insets are 18px for standard cards, 14px for metric cards, and 20px for the page. Banners for recovery and sleep span the full width above the content, at 12% of their status hue.

## Elevation & Depth

There are two depth models, one per surface.

The **dashboard is flat**: tonal layering only. A white card sits on the tinted ground and is outlined by a 1px warm hairline. It has no shadows.

The **popover uses the dashboard's card language**. Each section (timer, Today, recent sprints) sits in a `cardBg` card with a 12-point radius and a `cardBorder` hairline on the theme background, with uppercase tracked section titles and an accent symbol. The running timer uses large light monospaced digits in the accent color, or warning orange while paused, and a soft accent wash sits behind the popover while a sprint runs. Accent fills Clock In. Pause uses an orange tint; Resume uses solid orange; Clock Out uses the contrast-safe danger fill. Progress bars, steppers, menus, and links are drawn with theme colors, because native tinted controls turn grey or white-on-white while the menu bar app is inactive or when the macOS appearance differs from the theme. The hosting window always gets the theme's appearance (`themeAppearance`). Focus remains visible. No shadows or glows on controls.

### Named Rules
**The Separate Dates Rule.** The sprint label names its start day. Today's summary always uses today. The history picker changes only the history area. Each timesheet copy action names its date.

**The Protected Delete Rule.** Discard and Delete live in menus and require explicit confirmation. Completed-sprint Delete also offers Undo while the popover remains open. Individual sprint copy names its output; the effective end time is shown in details.

## Shapes

Corners are gentle and step up with the size of the element:
- **xs** (4px): stepper chips and tiny controls.
- **sm** (6px): chart bars, date controls, and inline rows. This is the most common radius.
- **md** (8px): Pause, Clock Out, and sidebar selection.
- **lg** (10px): Clock In and metric cards.
- **xl** (12px): full dashboard cards.
- **full** (Capsule): pills, tag chips, state badges, and the menu bar status pill.

Borders are 1px hairlines in the theme's `cardBorder` colour. Accent-tinted strokes (35–40% opacity) mark selected or tagged elements.

## Components

### Buttons
- **Clock In:** full-width theme accent fill, 12px Semibold Rounded label, 10px vertical padding, 7px corners.
- **Pause / Resume:** shares a row with Clock Out. Pause uses the orange tint and readable warning text. Resume uses orange with black text.
- **Clock Out:** contrast-safe `dangerFill` with white text. Its tooltip explains individual sprint copy and the global shortcut.
- **Discard:** a named More actions menu item with a confirmation. Recovery has no direct-discard x button.
- **Copy timesheet:** native bordered button. Its date and success feedback are explicit. It exports completed sprints only.
- **Focus:** keep native keyboard focus indicators. Never disable focus across the popover.
- **Native secondary controls:** labeled Dashboard button, history-date menu, row action menus, and upcoming-break Stepper.
- **Manual entry:** native sheet with the existing time controls and validation.
- **Dashboard:** native `.borderedProminent` and `.link` button styles.

### Chips
- **Tag chip:** `#tag` in 10.5px Bold Rounded accent text on a 14% accent capsule with a 35% accent stroke. It has a clear button (`xmark.circle.fill`) in faded ink.
- **Stepper chip:** 9.5px Bold Rounded faded ink on a 6% white fill with a hairline stroke and 4px corners. Used for Upcoming breaks increments.

### Cards / Containers
- **Corner Style:** 12px for dashboard cards (`WorkInsightsCardStyle`), 10px for metric cards. The popover summary and history use divided sections, with no timestamp-card grid.
- **Background:** card white on the tinted ground.
- **Shadow Strategy:** none (see Elevation & Depth).
- **Border:** 1px hairline.
- **Internal Padding:** 18px standard, 14px metric.

### Dashboard grammar
Shared parts in `DashboardGrammar.swift`, taken from the Month page, so every dashboard tab reads alike:
- **Card header** (`DashboardCardHeader`): accent SF Symbol on the left, 11px Rounded Bold uppercase label with 0.8px tracking in ink, optional trailing badge or actions.
- **Fact row** (`DashboardFactRow`): a muted rounded label and a mono value on one line, with an optional detail under the value.
- **Period navigator** (`DashboardPeriodNavigator` with `DashboardPeriodLabel`): round ‹ › buttons around the period chip, above the first card on every page, ⌘[ ⌘], and a sentence-case reset button ("Today", "This week", "This month") only when another period is shown.
- **On-screen times** use `h:mm AM` and durations like `2h 0m` (`Sprint.startDisplayLabel`, `durationDisplayLabel`). Seconds appear only in sprint details, timesheet tables, the clipboard, and CSV, which mirror the employer sheet.
- **Progress bar** (`DashboardProgressBar`): an 8px theme capsule. Never a native `ProgressView`, which turns grey while the window is inactive.
- **Info button** (`DashboardInfoButton`): explanations live behind an ⓘ with the same words as tooltip and VoiceOver hint, not as always-on captions.

### Inputs / Fields
- **Style:** native `.roundedBorder` text fields in dashboard forms, and `.plain` fields inside themed containers in the popover and search. Dates use `CalendarDatePicker` on a 6px card-white field.
- **Controls:** system `.switch` toggles, `.segmented` pickers, and `.checkbox` toggles.

### Navigation
- **Sidebar:** a `.sidebar` list with 14px rows, Semibold when selected. The selected row gets a 16% accent wash at 8px corners. Cmd+1–5 switches pages.
- **Header bar:** the page title and subtitle on the left; the state word (Caption Bold in its status colour) and the live elapsed time (body mono) on the right. Pause and Clock out sit beside it as native prominent buttons tinted by state: orange tint (Resume: solid orange) and the theme `dangerFill` red. Only Clock in carries the accent.

### Status Pill (signature)
The menu bar extra. It's a Capsule drawn in AppKit with 11px Bold monospaced-digit text. It's filled with the accent while active and with the paused colour while paused. The text colour is chosen per theme for legibility.

### Theme art (3D, scope B)
Clay objects rendered per palette by `scripts/render-app-art.sh` (SceneKit, headless) into `Assets.xcassets/Art3D`, named `art-<object>-<theme>-<light|dark>`, and drawn with `ThemeArtView`. They appear in two places only:
- **Page headers:** sun (Today), flag (Week), calendar (Month), bars (Analytics), at 46pt beside the title. Settings stays plain.
- **Moments with nothing else to read:** the stopwatch in the idle popover timer, the trophy when the daily goal is reached, and the mug in empty sprint lists.
Art never sits beside a running figure, inside a chart, or in a card header. It is decorative and hidden from VoiceOver. After adding or changing a theme, rerun the script; `testThemeArtCoverage` fails until every palette has every object.

### Day ribbon and earnings trend
- **Day ribbon** (popover, under today's progress): today's sprints as accent blocks on a fitted window of whole hours, the current pause in orange, a dashed accent block out to the finish forecast, and an ink "now" mark. Past pauses are not drawn, because sprints store only their total paused time. It redraws once a minute.
- **Earnings so far** (Analytics, after Totals, only with an hourly rate): cumulative earnings in `successText` with a 10% area, and the previous period as a dashed muted line at the current rate. No ghost line when the previous period earned nothing.
- **Menu bar ring** (Settings › System, off by default): replaces the pill's dot with a 10pt ring of today's daily-goal progress in the pill's text colour.

## Do's and Don'ts

### Do:
- **Do** set every duration, time, and amount in SF Mono or `.monospacedDigit()`.
- **Do** use `accentText`, `warningText`, `successText`, `dangerText`, and `statusText(for:)` for coloured text, and `accentIcon` for icons. Keep raw `accentColor` for fills, bars, and strokes.
- **Do** build new themes by filling the same seven `PopoverTheme` roles. Never add a one-off colour to a single view.
- **Do** keep dashboard cards flat: card white, a 1px hairline, and 12px or 10px corners.
- **Do** keep keyboard focus visible and add `.help` text naming each timer shortcut.
- **Do** keep paused, recovery, stopping, and sleep off the theme accent: orange, red, and indigo, in every theme.

### Don't:
- **Don't** add shadows or glows to cards, rows, charts, or the timer controls.
- **Don't** use native tinted controls (`ProgressView`, `Stepper`, `.bordered`, `.link`, bezel menus) in the popover. They ignore the theme while the app is inactive.
- **Don't** use `accentColor` (or its alias `neonTeal`) as a text colour. Half the theme accents are under 3:1 on a card.
- **Don't** use the theme accent for paused, recovery, or destructive states.
- **Don't** replace system controls (toggles, segmented pickers, date pickers, sidebar list) with custom ones.
- **Don't** hard-code a theme's hex value in a view. Read it from `ThemeManager.shared.theme`.
- **Don't** hard-code `.light` or `.dark` colour schemes. Derive them from `theme.isLight`, so native controls match the user's Light/Dark choice.
