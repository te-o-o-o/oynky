# Notes

## Decisions

- libproc only (`proc_listpids`, `proc_pid_rusage` v6, `proc_pidpath`): public, no entitlement, no private framework.
- CPU and energy are deltas between two snapshots: rusage counters are cumulative since launch, so a burst between two snapshots is still counted, only averaged.
- A process is the pair (pid, start time): a pid reused during the interval is a new process, counted from zero. Its path and app name are read once, then carried from snapshot to snapshot.
- Grouping by the outermost `.app` in the executable path: Chrome's helpers are nested `.app` bundles inside `Google Chrome.app`. Outside a bundle, the executable name.
- Energy is `ri_energy_nj`, not `ri_billed_energy`: the billed one only counts work billed through vouchers and read 0 for Zen at 6 % CPU.
- Memory is `ri_phys_footprint`, the figure Activity Monitor shows as Memory.
- Pace: every 5 s on mains, 15 s on battery, every second while the menu is open, right away on wake and on memory pressure. Timers get 20 % tolerance so macOS can batch the wake-up. The history keeps one line per app per minute (CPU and energy averaged over the minute, memory at its peak), only for apps above 0.1 % CPU or 50 MB: about 5 MB a day (~50 apps a minute measured), ~33 MB for the week.
- Rejected for the pace: Endpoint Security (Apple-granted entitlement, root system extension, Full Disk Access), powermetrics (root), DTrace (SIP), private APIs.
- "macOS's own process" means running from `/System/`, `/usr/`, `/bin/`, `/sbin/` or `/Library/Apple/`. Findings skip those: they are not what oynky hunts and nothing can be done about them.
- Background hog: third-party, ≥ 5 % CPU averaged over 30 minutes, not brought to the front in those 30 minutes, with at least 24 of the 30 minutes in the history (no verdict right after launch or wake).
- Memory climb: third-party, seen in each of the last 6 hours, the lowest point of each hour at least the one of the hour before, and +300 MB and +25 % overall.
- Installs: what landed in `/Applications`, `~/Applications`, `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons` in the last 7 days, dated by `addedToDirectoryDate` (when it landed in the folder, not when it was built). A launch plist is tied to the app owning its `Program`. The folders are watched (DispatchSource), no polling.
- macOS reports: the `.diag` files of `/Library/Logs/DiagnosticReports`, readable by admin users without root (group `_analyticsusers`). Only the first 4 KB are read. Dated by their `End time`: the file date changes when macOS moves files around. Event names seen: `disk writes`, `cpu usage`.

