<h1 align="center">oynky</h1>
<p align="center">Finds the apps that quietly eat your Mac. Watches, never kills: it's a pig, not a butcher.</p>
<p align="center"><sub>unreleased · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#features">Features</a> · <a href="#install">Install</a> · <a href="#usage">Usage</a> · <a href="#development">Development</a> · <a href="README.fr.md">Français</a></p>

## Features

- **One table per app**: CPU, energy and memory of every app, its helpers and background processes counted with it (Chrome's renderers are Chrome).
- **Real numbers**: CPU and energy are measured over an interval, not read off a since-boot average; memory is the footprint Activity Monitor shows.
- **Read-only**: oynky reads what macOS already tracks for each process. It never signals, slows down or kills anything.
- **Nothing to set up**: no permission to grant, no config, no dependency.

**Not yet**: the menu bar pig, the 7-day history and the alerts (background CPU, memory that never comes back down, new permanent processes after an install).

## Install

From source (needs the Xcode Command Line Tools, macOS 14 or later):

```sh
git clone https://github.com/te-o-o-o/oynky && cd oynky
swift build -c release
cp .build/release/oynky /usr/local/bin/
```

## Usage

```sh
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

## Development

```sh
swift test
swift run oynky top
```

`OynkyCore` samples processes with libproc and turns two samples into per-app usage, with no UI; the `oynky` command is a thin shell over it. Decisions and pitfalls are in [docs/notes.md](docs/notes.md).

## License

[MIT](LICENSE)
