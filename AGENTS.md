# Repository Guidelines

## Project Structure & Module Organization

`Skeval Timer/` contains the macOS app: SwiftUI views, domain models, persistence adapters, and assets:
- **Presentation**: `DashboardView.swift` & `DashboardWindowController.swift` (main desktop dashboard shell with sidebar: Today, Week, Month, Analytics, Settings), `TodayDashboardView.swift` (day navigator with ⌘[ ⌘], Worked card beside the finish forecast, and one sprint card with the sprint tag chip, Timeline/List, Copy all, Add sprint, and an auto-fit timeline), `WeeklyDashboardView.swift`, `WeekPacePanelView.swift` & `WeekLedgerView.swift` (week navigator with ⌘[ ⌘], worked and earned beside the Pace panel against the Weekly Goal, and a day ledger with work vs goal bars, last week's line, the hours each remaining workday needs, and timesheet copy, details, add, and delete), `MonthlyDashboardView.swift` (Monday-first month calendar beside Worked, Pace or Result, and Time by tag cards; timesheet hides upcoming days), `AnalyticsDashboardView.swift` & `AnalyticsCards.swift` (Week/Month/Year/All or custom range with ⌘[ ⌘], comparison with the previous period, hours by day or week, every-day grid for long ranges, sprint patterns, time by tag, timesheet or monthly totals, CSV export), `DashboardGrammar.swift` (shared card header, period navigator, fact rows, progress bar, info button, hero fonts), `DashboardSettingsView.swift` & `EyeBreakSettingsCard.swift` (goals, rate/currency, launch-at-login, themes, eye-break reminders, working days & days off), `SprintLogTableView.swift` (search, tag filtering, manual sprint modal, edit modal, delete confirmation), `DailyGoalCardView.swift` (Today's "When can I finish?" card with upcoming breaks and the week pace badge; a Result card for past days), and `PopoverView.swift` & `StatusBarPresenter.swift` (menu bar popover, state pills, quick timing controls, recent 7 days).
- **Domain & Engines**: `SprintEngine.swift` (state machine: idle, active, paused, recovery; 1-second ticker; workspace sleep/wake observer; sleep resolution), `Sprint.swift` & `DayLog.swift` (canonical entities; backward-compatible JSON encoding/decoding; tag support), `FinishForecast.swift` (projected finish time calculation, break allowance handling, scheduled pacing), `WeekPace.swift` (Weekly Goal pace: expected by today, needed per remaining workday, pace so far, past-week result), `EyeBreakReminder.swift` (20-20-20 rule reminder state and notifications, active-tick delivery), `EarningsCalculator.swift`, `MonthCalendar.swift` (Monday-first month grid, day statuses, workdays met), `CatchUpAnalytics.swift`, `AnalyticsReport.swift` (Analytics ranges, previous-period comparison cut to the same days, chart bars), `WeeklyAnalytics.swift`, `MonthlyAnalytics.swift` (pure analytics functions), `CSVExporter.swift` (RFC-4180 export with proper time math and effective end times), and `TimeFormatter.swift` (time parsing, formatting, duration display).
- **Persistence**: `DayLogStore.swift` & `DayLogStorage.swift` (storage protocol seam: `DiskDayLogAdapter` vs `InMemoryDayLogAdapter`), `GoalSettings.swift` (persists goals, hourly rate, currency, theme, eye-break settings, working schedule).

Other repository directories:
- `Tests/`: Plain Swift test suite compiled by `scripts/run-tests.sh` via `TestRunner.swift`.
- `HealthChecks/`: Real AppKit runtime check with event loop (`scripts/run-tests.sh --runtime-health`, 24 checks).
- `Preview/`: Standalone sample preview app with isolated mock data (`scripts/run-preview.sh`).
- `scripts/`: Development, test, build, deployment, and data verification scripts.
- `docs/`: Feature notes (`finish-time-forecast.md`, `eye-break-reminders.md`, `eye-break-recommendations.md`), health/audit reports (`v2-health-check.md`, `v2-metrics-audit.md`), and ADRs (`docs/adr/`).
- `.scratch/`: Local markdown issue tracker (`.scratch/<feature>/spec.md`, `.scratch/<feature>/issues/<NN>-<slug>.md`).

## Agent Skills & Conventions

