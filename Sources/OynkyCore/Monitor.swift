/// Turns snapshots taken at any pace (every second while watched, every few seconds
/// otherwise, right away on an event) into the live view and one history sample per minute.
public struct Monitor: Sendable {
    /// Usage over the last interval, empty until the second snapshot.
    public private(set) var live: [AppUsage] = []
    public private(set) var last: Snapshot?
    /// The minute being filled: CPU and watts weighted by each interval's length, memory at its peak.
    private var minute: [String: AppUsage] = [:]
    private var filled: UInt64 = 0

    public static let minuteLength: UInt64 = 60_000_000_000

    public init() {}

    /// Returns a minute's average per app once a minute of snapshots has gone by.
    public mutating func add(_ snapshot: Snapshot) -> [AppUsage]? {
        defer { last = snapshot }
        guard let last, snapshot.time > last.time else { return nil }
        live = usage(from: last, to: snapshot)

        let elapsed = snapshot.time - last.time
        for app in live {
            var m = minute[app.name] ?? AppUsage(name: app.name, cpu: 0, watts: 0, memory: 0, processes: 0, apple: app.apple)
            m.cpu += app.cpu * Double(elapsed)
            m.watts += app.watts * Double(elapsed)
            m.memory = max(m.memory, app.memory)
            m.processes = app.processes
            minute[app.name] = m
        }
        filled += elapsed
        guard filled >= Self.minuteLength else { return nil }

        // An app missing from some intervals counts as idle there: divide by the whole minute.
        let done = minute.values.map { m in
            AppUsage(name: m.name, cpu: m.cpu / Double(filled), watts: m.watts / Double(filled), memory: m.memory, processes: m.processes, apple: m.apple)
        }
        minute = [:]
        filled = 0
        return done
    }
}
