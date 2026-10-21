import Foundation

/// One app in one sample of the history.
public struct Record: Equatable, Sendable {
    public var time: Date
    public var app: AppUsage

    public init(time: Date, app: AppUsage) {
        self.time = time
        self.app = app
    }
}

/// The last 7 days of samples, one tab-separated file per local day: small, greppable,
/// and a line cut short by a crash only loses that line.
public struct History: Sendable {
    public let directory: URL
    public static let days = 7

    public init(directory: URL) {
        self.directory = directory
    }

    /// Appends one sample. Starting a new day's file also deletes the files older than 7 days.
    public func append(_ apps: [AppUsage], at time: Date) throws {
        let file = directory.appending(path: Self.fileName(time))
        if !FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: file)
            prune(now: time)
        }
        let stamp = Int(time.timeIntervalSince1970)
        let lines = apps.filter(Self.worthKeeping).map { app in
            let name = app.name.replacing("\t", with: " ").replacing("\n", with: " ")
            return String(format: "%d\t%@\t%.1f\t%.3f\t%llu\t%d\t%d\n", stamp, name, app.cpu, app.watts, app.memory, app.processes, app.apple ? 1 : 0)
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(lines.joined().utf8))
    }

    /// Every record from `since` to now, oldest first. Unreadable lines are skipped.
    public func records(since: Date, now: Date = Date()) -> [Record] {
        var names: [String] = []
        var day = since
        while Self.fileName(day) <= Self.fileName(now) {
            names.append(Self.fileName(day))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        return names.flatMap { name -> [Record] in
            guard let text = try? String(contentsOf: directory.appending(path: name), encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap(Self.parse).filter { $0.time >= since }
        }
    }

    /// Only our own `yyyy-MM-dd.tsv` files are ever deleted.
    func prune(now: Date) {
        let oldest = Self.fileName(Calendar.current.date(byAdding: .day, value: 1 - Self.days, to: now)!)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in files where name.wholeMatch(of: /\d{4}-\d{2}-\d{2}\.tsv/) != nil && name < oldest {
            try? FileManager.default.removeItem(at: directory.appending(path: name))
        }
    }

    // ponytail: fixed thresholds keep a day around 2 MB; tune them once alerts show what they miss.
    public static func worthKeeping(_ app: AppUsage) -> Bool {
        app.cpu >= 0.1 || app.memory >= 50_000_000
    }

    /// Local day, so a file is one day as the user lived it. Sorts like the dates it names.
    static func fileName(_ time: Date) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: time)
        return String(format: "%04d-%02d-%02d.tsv", day.year!, day.month!, day.day!)
    }

    static func parse(_ line: Substring) -> Record? {
        let f = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard f.count == 7, let stamp = Int(f[0]), let cpu = Double(f[2]), let watts = Double(f[3]),
              let memory = UInt64(f[4]), let processes = Int(f[5])
        else { return nil }
        let app = AppUsage(name: String(f[1]), cpu: cpu, watts: watts, memory: memory, processes: processes, apple: f[6] == "1")
        return Record(time: Date(timeIntervalSince1970: TimeInterval(stamp)), app: app)
    }
}

/// Usage per app over a window of records. CPU and energy are averaged over every sample
/// of the window (an app missing from a sample used next to nothing then); memory and
/// processes come from the app's latest sample.
public func summary(_ records: [Record]) -> [AppUsage] {
    let samples = Double(Set(records.map(\.time)).count)
    var apps: [String: AppUsage] = [:]
    for r in records.sorted(by: { $0.time < $1.time }) {
        var app = apps[r.app.name] ?? AppUsage(name: r.app.name, cpu: 0, watts: 0, memory: 0, processes: 0, apple: r.app.apple)
        app.cpu += r.app.cpu / samples
        app.watts += r.app.watts / samples
        app.memory = r.app.memory
        app.processes = r.app.processes
        apps[r.app.name] = app
    }
    return Array(apps.values)
}
