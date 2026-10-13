# V2 metrics and functionality audit

Audit date: 13 October 2026. Baseline: v2 at `99b038c`. All changes were made in the dedicated v2 worktree. Main remained at `1ca62eaca99d21142437b1bf8429fee8e043265e` with a clean working tree.

## Results

- Baseline suite: 715 / 715 assertions passed.
- Final suite, including new boundary and failure regressions: 2,476 / 2,476 assertions passed.
- Xcode Debug and Release builds succeeded with code signing disabled.
- Native UI flows were exercised using production views, an in-memory sprint store, and a separate settings suite.
- Git whitespace checks passed.

The audit found defects that the original suite did not cover. The new regressions reproduced them before the fixes. Passing these checks establishes the behavior below; it cannot prove that every possible input or macOS configuration is flawless.

## Metric rules checked

Net work is elapsed time minus recorded pauses, clamped at zero. Daily totals include the current sprint only on its start day. Weekly, monthly, range, trend, tag, and heatmap totals include completed sprints. An overnight sprint is attributed entirely to its start day.

Earnings use exact net seconds and the currently configured hourly rate, then round the aggregate to cents. Changing the rate recalculates historical reports. These are estimates of work value, not a ledger of invoices or payments. Goal amounts use the corresponding configured goal duration and rate.

An active day has positive completed work. Daily report averages divide by active days; the range card also shows the number of calendar days. Custom ranges include both selected dates. Long trend ranges use intervals of up to seven days, starting at the range's first day; shorter ranges use individual days. Annual heatmaps use calendar days, including leap days and the final day of the year.

CSV and clipboard effective end times deduct pauses. Their whole-second endpoints agree with the exported whole-second duration. CSV includes completed records only. A multi-day record's Duration column is authoritative because the effective End column contains a time, without a separate end date.

## Defects fixed

| Area | Correction |
| --- | --- |
| All Time | Includes the earliest completed record, instead of cutting off records older than five years. |
| Annual heatmaps | Computes the required 53 or 54 calendar columns, preserving December 31 in leap years that start on Sunday. Equality includes all cell values. |
| Dates and ranges | Uses the supplied calendar and time zone consistently, rejects malformed date keys, and safely normalizes reversed custom ranges. |
| Work-day counts | Excludes zero-duration records from active-day counts. |
| Tag reports | Keeps a literal `Untagged` tag separate from untagged work, normalizes filter counts, and shows more precise percentage labels and proportional bars. |
| Month comparisons | Shows N/A when there is no prior work; earnings changes equal the difference between the displayed rounded totals. |
| Save and reload precision | Keeps exact fractional timestamps alongside backward-compatible ISO date fields, preventing subsecond work and pause drift. |
| Sprint editing | Preserves exact pauses when editing a tag, supports explicit end-day offsets, and validates before changing stored data. |
| Recovery | Accepts an explicit end date for overnight recovery and validates proposed work before saving. |
| Sleep decisions | Persists the pause count, excludes time spent deciding after wake, holds conflicting controls, and refreshes the pause display immediately. |
| Daily milestones | Uses work attributed to today, so a sprint carried across midnight cannot trigger the next day's milestones. |
| Invalid numbers | Rejects invalid goals, rates, dates, and pauses; guards non-finite earnings and overflow; displays sub-minute work as seconds. |
| Persistence failures | Protects an unreadable existing file from overwrite, exposes a warning, retains unsaved memory changes for retry, and serializes writes to prevent stale snapshots. |
| Status bar | Refreshes idle accumulated totals and provides state/time accessibility text. |
| Export and login feedback | Surfaces save failures and login-registration errors rather than silently reporting success. |
| Report accessibility | Gives the large trend plot one summary and an expandable list of interval values. Year controls have labels, and report navigation respects Reduce Motion. |

## Automated coverage

Run `./scripts/run-tests.sh` from the v2 checkout. It compiles the app's production Swift files, its real AppDelegate without the application entry point, and every Swift file in Tests.

