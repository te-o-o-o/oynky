# Changelog

## Unreleased

### Added

- Under each process: what it does, who signed it and how it starts (launched by an app, or on its own), with when it runs and whether that is normal for macOS's usual suspects.
- Each app's share of a battery charge over the last 24 hours, and the minutes of battery it costs.
- Notifications for new findings, at most once a day each; a click opens the menu.
- Menu bar app: the apps using the most CPU, energy and memory right now and over the last hour, refreshed every second while the menu is open.
- Apps that keep the CPU busy in the background, while you are not using them.
- Apps whose memory keeps growing for hours without coming back down.
- The resource reports macOS writes itself (CPU, wakeups, disk writes), for third-party apps.
- Apps and background services installed in the last 7 days, with what they used since.
- Seven days of history, one small file per day.
- `oynky top` ranks apps by CPU, energy or memory over an interval, helpers counted with their app.
