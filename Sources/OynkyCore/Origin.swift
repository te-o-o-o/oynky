import Darwin
import Foundation
import SQLite3

// Where a program comes from, for the ones that carry no author: what it runs, where it lives,
// where it was started from, and whether it was downloaded. All read locally, same user, no root.

/// The program's command line, from the kernel (KERN_PROCARGS2). Nil for other users' processes.
/// Never shown as is: arguments can hold tokens and passwords. See `script(_:)`.
public func arguments(pid: Int32) -> [String]? {
    var mib = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
    // Layout: argc, the executable path, padding zeros, then argc arguments, then the environment.
    let argc = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
    let strings = buffer[4..<size].split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    return Array(strings.dropFirst().prefix(argc))
}

/// The process's current folder. Nil when unreadable.
public func workingDirectory(pid: Int32) -> String? {
    var info = proc_vnodepathinfo()
    guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout<proc_vnodepathinfo>.size)) > 0 else { return nil }
    let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    return path.isEmpty ? nil : path
}

let interpreters: Set<String> = ["node", "bun", "deno", "python", "python3", "ruby", "perl", "php", "java", "Python"]

/// What an interpreter runs: "mcp-pdf-server" for `node …/node_modules/.bin/mcp-pdf-server --stdio`,
/// "http.server" for `python3 -m http.server`. Only a script name, never the other arguments; and
/// only when it looks like a file or module name, so a token passed first is never shown.
public func script(_ arguments: [String]) -> String? {
    guard let program = arguments.first.map({ URL(filePath: $0).lastPathComponent }),
          interpreters.contains(program) || program.hasPrefix("python")
    else { return nil }
    var rest = arguments.dropFirst()[...]
    if let m = rest.firstIndex(of: "-m"), rest.index(after: m) < rest.endIndex { return rest[rest.index(after: m)] }
    rest = rest.drop { $0.hasPrefix("-") }
    guard let first = rest.first,
          first.contains("/") || first.contains(".") || (first.count < 20 && first.allSatisfy { $0.isLetter || $0 == "-" || $0 == "_" })
    else { return nil }
    let name = URL(filePath: first).lastPathComponent
    return name.isEmpty ? nil : name
}

/// The name to show for a program whose file name says nothing: Claude Code runs a file named
/// `2.1.306`, started as `claude`. Nil when the file name already has letters in it.
public func commandName(executable: String, argv0: String) -> String? {
    let file = URL(filePath: executable).lastPathComponent
    let command = URL(filePath: argv0).lastPathComponent
    guard !file.contains(where: \.isLetter), command.contains(where: \.isLetter) else { return nil }
    return command
}

/// Where a program lives, in words the menu can say.
public enum Place: Equatable, Sendable {
    case homebrew, npm, cargo, temporary, build, downloads
    /// Somewhere in the home folder, as "~/workspace/oynky".
    case home(String)
}

public func place(path: String, home: String = NSHomeDirectory()) -> Place? {
    if path.hasPrefix("/opt/homebrew/") || path.hasPrefix("/usr/local/Cellar/") || path.hasPrefix("/usr/local/Homebrew/") { return .homebrew }
    if path.contains("/node_modules/") || path.contains("/_npx/") { return .npm }
    if path.contains("/.cargo/") { return .cargo }
    if path.hasPrefix("/private/tmp/") || path.hasPrefix("/tmp/") || path.hasPrefix("/private/var/folders/") { return .temporary }
    if path.contains("/DerivedData/") || path.contains("/.build/") || path.contains("/target/release/") || path.contains("/target/debug/") { return .build }
    if path.hasPrefix(home + "/Downloads/") { return .downloads }
    if path.hasPrefix(home + "/") {
        return .home("~" + URL(filePath: path).deletingLastPathComponent().path.dropFirst(home.count))
    }
    return nil
}

/// What macOS noted when the file was downloaded: the app that downloaded it and when,
/// and the address when that app recorded one (Safari and Chrome do, Zen and Homebrew do not).
public struct Download: Equatable, Sendable {
    public var agent: String
    public var date: Date
    public var host: String?
}

public func download(path: String) -> Download? {
    let size = getxattr(path, "com.apple.quarantine", nil, 0, 0, 0)
    guard size > 0 else { return nil }
    var value = [UInt8](repeating: 0, count: size)
    guard getxattr(path, "com.apple.quarantine", &value, size, 0, 0) == size,
          var found = parseQuarantine(String(decoding: value, as: UTF8.self))
    else { return nil }
    if let event = String(decoding: value, as: UTF8.self).split(separator: ";").dropFirst(3).first {
        found.host = downloadHost(event: String(event))
    }
    return found
}

/// "01c1;6ad63226;Zen;24AAF532-…": flags, hex Unix time, downloading app, event id.
func parseQuarantine(_ value: String) -> Download? {
    let fields = value.split(separator: ";", omittingEmptySubsequences: false)
    guard fields.count >= 3, let seconds = UInt64(fields[1], radix: 16), !fields[2].isEmpty else { return nil }
    return Download(agent: String(fields[2]), date: Date(timeIntervalSince1970: TimeInterval(seconds)), host: nil)
}

/// The site a download came from, from macOS's download log, read-only.
func downloadHost(event: String) -> String? {
    let log = NSHomeDirectory() + "/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
    var db: OpaquePointer?
    guard sqlite3_open_v2(log, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_close(db) }
    var query: OpaquePointer?
    let sql = "SELECT LSQuarantineOriginURLString, LSQuarantineDataURLString FROM LSQuarantineEvent WHERE LSQuarantineEventIdentifier = ?"
    guard sqlite3_prepare_v2(db, sql, -1, &query, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(query) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)  // SQLITE_TRANSIENT: sqlite copies the string
    sqlite3_bind_text(query, 1, event, -1, transient)
    guard sqlite3_step(query) == SQLITE_ROW else { return nil }
    // The page it was downloaded from says more than the file's own address (often a CDN).
    for column: Int32 in [0, 1] {
        if let text = sqlite3_column_text(query, column), let host = URL(string: String(cString: text))?.host, !host.isEmpty { return host }
    }
    return nil
}
