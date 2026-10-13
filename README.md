# Skeval Timer

Current version: `v2.0`

A native macOS menu bar timer with a desktop dashboard for work time, goals, and hourly earnings.

Open the dashboard from the menu bar popover. Use the sidebar to move between Today, Week, Month, Analytics, and Settings. Today shows live work time and earnings, daily goal progress, and searchable sprint history. Its date picker can review any past day.

Manual sprint entry, editing, tags, clipboard copy, and CSV export are available in the dashboard. The popover keeps quick timing controls, manual entry, and the most recent seven days. Earnings use the hourly rate and currency configured in Settings. Weekly, monthly, and report totals use completed sprints; daily totals also include the active sprint.

If the Mac sleeps during a sprint, the timer holds until you decide whether sleep counts as work or paused time. Time spent waiting to make that decision counts as paused time.

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

Build without signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'Skeval Timer.xcodeproj' -scheme 'Skeval Timer' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The [v2 refresh report](docs/v2-refresh.md) records the branch comparison, changes, and validation.

The [metrics and functionality audit](docs/v2-metrics-audit.md) records the fixes, 2,476 passing assertions, native UI checks, and remaining macOS integration checks.
