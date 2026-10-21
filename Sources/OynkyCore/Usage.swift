/// What an app used between two snapshots, all its processes together.
public struct AppUsage: Equatable, Sendable {
    public var name: String
    /// Percent of one core, like top: 250 means two and a half cores busy.
    public var cpu: Double
    public var watts: Double
    /// Current footprint, in bytes.
    public var memory: UInt64
    public var processes: Int
    /// Every process runs from a macOS location: not what oynky hunts.
    public var apple: Bool

    public init(name: String, cpu: Double, watts: Double, memory: UInt64, processes: Int, apple: Bool = false) {
        self.name = name
        self.cpu = cpu
        self.watts = watts
        self.memory = memory
        self.processes = processes
        self.apple = apple
    }
}

/// The app a process belongs to: the outermost .app in its path, so Chrome's
/// helpers (nested .app bundles inside Chrome.app) count as Chrome.
/// Anything outside a bundle is named after its executable.
public func appName(path: String) -> String {
    let outside = path.firstRange(of: ".app/").map { path[..<$0.lowerBound] } ?? Substring(path)
    return outside.split(separator: "/").last.map(String.init) ?? path
}

/// macOS's own locations. Apple apps in /Applications (Safari) are not caught: harmless, they rarely hide.
public func isApple(path: String) -> Bool {
    ["/System/", "/usr/", "/bin/", "/sbin/", "/Library/Apple/"].contains { path.hasPrefix($0) }
}

/// Usage per app between two snapshots, in no particular order.
public func usage(from a: Snapshot, to b: Snapshot) -> [AppUsage] {
    guard b.time > a.time else { return [] }
    let elapsed = Double(b.time - a.time)
    let before = Dictionary(a.procs.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })

    var apps: [String: AppUsage] = [:]
    for p in b.procs {
        // A process absent before, or a reused pid, started during the interval: all its usage is new.
        let old = before[p.pid].flatMap { $0.start == p.start ? $0 : nil }
        let name = appName(path: p.path)
        var app = apps[name] ?? AppUsage(name: name, cpu: 0, watts: 0, memory: 0, processes: 0, apple: true)
        app.apple = app.apple && isApple(path: p.path)
        app.cpu += Double(since(old?.cpu, p.cpu)) / elapsed * 100
        app.watts += Double(since(old?.energy, p.energy)) / elapsed  // nJ / ns = W
        app.memory += p.memory
        app.processes += 1
        apps[name] = app
    }
    return Array(apps.values)
}

/// What to rank apps by: shared by the command and the menu bar app.
public enum Sort: String, CaseIterable, Sendable {
    case cpu, energy, memory
}

public func ranked(_ apps: [AppUsage], by sort: Sort) -> [AppUsage] {
    apps.sorted {
        switch sort {
        case .cpu: $0.cpu > $1.cpu
        case .energy: $0.watts > $1.watts
        case .memory: $0.memory > $1.memory
        }
    }
}

/// Counters only grow, but a kernel hiccup must not crash on an underflow.
private func since(_ old: UInt64?, _ new: UInt64) -> UInt64 {
    let old = old ?? 0
    return new > old ? new - old : 0
}
