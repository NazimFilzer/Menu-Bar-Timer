# V2 refresh

Compared main at `1ca62ea` with the original v2 at `335fbc9`. The work is on the local `v2` branch in a dedicated worktree. Main's commit and working files remain unchanged.

## Feature comparison

| Area | Main | Original v2 | Updated v2 |
| --- | --- | --- | --- |
| Earnings | Live daily earnings and daily target | Completed daily earnings, weekly and monthly billing | Live daily earnings with v2's currency choice and completed report totals |
| History | Recent seven days in the popover | Weekly and monthly tables | Both, plus a Today date picker for any past day |
| Manual entry | Popover form, break validation, clipboard copy | Dashboard forms and editing | Both entry points, shared validation, synchronized history and analytics |
| Timing | Exact pause math, clamped effective end, rollover handling | Tags and sleep resolution | Both, plus recovery retry and sleep decision delay fixes |
| Keyboard | Global clock and pause shortcuts | Global clock shortcut | Both global shortcuts, view shortcuts, add sprint, form save and cancel |
| Navigation | Menu bar popover | Dashboard with nested Week and Month tabs | Today, Week, Month, Analytics, and Settings directly in a native sidebar |
| Reports | Clipboard export | CSV, custom ranges, trends, heatmap, tag breakdown | Preserved, with aligned heatmap month headers and accessible chart days |

## Daily use

The dashboard keeps clock-in, clock-out, and pause controls visible on every page. Today provides live daily totals, editable sprint tags, a date picker with previous and next day controls, daily goal progress, and sprint history. A rate setup button takes users to Settings when earnings are not configured.

The selected page and window position persist. The sidebar can collapse using macOS's standard control. The window opens at 1140 × 780 and has a 1000 × 650 minimum size to fit the tables.

Icon controls have descriptive accessibility labels. Chart bars are real buttons with date, work duration, earnings, and selection state. Daily progress has an accessibility value. Form fields have labels, keyboard focus remains available, and chart animations respect Reduce Motion.

The heatmap's month labels use the same column positions and horizontal scroll container as its cells. They previously spread across the full card while the fixed-size grid occupied less width.

## Timing and data behavior

Main's exact timestamp pause calculation is preserved. Sleep resolution uses the same wall-clock calculation, excluding the time between wake and the user's decision. Resume cannot skip a pending sleep decision. Clocking out while held excludes the full held interval.

Recovery validation calculates the proposed pause total before saving, so failed retries cannot repeatedly add paused time. Manual forms reject malformed time strings, negative or non-finite breaks, and breaks that consume the whole sprint.

A sprint continues to belong to its start day across midnight. It cannot inflate the next day's live total. Saved changes refresh both the selected day's log and dashboard analytics. Timer ticks do not reload and invalidate the full analytics store every second.

Existing JSON files, tags, editable start dates, clipboard columns, and CSV formatting remain compatible. No storage migration is required.

## Complexity report

Counts were checked manually using decision points plus one, including boolean conditions and ternaries.

| Function or computation | Before | After |
| --- | --- | --- |
| `saveManualSprint` | 10 | 4 |
| Sprint table `filteredSprints` | 9 | 2 |
| Extracted `matchesSearch` | n/a | 2 |
| `SprintEntry.init` with dates | n/a | 5 |
| `SprintEntry.init` with text | n/a | 4 |

Extracted validation into `SprintEntry`, kept search matching in `matchesSearch`, and moved engine state updates into `handleStateChange`. The existing CRUD method signatures remain available.

## Verification

- Original v2 baseline: 522 of 522 assertions passed.
- Combined suites and new regressions: 715 of 715 assertions passed.
- Native Xcode Debug build succeeded with code signing disabled.
- Native sample-data preview checked for layout, page shortcuts, accessible chart values, Command N entry, and Escape dismissal.
- Git whitespace checks passed.

The sample-data preview uses an in-memory sprint store and separate goal settings. The built app has not replaced the installed app. These changes are local and have not been pushed.
