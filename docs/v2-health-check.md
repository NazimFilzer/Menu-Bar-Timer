# v2 health check

Checked October 19, 2026, in the existing `v2` checkout.

The decimal earnings display has no recursive calculation or update feedback loop. The engine owns one repeating timer, scheduled once per second. The view model derives earnings from total net work seconds and the hourly rate. Formatting only rounds the displayed value to two decimal places when needed. Reading an earnings label does not change engine state, refresh logs, or save data.

## Fix

The engine's deinitializer removed its workspace observers but left its timer registered with the run loop. The timer captured the engine weakly, so it did not retain the engine, but it could keep waking after the engine was discarded. `SprintEngine.deinit` now invalidates the timer. Regression checks reproduced the issue with both active and paused engines before the fix, then passed afterward.

## Verification

| Check | Result |
| --- | --- |
| `./scripts/run-tests.sh` | 39,923 of 39,923 assertions passed |
| `./scripts/run-tests.sh --runtime-health` | 20 of 20 checks passed with a real AppKit event loop |
| Xcode Debug build with signing disabled | Passed |
| Xcode Analyze with signing disabled | Passed |
| `git diff --check` | Passed |

The earnings stress checks read both daily labels 10,000 times, then sample 24 hours of elapsed time at ten-second intervals. They verify that repeated reads leave engine state, log revision, and storage write count unchanged, and that earnings derive from elapsed time without accumulated rounding drift. Timer disposal checks verify that the engine is released and its timer becomes invalid.

The runtime check uses isolated preferences and in-memory logs. It hosts the Today dashboard and popover, checks real active and pause ticks, verifies that earnings freeze while paused, runs 100 rapid pause/resume cycles, and checks that clock-out persists one sprint and stops updates. Its live intervals total about nine seconds, with a 45-second timeout to catch a hang. No crash or runaway update occurred in these checks.

The suite also covers recovery after interruption, sleep/wake resolution, invalid numeric inputs, persistence failures, analytics, and dashboard window lifecycle. These checks do not establish that every possible macOS or hardware failure is impossible. The existing running timer was not restarted; the cleanup fix is in the v2 source and the new health build.
