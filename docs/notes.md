# Notes

## Decisions

- libproc only (`proc_listpids`, `proc_pid_rusage` v6, `proc_pidpath`): public, no entitlement, no private framework, a few milliseconds for ~500 processes.
- CPU and energy are deltas between two samples: rusage counters are cumulative since launch, so a single read only gives a lifetime average.
- A process is the pair (pid, `ri_proc_start_abstime`): a pid reused during the interval is a new process, counted from zero.
- Grouping by the outermost `.app` in the executable path: Chrome's helpers are nested `.app` bundles inside `Google Chrome.app`. Outside a bundle, the executable name.
- Energy is `ri_energy_nj`, not `ri_billed_energy`: the billed one only counts work billed through vouchers and read 0 for Zen at 6 % CPU.
- Memory is `ri_phys_footprint`, the figure Activity Monitor shows as Memory.

## Not handled yet

- Executables named by version (Claude Code runs `~/.local/share/claude/versions/2.1.306`) show up as `2.1.306`; `proc_name` says the same. Only argv[0] (`KERN_PROCARGS2`) would say `claude`.
- Launch agents outside any `.app` (`/Library/Application Support/<vendor>/…`) are not tied back to their app.
- History, alerts, menu bar icon.

## Verified

| OS | Status |
|---|---|
| macOS 27.0.1 (arm64) | `oynky top` run as a user: 330 processes read, 178 of other users skipped; CPU in ns checked by a test (200 ms spin); `--sort energy` gives non-zero mW; release binary takes ~10 MB of RAM and no measurable CPU for a 0.1 s run. Not run with sudo, not run on Intel. |

## Pitfalls

- `ri_user_time` and `ri_system_time` are mach ticks, not nanoseconds: 125/3 ns per tick on Apple Silicon, so forgetting `mach_timebase_info` reads 41× too low. On Intel the ratio is 1, which hides the bug.
- `proc_listpids` with a nil buffer returns a size in bytes, not a count of pids.
- `proc_pid_rusage` fails (EPERM) on other users' processes unless run as root: 178 of 508 on a desktop session.
