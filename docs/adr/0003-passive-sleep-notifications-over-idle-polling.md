# Passive Sleep Notifications Over Idle Polling

Continuous monitoring of user idle state via HID event polling or background timers causes periodic CPU wakeups and drains battery on Apple Silicon MacBooks. We decided to omit background idle reminders entirely in favor of an entirely passive, zero-overhead event model that listens exclusively to macOS kernel/workspace push notifications (`NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification`). This guarantees zero CPU and battery impact while the app or Mac is idle.
