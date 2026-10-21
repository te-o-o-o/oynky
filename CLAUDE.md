# oynky

Finds the apps that quietly use too much CPU, energy or memory on macOS: who, since when, and whether it is normal. Read-only: it observes, it never signals or kills a process. macOS only, Swift, no dependencies.
This project is outside the global stack table on purpose (macOS-only, Swift, like wrkspaces).

| Target | Role | Rule |
|---|---|---|
| `OynkyCore` | libproc snapshots, per-app usage, `Monitor` (any pace in, live view + one history line per minute out), `History` (daily files), findings rules, installs, macOS reports | no AppKit, no UI; rules are pure functions over records, unit-tested |
| `oynky` | one binary: no argument starts the menu bar app (`MenuBar.swift`: pace, events, menu), `oynky top` is the command (`Command.swift`) | thin shells: AppKit and output only, anything both need goes into the core |

## Commands

- `swift build`, `swift test`, `swift run oynky` (app), `swift run oynky top` (command)
- `./bundle.sh`: universal release build packed as `.build/oynky.app` (ad-hoc signed, `LSUIElement`); its `VERSION` is the one version
- Release: bump `VERSION` in `bundle.sh` and the README badges → date the CHANGELOG section → `chore: release X.Y.Z` → `git tag vX.Y.Z && git push --tags`; `release.yml` checks the tag against `VERSION`, tests, packs the app as a `.dmg` and a `.zip`, and publishes the GitHub release
- Only Command Line Tools here (no Xcode): tests use Swift Testing, not XCTest.
- Measure the app at rest: `ps -o time= -p $(pgrep -f oynky.app/Contents/MacOS/oynky)` twice, 2 minutes apart.

## Traps

- rusage times (CPU, start time) are mach ticks (125/3 ns on Apple Silicon): always go through `timebase`. `cpuTimeIsInNanoseconds` guards it.
- Energy is `ri_energy_nj` (rusage v6); `ri_billed_energy` is 0 for most apps.
- Without root, `proc_pid_rusage` fails on other users' processes (~1/3 of them): counted in `Snapshot.unreadable`, never an error.
- Pass the previous snapshot to `snapshot(after:)`: re-reading every path and app name doubled the CPU at rest.
- The app runs on efficiency cores: benchmarks on the command line read ~7× lower than the real cost. Measure the bundled app.
- `#expect`/`#require` cannot call `mutating` methods (`monitor.add`): store the result first.
- `swift test` sometimes fails with "plugin for module 'TestingMacros' not found" (Command Line Tools bug, random): just rerun.
- Test fixtures (`Tests/OynkyCoreTests/Fixtures`) are trimmed by hand: never commit a raw `.diag`, it holds the Mac's identifiers.
- History lines have 7 tab-separated fields; a line that does not parse is skipped, so changing the format silently drops old lines.

## Rules

- Keep `README.md` and `README.fr.md`, `docs/notes.md` and `docs/notes.fr.md` in sync, in the same change.
- Menu text goes through `tr(english, french)`.
- The icon and menu are placeholders (SF Symbols, plain NSMenu) until the design pass: no mascot.
- Commits: one line, Conventional Commits, no body, no trailer.
