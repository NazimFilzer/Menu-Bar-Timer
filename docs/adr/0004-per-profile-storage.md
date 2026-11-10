# Per-Profile Storage in Folders

Profiles must keep their history and settings completely separate, and must be easy to back up or delete as a unit. We store a registry at `SkevalTimer/profiles.json` (profile list, names, colours, active profile id) and give each profile its own folder `SkevalTimer/Profiles/<uuid>/` containing `logs.json` (the same Day Log format as before) and `settings.json` (per-profile goal settings). Per-profile settings move out of the global `UserDefaults` keys; app-wide preferences (launch at login, eye-break reminders, theme) stay in `UserDefaults`.

Switching swaps the storage behind the single `DayLogStore` and reloads `GoalSettings` in place, so the app keeps one `SprintEngine` and one 1-second ticker. Switching is only allowed while the engine is idle, so an open sprint never belongs to an inactive profile.

On first launch without `profiles.json`, the existing `logs.json` and the legacy `UserDefaults` goal keys are copied into a profile named "Skeval", and the original `logs.json` is moved to `SkevalTimer/Backups/`. If the copy fails, the original stays at the old path. If `profiles.json` is ever unreadable, it is moved to `Backups/` and the registry is rebuilt from the profile folders as "Profile 1", "Profile 2", … (the history is kept; names and the active choice are not). Deleting a profile moves its folder to `SkevalTimer/Backups/` instead of erasing it.

Rejected: one shared `logs.json` with a profile id on each sprint (a bug in filtering could leak data between profiles, and deleting a profile would mean rewriting everyone's history), and per-profile `UserDefaults` suites (settings would live apart from the profile's logs, so a folder would not be a complete backup).
