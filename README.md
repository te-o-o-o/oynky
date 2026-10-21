<h1 align="center">oynky</h1>
<p align="center">Finds the apps that quietly eat your Mac. Watches, never kills: a detective, not a bouncer.</p>
<p align="center"><sub>unreleased · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#features">Features</a> · <a href="#install">Install</a> · <a href="#usage">Usage</a> · <a href="#development">Development</a> · <a href="README.fr.md">Français</a></p>

## Features

Activity Monitor tells you how much. oynky tells you who, since when, and whether it is normal.

- **Busy in the background**: an app you have not brought to the front for 30 minutes that still keeps the CPU busy.
- **Memory that never comes back down**: an app whose memory went up hour after hour for 6 hours.
- **Flagged by macOS**: macOS writes its own reports when a process goes over its CPU, wakeup or disk-write limits, in a folder nobody reads. oynky reads it.
- **Installed recently**: the apps and background services added in the last 7 days, with what each one used since, and the processes it left running for good.
- **Live view**: the apps using the most CPU, energy and memory right now and over the last hour, their helpers counted with them (Chrome's renderers are Chrome).
- **Quiet and light**: a menu bar icon that changes when something is worth a look, about 0.2 % of one efficiency core, nothing to set up.
- **Read-only**: oynky reads what macOS already tracks. No root, no network, no helper; it never signals, slows down or kills anything.

**Not yet**: notifications, the real icon and menu design.

## Install

From source (needs the Xcode Command Line Tools, macOS 14 or later):

```sh
git clone https://github.com/te-o-o-o/oynky && cd oynky
./bundle.sh
cp -R .build/oynky.app /Applications/
open /Applications/oynky.app
```

Click the icon and pick **Open at Login** to start it with your session.

## Usage

Click the menu bar icon: findings first, then the live view. While the menu is open it refreshes every second; hover a finding for its details.

The same binary is a command line tool:

```sh
alias oynky=/Applications/oynky.app/Contents/MacOS/oynky
oynky top                    # the 15 apps that used the most CPU over 5 s
oynky top --sort energy      # or --sort memory
oynky top --interval 30 --limit 5
sudo oynky top               # include system daemons, which belong to other users
```

```
APP                                   CPU    ENERGY    MEMORY  PROCS
Zen                                 8.3 %      3 mW   7.52 GB     36
Ghostty                             4.6 %      4 mW  736.2 MB      1
Music                               2.9 %      2 mW  980.4 MB      1
```

CPU is a percentage of one core, like `top`: 250 % means two and a half cores busy.

The history lives in `~/Library/Application Support/oynky/`, one tab-separated file per day, 7 days kept.

## Development

```sh
swift test
swift run oynky              # the menu bar app
swift run oynky top          # the command
```

`OynkyCore` samples processes, keeps the history and holds the rules, with no UI; the `oynky` target is the menu bar app and the command, thin shells over it. Decisions and pitfalls are in [docs/notes.md](docs/notes.md).

## License

[MIT](LICENSE)
