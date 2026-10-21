import Foundation

/// A report macOS writes itself when a process goes over a resource limit (CPU, wakeups, disk writes).
public struct Report: Equatable, Sendable {
    public var name: String
    /// As macOS words it: "cpu usage", "wakeups", "disk writes".
    public var event: String
    /// macOS's one-line explanation, e.g. "2147.52 MB of file backed memory dirtied over 16777 seconds…".
    public var detail: String
    public var date: Date
    public var apple: Bool
}

/// Readable without root by admin users (group _analyticsusers).
public let reportsFolder = URL(filePath: "/Library/Logs/DiagnosticReports")

public func reports(in folder: URL = reportsFolder, since: Date) -> [Report] {
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    return files.compactMap { file -> Report? in
        guard file.pathExtension == "diag",
              let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, date >= since,
              let handle = try? FileHandle(forReadingFrom: file)
        else { return nil }
        defer { try? handle.close() }
        // The fields sit in the first lines; the rest is kilobytes of stack samples.
        let head = (try? handle.read(upToCount: 4096)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return parseReport(head, date: date)
    }.sorted { $0.date > $1.date }
}

func parseReport(_ text: String, date: Date) -> Report? {
    var fields: [String: String] = [:]
    var detail = ""
    var afterAction = false
    for line in text.split(separator: "\n") {
        guard let colon = line.firstIndex(of: ":") else { continue }
        let key = String(line[..<colon])
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        // ponytail: the explanation is the line right after "Action taken" (Writes:, CPU:, Wakeups:); breaks if macOS reorders it.
        if afterAction { detail = value }
        afterAction = key == "Action taken"
        if fields[key] == nil { fields[key] = value }
    }
    guard let event = fields["Event"], let path = fields["Path"] else { return nil }
    // The first Path is the reported process; later ones belong to other processes in the samples.
    // Not "Is First Party": Apple's own reports leave it out, so a later process's "No" would be picked up.
    return Report(name: appName(path: path), event: event, detail: detail, date: date, apple: isApple(path: path))
}