- Independent duration and earnings calculations across UTC−8, UTC, and UTC+9, plus daylight-saving boundaries and inclusive date ranges.
- Annual coverage for every year from 2000 through 2040, including leap-year final days.
- Five pause/resume cycles on each of 100 sprints, fractional timestamps, repeated recovery attempts, midnight attribution, and both sleep choices.
- Live daily totals, completed reports, goal progress, rate/currency changes, tag shares, month comparisons, and empty reports.
- Manual entry, edit, move between days, delete, malformed input, and edits to unfinished sprints.
- Backward-compatible JSON, exact real-disk round trips, unreadable files, failed writes, retry feedback, and forced concurrent write ordering.
- RFC-4180 CSV escaping and CRLF records, filtered export input, unfinished-record exclusion, and clipboard endpoint consistency.
- Window lifecycle, navigation state, dynamic popover sizing, automatic day rollover, shortcut handling/debounce, status-bar updates, and workspace sleep/wake observer handling.

## Native UI checks

The test app used disposable sample records and separate settings. It did not open or modify the installed app's work log.

Clock-in, pause, resume, clock-out, tag editing, manual entry validation, Return to save, and sidebar shortcuts were exercised through native controls. Search/tag filtering and a CSV save through the macOS save panel were checked. The saved CSV was read back to verify its row and duration.

Fixtures at ₹1,500/hour produced these independently calculated totals:

| Fixture | Net work | Earnings | Completed records / active days |
| --- | --- | --- | --- |
| Today | 1h 55m | ₹2,875 | 1 / 1 |
| Monday, October 12 | 4h 25m | ₹6,625 | 2 / 1 |
| October | 44h 55m | ₹67,375 | 21 / 13 |
| Last 30 Days | 70h 50m | ₹1,06,250 | 33 / 20 |
| All Time, with a 2012 archive record | 71h 50m | ₹1,07,750 | 34 / 21 |

Recovery of a sprint from yesterday at 23:30 to today at 01:30 added two hours and ₹3,000 to yesterday, while today's total stayed unchanged. A one-hour sprint with five minutes of simulated sleep and five minutes awaiting a decision held at 50 minutes; counting sleep as work yielded 55 minutes, while counting it as paused resumed from 50 minutes. Later decision time was excluded. Quick controls showed the same paused work, accumulated break, and selected-day earnings.

The All Time summary remained available in the accessibility tree, and its trend disclosure exposed the archived interval. Chart/heatmap labels and the native dashboard layout were inspected. These are accessibility-control checks, not a full human VoiceOver evaluation.

## Complexity check

Lizard measured Swift functions against the pre-audit v2 commit. Refactoring kept arithmetic and validation in small helpers shared by the reports.

| Function | Before | After |
| --- | --- | --- |
| WeeklyAnalytics.calculate | 12 | 3 |
| MonthlyAnalytics.calculate | 18 | 3 |
| Monthly tag breakdown | 10 | 4 |
| Monthly comparison | 10 | 6 |
| Insights period summary | 11 | 1 |
| Insights trend construction | 7 | 4 |
| Insights annual heatmap | 13 | 3 |
| StatusBarPresenter.update | 15 | 4 |
| StatusBarPresenter.makePillImage | 8 | 2 |
| TimeFormatter.parseTime | 7 | 3 |
| SprintEngine.saveRecoveryEndTime | 7 | 4 |
| DayLogStore.delete(sprintId:) | 8 | 3 |

The new trend-rendering function was also reduced from 14 to 1 during the audit. Its pre-audit form was a computed property, so it is not included as a function-to-function comparison above.

## Verification limits

The Release app is unsigned and has not replaced the installed app. Actual launch-at-login registration, notification permission/delivery, and physical Mac sleep were not executed. Their app logic and error handling were checked with deterministic tests and simulated workspace events. A signed installed build still needs those macOS integration checks.

The global shortcut handlers and debounce were tested; full system-wide shortcut delivery depends on macOS permissions and other software. Disk tests used temporary files rather than the user's existing history. No branch was pushed during this audit.
