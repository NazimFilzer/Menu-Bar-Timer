# Repository Guidelines

## Project Structure & Module Organization

`Skeval Timer/` contains the macOS app: SwiftUI views, domain models, persistence adapters, and assets:
- **Presentation**: `DashboardView.swift` & `DashboardWindowController.swift` (main desktop dashboard shell with sidebar: Today, Week, Month, Analytics, Settings), `TodayDashboardView.swift` (live daily totals, date picker for past days, daily goal progress, finish-time forecast, catch-up card, sprint history), `WeeklyDashboardView.swift` & `WeeklyChartView.swift` (7-day chart with goal line, daily averages, weekly goal progress bar), `MonthlyDashboardView.swift` & `MonthlyChartView.swift` (month-to-date totals, 28–31 day interactive chart, tag distribution card, MoM comparison), `AnalyticsDashboardView.swift` (custom date range picker, period summary, long-term trend line, 52-week annual heatmap, CSV export), `DashboardSettingsView.swift` & `EyeBreakSettingsCard.swift` (goals, rate/currency, launch-at-login, themes, eye-break reminders, working days & days off), `SprintLogTableView.swift` (search, tag filtering, manual sprint modal, edit modal, delete confirmation), `FinishForecastCardView.swift` & `CatchUpCardView.swift` (finish time ETA with upcoming breaks; schedule-based catch-up card), and `PopoverView.swift` & `StatusBarPresenter.swift` (menu bar popover, state pills, quick timing controls, recent 7 days).
- **Domain & Engines**: `SprintEngine.swift` (state machine: idle, active, paused, recovery; 1-second ticker; workspace sleep/wake observer; sleep resolution), `Sprint.swift` & `DayLog.swift` (canonical entities; backward-compatible JSON encoding/decoding; tag support), `FinishForecast.swift` (projected finish time calculation, break allowance handling, scheduled pacing), `EyeBreakReminder.swift` (20-20-20 rule reminder state and notifications, active-tick delivery), `EarningsCalculator.swift`, `CatchUpAnalytics.swift`, `InsightsAnalytics.swift`, `WeeklyAnalytics.swift`, `MonthlyAnalytics.swift` (pure analytics functions), `CSVExporter.swift` (RFC-4180 export with proper time math and effective end times), and `TimeFormatter.swift` (time parsing, formatting, duration display).
- **Persistence**: `DayLogStore.swift` & `DayLogStorage.swift` (storage protocol seam: `DiskDayLogAdapter` vs `InMemoryDayLogAdapter`), `GoalSettings.swift` (persists goals, hourly rate, currency, theme, eye-break settings, working schedule).

Other repository directories:
- `Tests/`: Plain Swift test suite compiled by `scripts/run-tests.sh` via `TestRunner.swift` (39,923 assertions).
- `HealthChecks/`: Real AppKit runtime check with event loop (`scripts/run-tests.sh --runtime-health`, 20 checks).
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

- `./scripts/run-tests.sh` compiles and runs the domain, persistence, analytics, and lifecycle checks (39,923 assertions).
- `./scripts/run-tests.sh --runtime-health` runs the AppKit health check with disposable data and live event loop (20 checks).
- `./scripts/run-preview.sh` builds and opens the sample preview app with isolated logs.
- `./scripts/run-app.sh` builds and opens the app; pass `--configuration Release` for a Release build.
- `./scripts/deploy-app.sh` stages, signs, verifies, and installs a sandboxed Release app, making safety backups of live data before replacement.
- `./scripts/check-data-location.sh` verifies sandbox container storage path vs legacy unconfined path and checks code signature.
- `./scripts/sign-app.sh` signs the application bundle with entitlements.

## Architecture Invariants

- **Activation Policy (ADR 0001)**: The app runs as an `.accessory` (menu bar only, no Dock icon) by default. When the Dashboard window is opened, `NSApp.setActivationPolicy(.regular)` is set with Dock and Cmd+Tab presence. When the Dashboard window closes, it reverts to `.accessory`.
- **Zero Background Polling (ADR 0003 & Eye-break)**: Never introduce HID event polling or background timers while idle. Use `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification` for sleep/wake. Eye-break reminders must piggyback on the active 1-second engine tick only.
- **Sleep/Wake Resolution (ADR 0002)**: On system sleep, ticks suspend. On wake, the timer holds until the user chooses "Count as Work" or "Count as Paused". Resolving as work counts the sleep interval and decision delay as active work; resolving as paused credits both to `pausedDuration`.
- **Timer Lifecycle & Resource Cleanup**: `SprintEngine` owns a single repeating 1-second timer. `SprintEngine.deinit` must invalidate the timer and remove workspace observers to prevent leaks and runloop wakeups.
- **Data Attribution**: Sprints belong to their start day even across midnight. Live active sprint counts toward today's total on its start day; reports and catch-up use completed sprints plus current active net work.
- **Sandboxed Storage**: Production data lives in `~/Library/Containers/com.nazim.Skeval-Timer/Data/Library/Application Support/SkevalTimer/logs.json`. The legacy unconfined path (`~/Library/Application Support/SkevalTimer/logs.json`) is not live history. Always use `InMemoryDayLogAdapter` for tests and never touch user logs.

## Coding Style & Naming Conventions

Use four spaces for Swift indentation. Name types in `UpperCamelCase` and properties, functions, and local values in `lowerCamelCase`; keep source filenames aligned with their main type or feature (for example, `FinishForecast.swift`). Keep calculations and state transitions in domain, analytics, or engine types, and keep views focused on presentation. No external third-party dependencies; use Apple native frameworks (SwiftUI, AppKit, Combine, Foundation, Carbon).

## Testing Guidelines

Add tests to `Tests/` as plain Swift functions named `test...`, grouped in files by feature (for example, `FinishForecastTests.swift`, `EyeBreakReminderTests.swift`). Assertions come from `Tests/TestRunner.swift`; tests are compiled together by `scripts/run-tests.sh`, rather than run through XCTest. Always cover date boundaries, DST transitions, paused time, and persistence behavior when modifying timer or reporting logic.
