import Foundation

// The rules that turn history into findings. Pure: records in, findings out.
// ponytail: fixed thresholds, picked by hand; tune them against real weeks of history.

/// Third-party apps that kept using the CPU over the window while not in use: the core of "quietly".
/// `inUse` holds the apps brought to the front during the window.
public func backgroundHogs(_ records: [Record], inUse: Set<String>, now: Date, window: TimeInterval = 30 * 60, threshold: Double = 5) -> [AppUsage] {
    let recent = records.filter { $0.time > now - window }
    // A window mostly made of gaps (oynky just started, the Mac slept) proves nothing.
    guard Double(Set(recent.map(\.time)).count) >= window / 60 * 0.8 else { return [] }
    return summary(recent).filter { !$0.apple && !inUse.contains($0.name) && $0.cpu >= threshold }
}

public struct Climb: Equatable, Sendable {
    public var name: String
    public var from: UInt64
    public var to: UInt64

    public init(name: String, from: UInt64, to: UInt64) {
        self.name = name
        self.from = from
        self.to = to
    }
}

/// Third-party apps whose memory went up hour after hour without ever coming back down:
/// the lowest point of each hour is at least the one of the hour before.
public func memoryClimbs(_ records: [Record], now: Date, hours: Int = 6, minGrowth: UInt64 = 300_000_000) -> [Climb] {
    var lows: [String: [UInt64?]] = [:]
    for r in records where !r.app.apple {
        let hour = hours - 1 - Int((now.timeIntervalSince(r.time)) / 3600)
        guard (0..<hours).contains(hour) else { continue }
        var app = lows[r.app.name] ?? Array(repeating: nil, count: hours)
        app[hour] = min(app[hour] ?? .max, r.app.memory)
        lows[r.app.name] = app
    }
    return lows.compactMap { name, lows in
        // Every hour must have been seen: an app restarted halfway is not a leak.
        let lows = lows.compactMap { $0 }
        guard lows.count == hours, zip(lows, lows.dropFirst()).allSatisfy({ $0 <= $1 }),
              let first = lows.first, let last = lows.last, last >= first + minGrowth, last >= first + first / 4
        else { return nil }
        return Climb(name: name, from: first, to: last)
    }
}

/// How many processes of an app have been running for longer than `age`: what an install left running for good.
public func longLived(_ snapshot: Snapshot, app: String, age: UInt64 = 3_600_000_000_000) -> Int {
    snapshot.procs.filter { appName(path: $0.path) == app && snapshot.time >= $0.start + age }.count
}
