import Foundation
import OynkyCore

let help = """
    usage: oynky top [--interval SECONDS] [--limit N] [--sort cpu|energy|memory]

    Ranks the apps that used the most over the interval (default 5 s, top 15, by cpu).
    Helpers and background processes count towards the app they ship in.
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("oynky: \(message)\n\n\(help)\n".utf8))
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
guard args.first == "top" else {
    if ["-h", "--help"].contains(args.first) {
        print(help)
        exit(0)
    }
    fail(args.isEmpty ? "missing command" : "unknown command \(args[0])")
}
args.removeFirst()

var interval = 5.0
var limit = 15
var sort = Sort.cpu
while !args.isEmpty {
    let flag = args.removeFirst()
    guard !args.isEmpty else { fail("\(flag) needs a value") }
    let value = args.removeFirst()
    switch flag {
    case "--interval":
        guard let seconds = Double(value), seconds > 0 else { fail("bad interval \(value)") }
        interval = seconds
    case "--limit":
        guard let n = Int(value), n > 0 else { fail("bad limit \(value)") }
        limit = n
    case "--sort":
        guard let s = Sort(rawValue: value) else { fail("bad sort \(value)") }
        sort = s
    default: fail("bad option \(flag) \(value)")
    }
}

let first = snapshot()
Thread.sleep(forTimeInterval: interval)
let last = snapshot()

let apps = ranked(usage(from: first, to: last), by: sort)

func cell(_ s: String, _ width: Int) -> String {
    String(repeating: " ", count: max(0, width - s.count)) + s
}

let memory = ByteCountFormatter()
memory.countStyle = .memory
print("APP".padding(toLength: 32, withPad: " ", startingAt: 0) + cell("CPU", 9) + cell("ENERGY", 10) + cell("MEMORY", 10) + cell("PROCS", 7))
for app in apps.prefix(limit) {
    print(
        String(app.name.prefix(31)).padding(toLength: 32, withPad: " ", startingAt: 0)
            + cell(String(format: "%.1f %%", app.cpu), 9)
            + cell(String(format: "%.0f mW", app.watts * 1000), 10)
            + cell(memory.string(fromByteCount: Int64(app.memory)), 10)
            + cell(String(app.processes), 7)
    )
}
if last.unreadable > 0 {
    print("\n\(last.unreadable) processes of other users skipped (system daemons): run with sudo to include them.")
}