### Issue tracker
Issues and specs are tracked locally as markdown files under `.scratch/`:
- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state is recorded on a `Status:` line near the top of each issue file

### Triage labels
Standard triage vocabulary:
- `needs-triage`: Maintainer needs to evaluate this issue
- `needs-info`: Waiting on reporter for more information
- `ready-for-agent`: Fully specified, ready for an agent
- `ready-for-human`: Requires human implementation
- `wontfix`: Will not be actioned

### Domain docs
Single-context layout with a root `CONTEXT.md` defining core domain terms (sprint, day log, recovery, finish forecast, eye break reminder, etc.) and `docs/adr/` capturing durable architecture decisions. Always use the glossary's terminology.

## Build, Test, and Development Commands

The Xcode target requires macOS 26.2 or newer. Open `Skeval Timer.xcodeproj` in Xcode to browse or edit the app.

- `./scripts/run-tests.sh` compiles and runs the domain, persistence, analytics, and lifecycle checks and prints the assertion count.
- `./scripts/run-tests.sh --runtime-health` runs the AppKit health check with disposable data and live event loop (24 checks).
- `./scripts/run-preview.sh` builds and opens the sample preview app with isolated logs.
- `./scripts/run-app.sh` builds and opens the app; pass `--configuration Release` for a Release build.
- `./scripts/deploy-app.sh` stages, signs, verifies, and installs a sandboxed Release app, making safety backups of live data before replacement.
- `./scripts/check-data-location.sh` verifies sandbox container storage path vs legacy unconfined path and checks code signature.
- `./scripts/sign-app.sh` signs the application bundle with entitlements.

## Architecture Invariants

- **Activation Policy (ADR 0001)**: The app runs as an `.accessory` (menu bar only, no Dock icon) by default. When the Dashboard window is opened, `NSApp.setActivationPolicy(.regular)` is set with Dock and Cmd+Tab presence. When the Dashboard window closes, it reverts to `.accessory`.
- **Zero Background Polling (ADR 0003 & Eye-break)**: Never introduce HID event polling or background timers while idle. Use `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification` for sleep/wake. Eye-break reminders must piggyback on the active 1-second engine tick only.
- **No Hidden SwiftUI Content**: Hidden SwiftUI views still re-render on every engine tick. The Dashboard window builds its content in `showDashboard()` and drops it in `hideDashboard()`; the popover builds its content on open and drops it in `popoverDidClose`. Wrap values that change every tick in `Live { … }` so only that piece re-renders.
- **Sleep/Wake Resolution (ADR 0002)**: On system sleep, ticks suspend. On wake, the timer holds until the user chooses "Count as Work" or "Count as Paused". Resolving as work counts the sleep interval and decision delay as active work; resolving as paused credits both to `pausedDuration`.
- **Timer Lifecycle & Resource Cleanup**: `SprintEngine` owns a single repeating 1-second timer. `SprintEngine.deinit` must invalidate the timer and remove workspace observers to prevent leaks and runloop wakeups.
- **Data Attribution**: Sprints belong to their start day even across midnight. Live active sprint counts toward today's total on its start day; reports and catch-up use completed sprints plus current active net work.
- **Sandboxed Storage**: Production data lives in `~/Library/Containers/com.nazim.Skeval-Timer/Data/Library/Application Support/SkevalTimer/logs.json`. The legacy unconfined path (`~/Library/Application Support/SkevalTimer/logs.json`) is not live history. Always use `InMemoryDayLogAdapter` for tests and never touch user logs.

## Coding Style & Naming Conventions

Use four spaces for Swift indentation. Name types in `UpperCamelCase` and properties, functions, and local values in `lowerCamelCase`; keep source filenames aligned with their main type or feature (for example, `FinishForecast.swift`). Keep calculations and state transitions in domain, analytics, or engine types, and keep views focused on presentation. No external third-party dependencies; use Apple native frameworks (SwiftUI, AppKit, Combine, Foundation, Carbon).

## Testing Guidelines

Add tests to `Tests/` as plain Swift functions named `test...`, grouped in files by feature (for example, `FinishForecastTests.swift`, `EyeBreakReminderTests.swift`). Assertions come from `Tests/TestRunner.swift`; tests are compiled together by `scripts/run-tests.sh`, rather than run through XCTest. Always cover date boundaries, DST transitions, paused time, and persistence behavior when modifying timer or reporting logic.
