# oynky

Finds the apps that quietly use too much CPU, energy or memory on macOS. Read-only: it observes, it never signals or kills a process. macOS only, Swift, no dependencies.
This project is outside the global stack table on purpose (macOS-only, Swift, like wrkspaces).

| Target | Role | Rule |
|---|---|---|
| `OynkyCore` | libproc snapshots, per-app usage between two snapshots | no AppKit, no UI: unit-tested, the future menu bar app reuses it as is |
| `oynky` | `oynky top` command | thin shell: argument parsing and table output only |

Menu bar app, planned: the same `oynky` binary, packed as `oynky.app` (`LSUIElement`) by a `bundle.sh` copied from wrkspaces. No argument starts the menu bar item, `oynky top` stays the command. What both need (ranking, then the 30 to 60 s sampling loop, the daily history files and the alert rules) goes into `OynkyCore`; AppKit stays in the `oynky` target.

## Commands

- `swift build`, `swift test`, `swift run oynky top`
- Only Command Line Tools here (no Xcode): tests use Swift Testing, not XCTest.
- No release yet: `bundle.sh` (the one `VERSION`) and `release.yml` come with the menu bar app, copied from wrkspaces.

## Traps

- rusage CPU times are mach ticks (125/3 ns on Apple Silicon): always go through `timebase`. `cpuTimeIsInNanoseconds` guards it.
- Energy is `ri_energy_nj` (rusage v6); `ri_billed_energy` is 0 for most apps.
- Without root, `proc_pid_rusage` fails on other users' processes (~1/3 of them): counted in `Snapshot.unreadable`, never an error.
- `swift test` sometimes fails with "plugin for module 'TestingMacros' not found" (Command Line Tools bug, random): just rerun.
- Stay at ~0 % CPU when idle: one snapshot every 30 to 60 s, never a tight loop or a per-process timer.

## Rules

- Keep `README.md` and `README.fr.md`, `docs/notes.md` and `docs/notes.fr.md` in sync, in the same change.
- Commits: one line, Conventional Commits, no body, no trailer.
