# Skeval Timer

Current version: `v2.0`

A native macOS menu bar timer with a desktop dashboard for work time, goals, and hourly earnings.

Open the dashboard from the menu bar popover. Use the sidebar to move between Today, Week, Month, Analytics, and Settings. Today shows live work time and earnings, daily goal progress, and searchable sprint history. Its date picker can review any past day.

Manual sprint entry, editing, tags, clipboard copy, and CSV export are available in the dashboard. The popover keeps quick timing controls, manual entry, and the most recent seven days. Settings are available only in the dashboard. Earnings use the hourly rate and currency configured there. Weekly, monthly, and report totals use completed sprints; daily totals also include the active sprint.

Today and the current Week and Month show a catch-up card below goal progress. Its target is the daily goal multiplied by scheduled working days through today, minus all clocked work in that week or month. The active sprint counts toward catch-up, with breaks excluded. Work on days off still counts. Choose working weekdays and individual days off in Settings; the default is Monday–Friday. Weekly and monthly goal totals remain separate from this daily schedule calculation.

If the Mac sleeps during a sprint, the timer holds until you decide whether sleep counts as work or paused time. Time spent waiting to make that decision counts as paused time.

## Copy All

In the Today dashboard or menu bar popover, select a day and click **Copy All**, then paste into your sheet's Login cell. The popover context menu exports the same row. The four tab-separated columns are Login, Logout, an empty Lunch cell, and Break in whole minutes.

Login is the earliest completed sprint's start and Logout is the latest actual end. Break includes pauses and gaps between completed sprints, calculated as `logout - login - total net work` and rounded to the nearest minute, with 30 seconds rounding up. Running and unresolved recovery sprints are excluded. Date and Hours Worked stay in the sheet, and stored durations keep their precision.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Command 1–5 | Today, Week, Month, Analytics, Settings |
| Command N | Add a sprint in the current log view |
| Command Option Shift C | Clock in or out globally |
| Command Option Shift P | Pause or resume globally |
| Return / Escape | Save or cancel a dashboard sprint form |

## Development

Open `Skeval Timer.xcodeproj` in Xcode. The target requires macOS 26.2 or newer.

Run the domain, persistence, analytics, and lifecycle tests with `./scripts/run-tests.sh`.

Run `./scripts/run-tests.sh --runtime-health` for a separate AppKit check of live decimal earnings, dashboard and popover rendering, pause/resume, and timer shutdown with disposable data. The [health check report](docs/v2-health-check.md) records the findings and timer cleanup fix.

Run `./scripts/run-preview.sh` to open a separate native preview app with disposable sample logs. It opens Week; on Tuesday, October 13, 2026, the sample shows 16h expected, 6h clocked, and 10h left to catch up. Use the app menu's "Show menu bar preview" action to inspect the quick controls. Preview preferences and logs are isolated from the installed timer.

Build without signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'Skeval Timer.xcodeproj' -scheme 'Skeval Timer' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The [v2 refresh report](docs/v2-refresh.md) records the branch comparison, changes, and validation.

The [metrics and functionality audit](docs/v2-metrics-audit.md) records the fixes, 2,476 passing assertions, native UI checks, and remaining macOS integration checks.
