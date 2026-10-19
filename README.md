# Skeval Timer

Current version: `v2.0`

A native macOS menu bar timer with a desktop dashboard for work time, goals, and hourly earnings.

Open the dashboard from the menu bar popover. Use the sidebar to move between Today, Week, Month, Analytics, and Settings. Today shows live work time and earnings, daily goal progress, and searchable sprint history. Its date picker can review any past day.

Manual sprint entry, editing, tags, clipboard copy, and CSV export are available in the dashboard. The popover keeps quick timing controls, manual entry, and the most recent seven days. Settings are available only in the dashboard. Earnings use the hourly rate and currency configured there. Weekly, monthly, and report totals use completed sprints; daily totals also include the active sprint.

Today and the current Week and Month show a catch-up card below goal progress. Its target is the daily goal multiplied by scheduled working days through today, minus all clocked work in that week or month. The active sprint counts toward catch-up, with breaks excluded. Work on days off still counts. Choose working weekdays and individual days off in Settings; the default is Monday–Friday. Weekly and monthly goal totals remain separate from this daily schedule calculation.

If the Mac sleeps during a sprint, the timer holds until you decide whether sleep counts as work or paused time. Time spent waiting to make that decision counts as paused time.

## When can I finish?

Today's dashboard forecasts when you could reach your daily goal: remaining net work plus **Upcoming breaks** (0–240 minutes, in five-minute steps, default zero). Include lunch and other breaks still ahead; reduce the allowance after taking them. This planning input never changes logs, pauses the timer, or schedules clock-out. It resets each day and on app restart.

Active estimates assume you keep working; idle/paused estimates explicitly assume you start/resume now. The card refreshes at least once a minute while visible. Recovery and unresolved sleep hide the daily estimate. A previous-day sprint cannot advance today's goal, so the card asks you to start a sprint today. Cross-midnight estimates show the date and explain start-day attribution. Reaching the goal removes the estimate even if an allowance remains.

Weekly pacing spreads the week's remaining schedule-based work across remaining working days through Sunday, respecting days off and including today only when scheduled. It shows work still needed per workday and any amount above the normal daily goal—not extra work on top of today's full goal. The target is daily goal × scheduled days, separate from the configured weekly goal. Completed off-day work and known active net work count; future-dated work and recovery do not. Break allowances affect the daily estimate only. A capacity warning compares remaining work with scheduled-day calendar time, not a recommended work limit; overnight/off-day work can still count under existing attribution rules.

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

Build and launch the Debug app from Xcode with `./scripts/run-app.sh`. Build and install a Release app with `./scripts/deploy-app.sh`; it stages, signs, and verifies the app before replacing the install. The bundle ID alone is not enough to preserve data—the app must retain its sandbox entitlement. Production logs are in `~/Library/Containers/com.nazim.Skeval-Timer/Data/Library/Application Support/SkevalTimer/logs.json`, with preferences in that container's `Library/Preferences`. Deployments back up production data before replacement. The non-container `~/Library/Application Support/SkevalTimer/logs.json` is a separate legacy log, not live history. The scripts do not migrate or overwrite logs. Run `./scripts/check-data-location.sh` to verify paths and signing. Both build scripts accept `--help`; `run-app.sh` also accepts `--configuration Release`, and `deploy-app.sh` accepts a different destination path.

The [v2 refresh report](docs/v2-refresh.md) records the branch comparison, changes, and validation.

The [metrics and functionality audit](docs/v2-metrics-audit.md) records the fixes, 2,476 passing assertions, native UI checks, and remaining macOS integration checks.
