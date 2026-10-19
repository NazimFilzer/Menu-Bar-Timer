# Interactive Sleep and Wake Resolution

When macOS enters sleep (`NSWorkspace.willSleepNotification`) during an active Sprint, the engine immediately records the exact sleep timestamp and suspends ticks. Upon wake (`NSWorkspace.didWakeNotification`), the app calculates the Sleep Interval and presents an interactive resolution prompt asking the user whether to include the duration in the sprint or treat it as paused duration. This avoids silent phantom hours while preserving user control over real-world edge cases like working offline on another device during a system sleep.
