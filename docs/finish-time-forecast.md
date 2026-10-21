# Finish-time forecast

The daily finish-time estimate appears on **Today** for the current date. **Week** and **Month** each show a separate **When can I finish up?** card for the current period, below its catch-up card. Past periods do not show a forward-looking pace. No storage migration or changes to time accounting.

## Rules

- Finish estimate = now + remaining daily net work + upcoming-break allowance.
- Upcoming breaks default to zero, can be adjusted from 0–240 minutes in five-minute steps, and reset on day rollover/app restart. They are not actual pauses and must be reduced after taking a planned break.
- Active work is credited using the engine's net elapsed time. Paused work remains credited, but the displayed time assumes resuming now. Idle estimates assume starting now.
- Recovery and unresolved sleep hide the daily estimate. Pre-sleep credited work remains in weekly pace, which can change after sleep classification.
- A live sprint started on a previous day cannot advance today's daily goal. Cross-midnight estimates display the end date and explain start-day attribution.
- Weekly remaining work is the full week's scheduled days × daily goal, minus completed work through today and known live net work whose sprint started in this week. The independent weekly goal is not used.
- Divide remaining weekly work by remaining scheduled days (including today only if scheduled). The UI shows the remaining per-day pace and any amount above the normal daily goal. Work on days off still counts; days off remove expected work and available days.
- Weekly pacing uses the daily goal multiplied by scheduled working days in the week. Monthly pacing uses the configured monthly goal. Completed and active net work reduce the target, and the remainder is divided by scheduled days from today through period-end. For example, with a 160-hour monthly goal and 64 hours clocked on October 21, 96 hours remain across 8 working days, or 12 hours per day.
- The Week card shows its scheduled total; the Month card shows the configured monthly goal. Both show work clocked so far. Their daily pace is remaining net work, and the orange note identifies any amount above the normal daily goal. Upcoming-break planning belongs to the daily finish-time estimate on Today.
- No remaining scheduled days produces a clear message, not division by zero. Capacity warnings refer only to scheduled-day calendar time; they do not prohibit overnight/off-day work.
- Calendar-day increments respect DST. Finish timestamps add absolute work/break seconds. Projections round displayed durations up to a minute.
- Engine updates keep active estimates live. A visible, minute-level SwiftUI timeline refreshes conditional idle estimates without a new app-wide polling timer. Render-time `Date()` is used rather than the timeline's older tick date.

## Verification

- Moving weekly pacing to Week and adding monthly pacing: `./scripts/run-tests.sh` passed **926 / 926 assertions**. The suite compiles the SwiftUI cards alongside the domain and view-model checks. No installed-app deployment or visual runtime check was performed for this move.

Original feature verification:

- `./scripts/run-tests.sh`: **39,893 / 39,893 assertions passed**.
- `./scripts/run-tests.sh --runtime-health`: **20 / 20 checks passed** with an actual AppKit event loop.
- Xcode Debug build with signing disabled: **passed**.
- `git diff --check`: **passed**.

Coverage includes planned versus already-taken breaks, active versus paused ETA passage, recovery/sleep holds, sleep resolution, previous-day/week sprint attribution, goals reached, invalid inputs, custom schedules, days off, weekend/no-days-left cases, schedule versus weekly-goal independence, DST 23/25-hour days, CRUD refreshes, and day rollover.

Period pacing also covers monthly active/paused/recovery work, start-month attribution, month rollover, leap days, days off, no remaining working days, and monthly DST capacity. `PeriodPaceForecast` shares the calculation between Week and Month; `FinishForecast` delegates its existing weekly properties to it.

Tests use disposable preferences and in-memory logs. The installed application and the user's work history were not replaced or modified. Real notifications, system sleep, and installed-app deployment were not exercised for this change.

## Complexity report

Manual counts use decision points plus one, including ternaries and boolean conditions.

| Function | Before | After |
| --- | --- | --- |
| Forecast status selection | 8 | 4 |
| Extracted work-status selection | — | 5 |
| Forecast calculation | — | 6 |

Extracted `workStatus` to separate held/recovery/completed-goal decisions from active/paused/idle decisions. Behavior verified by domain and live AppKit regression tests. UI status text remains an exhaustive enum switch rather than introducing another indirection solely to reduce its branch count.

For the period-pacing extraction, manual counts include ternaries and nil-coalescing fallbacks:

| Function | Before | After |
| --- | --- | --- |
| `FinishForecast.calculate` | 8 | 6 |
| `PeriodPaceForecast.calculate` | — | 3 |

The existing weekly forecast properties retain their behavior through delegation. Both dashboard cards use the shared period forecast.
