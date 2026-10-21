# Notes

## Decisions

- libproc only (`proc_listpids`, `proc_pid_rusage` v6, `proc_pidpath`): public, no entitlement, no private framework.
- CPU and energy are deltas between two snapshots: rusage counters are cumulative since launch, so a burst between two snapshots is still counted, only averaged.
- A process is the pair (pid, start time): a pid reused during the interval is a new process, counted from zero. Its path and app name are read once, then carried from snapshot to snapshot.
- Grouping by the outermost `.app` in the executable path: Chrome's helpers are nested `.app` bundles inside `Google Chrome.app`. Outside a bundle, the executable name.
- Energy is `ri_energy_nj`, not `ri_billed_energy`: the billed one only counts work billed through vouchers and read 0 for Zen at 6 % CPU.
- Memory is `ri_phys_footprint`, the figure Activity Monitor shows as Memory.
- Pace: every 5 s on mains, 15 s on battery, every second while the menu is open, right away on wake and on memory pressure. Timers get 20 % tolerance so macOS can batch the wake-up. The history keeps one line per app per minute (CPU and energy averaged over the minute, memory at its peak), only for apps above 0.1 % CPU or 50 MB: about 2 MB a day.
- Rejected for the pace: Endpoint Security (Apple-granted entitlement, root system extension, Full Disk Access), powermetrics (root), DTrace (SIP), private APIs.
- "macOS's own process" means running from `/System/`, `/usr/`, `/bin/`, `/sbin/` or `/Library/Apple/`. Findings skip those: they are not what oynky hunts and nothing can be done about them.
- Background hog: third-party, ≥ 5 % CPU averaged over 30 minutes, not brought to the front in those 30 minutes, with at least 24 of the 30 minutes in the history (no verdict right after launch or wake).
- Memory climb: third-party, seen in each of the last 6 hours, the lowest point of each hour at least the one of the hour before, and +300 MB and +25 % overall.
- Installs: what landed in `/Applications`, `~/Applications`, `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons` in the last 7 days, dated by `addedToDirectoryDate` (when it landed in the folder, not when it was built). A launch plist is tied to the app owning its `Program`. The folders are watched (DispatchSource), no polling.
- macOS reports: the `.diag` files of `/Library/Logs/DiagnosticReports`, readable by admin users without root (group `_analyticsusers`). Only the first 4 KB are read. Dated by their `End time`: the file date changes when macOS moves files around. Event names seen: `disk writes`, `cpu usage`.

## Not handled yet

- Executables named by version (Claude Code runs `~/.local/share/claude/versions/2.1.306`) show up as `2.1.306`; `proc_name` says the same. Only argv[0] (`KERN_PROCARGS2`) would say `claude`.
- Launch agents outside any `.app` and not installed in the last 7 days are not tied back to their app.
- "In use" means brought to the front: an app playing a video in a window behind another one counts as background.
- Login items registered with `SMAppService` live inside their app and do not show up as installs; their processes still count towards the app.
- A process that lives less than one snapshot interval is not seen at all.
- Notifications, real icon and menu design.

## Verified

| OS | Status |
|---|---|
| macOS 27.0.1 (arm64) | `oynky top` run as a user: ~370 processes read, ~180–240 of other users skipped; CPU in ns checked by a test (200 ms spin); the menu bar app runs from `oynky.app`, writes the history, uses 0.21 s of CPU over 2 min at rest (0.18 % of one core) and 50 MB of RAM; installs found: Thaw, AltTab (through its agent), copycopy; reports found: Zen, rustc, cargo (third-party) and Apple ones filtered out. Menu content not checked by eye yet. Not run with sudo, not run on Intel. |

## Pitfalls

- `ri_user_time`, `ri_system_time` and `ri_proc_start_abstime` are mach ticks, not nanoseconds: 125/3 ns per tick on Apple Silicon, so forgetting `mach_timebase_info` reads 41× too low. On Intel the ratio is 1, which hides the bug.
- `proc_listpids` with a nil buffer returns a size in bytes, not a count of pids.
- `proc_pid_rusage` fails (EPERM) on other users' processes unless run as root: about a third of them on a desktop session.
- A background app runs on the efficiency cores: 2.5 ms of work measured on a performance core shows up as ~18 ms of CPU time there. Measure the bundled app (`ps -o time`), not a benchmark.
- Most of a snapshot's cost was `proc_pidpath` and the app name: reading them once per process halved the app's CPU at rest.
- macOS reports: the first 4 KB also hold other processes' `Path` and `Is First Party` lines, and Apple's own reports have no `Is First Party` line at all. Take the first `Path`, and decide Apple or not from it.
- Regex literals (`/…/`) need `-enable-bare-slash-regex` when compiling the core with `swiftc` directly; SwiftPM sets it.