- Notifications: one per finding key (`hog:Zen`, `climb:Zen`, `report:Zen:disk writes`, `install:Zen`), at most once a day, the dates kept in UserDefaults (`told`), forgotten after 7 days. macOS reports only notify when less than a day old, so a first launch does not dig up the week. Installs notify once they leave processes running for over an hour.
- "In use" also covers what an app in use launched: `node` or a build started from the terminal you are typing in is not a background hog. Found because Claude Code, running in Ghostty, was flagged.
- Checked end to end: a test program at ~10 % CPU, never brought to the front, was flagged and notified after ~18 minutes (the 30-minute average crossed 5 %).
- Battery: capacity is today's full charge (`BatteryData.FullChargeCapacity` × voltage), not the design capacity. An app's energy over 24 h is the sum of its minutes in the history. Minutes of battery use the Mac's usual draw on battery (`InstantAmperage` × voltage, averaged over the minutes on battery, kept in UserDefaults `draw`): no minutes until the Mac has run on battery.
- Energy figures checked: one performance core at full load reads 2.97 W from `ri_energy_nj`. Most apps show a few mW because they run on the efficiency cores.
- Explanations, all read from the Mac: the signer from the code signature (`SecStaticCode`, not validated: it names the author, it does not vouch for the code); "launched by" by walking up the parent processes to the first other `.app` (shells skipped, stops at launchd); "starts on its own" when a launch plist runs that program (~850 plists, ~40 ms, indexed once); the manual page's `.Nd` line; and `Glossary.swift`, written by hand for ~60 macOS processes, in English and French.
- Programs with no author: ad-hoc signatures (flag 0x2, what the linker and Homebrew produce) are told apart from no signature at all. Then: the script an interpreter runs (only its name, and only when it looks like a file or module name: a command line can hold tokens), where the binary lives (`Place`), its working folder, its creation date, and the quarantine tag (`com.apple.quarantine`: downloading app and date; the site comes from `QuarantineEventsV2`, read-only, when the app recorded it: Zen and Homebrew do not).
- A file named like a version (Claude Code's `2.1.306`) is named after argv[0] (`claude`), read only for such files.
- Parents: `PROC_PIDT_SHORTBSDINFO`, not `PROC_PIDTBSDINFO`: the full one is refused for root's processes, and root's `login` sits between a terminal and its shell, which broke "launched by Ghostty" and the in-use rule for terminal tools.
- Apple's code is told by its signature's issuer (`Apple Code Signing Certification Authority`): the leaf's name changed from "Software Signing" to "macOS Software Signing".

## Not handled yet

- "Launched by" names the first other app up the parents: MCP servers started by Claude Code in Ghostty read "launched by Ghostty", not "by claude".
- Launch agents outside any `.app` and not installed in the last 7 days are not tied back to their app.
- "In use" means brought to the front: an app playing a video in a window behind another one counts as background.
- Login items registered with `SMAppService` live inside their app and do not show up as installs; their processes still count towards the app.
- A process that lives less than one snapshot interval is not seen at all.
- Menu bar managers (Thaw, Bartender) query the status item through Accessibility all the time: that work lands in oynky's main thread and shows in its CPU (0.28 % at rest with Thaw running, 0.18 % before it).
- Manual page summaries are English only; the glossary covers the busiest macOS processes, not all of them.
- XPC services (WebKit pages, video decoders) are started by launchd for an app: the app that asked for them is not known without private APIs.
- Minutes of battery on a Mac that has never run on battery; the draw on battery is not verified yet (the test Mac stayed plugged in).
- Real icon and menu design, small charts.

## Verified

| OS | Status |
|---|---|
| macOS 27.0.1 (arm64) | `oynky top` run as a user: ~370 processes read, ~180–240 of other users skipped; CPU in ns checked by a test (200 ms spin); the menu bar app runs from `oynky.app`, writes the history, uses 0.21 s of CPU over 2 min at rest (0.18 % of one core) and 50 MB of RAM; installs found: Thaw, AltTab (through its agent), copycopy; reports found: Zen, rustc, cargo (third-party) and Apple ones filtered out. Menu checked on a screenshot: explanations under each name (signers, "launched by Raycast", glossary and manual page lines). Battery capacity read (72 Wh), draw on battery not verified. Not run with sudo, not run on Intel. |

## Pitfalls

- `ri_user_time`, `ri_system_time` and `ri_proc_start_abstime` are mach ticks, not nanoseconds: 125/3 ns per tick on Apple Silicon, so forgetting `mach_timebase_info` reads 41× too low. On Intel the ratio is 1, which hides the bug.
- `proc_listpids` with a nil buffer returns a size in bytes, not a count of pids.
- `proc_pid_rusage` fails (EPERM) on other users' processes unless run as root: about a third of them on a desktop session.
- A background app runs on the efficiency cores: 2.5 ms of work measured on a performance core shows up as ~18 ms of CPU time there. Measure the bundled app (`ps -o time`), not a benchmark.
- Most of a snapshot's cost was `proc_pidpath` and the app name: reading them once per process halved the app's CPU at rest.
- macOS reports: the first 4 KB also hold other processes' `Path` and `Is First Party` lines, and Apple's own reports have no `Is First Party` line at all. Take the first `Path`, and decide Apple or not from it.
- Regex literals (`/…/`) need `-enable-bare-slash-regex` when compiling the core with `swiftc` directly; SwiftPM sets it.
