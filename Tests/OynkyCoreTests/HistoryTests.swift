import Foundation
import OynkyCore
import Testing

func tempHistory() -> History {
    History(directory: FileManager.default.temporaryDirectory.appending(path: "oynky-tests-\(UUID().uuidString)"))
}

let zen = AppUsage(name: "Zen", cpu: 8.3, watts: 0.003, memory: 7_520_000_000, processes: 36)
let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!

func days(_ n: Int, from date: Date = noon) -> Date {
    Calendar.current.date(byAdding: .day, value: n, to: date)!
}

@Test func recordsComeBackAsWritten() throws {
    let history = tempHistory()
    try history.append([zen], at: noon)
    #expect(history.records(since: noon, now: noon) == [Record(time: noon, app: zen)])
}

@Test func idleSmallAppsAreNotStored() throws {
    let history = tempHistory()
    try history.append([AppUsage(name: "idle", cpu: 0, watts: 0, memory: 5_000_000, processes: 1)], at: noon)
    #expect(history.records(since: noon, now: noon).isEmpty)
}

@Test func recordsSpanSeveralDays() throws {
    let history = tempHistory()
    try history.append([zen], at: days(-1))
    try history.append([zen], at: noon)
    #expect(history.records(since: days(-1), now: noon).count == 2)
    #expect(history.records(since: noon, now: noon).count == 1)
}

@Test func onlySevenDaysAreKept() throws {
    let history = tempHistory()
    try FileManager.default.createDirectory(at: history.directory, withIntermediateDirectories: true)
    try "keep me".write(to: history.directory.appending(path: "notes.txt"), atomically: true, encoding: .utf8)
    for n in -8...0 { try history.append([zen], at: days(n)) }
    let files = try FileManager.default.contentsOfDirectory(atPath: history.directory.path)
    #expect(files.filter { $0.hasSuffix(".tsv") }.count == 7)
    #expect(files.contains("notes.txt"))
}

@Test func aTruncatedLineIsSkipped() throws {
    let history = tempHistory()
    try history.append([zen], at: noon)
    let file = try #require(FileManager.default.contentsOfDirectory(at: history.directory, includingPropertiesForKeys: nil).first)
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("1792580400\tZen\t8.".utf8))  // a crash in the middle of a write
    try handle.close()
    #expect(history.records(since: noon, now: noon).count == 1)
}

@Test func summaryAveragesOverEverySample() {
    let busy = AppUsage(name: "busy", cpu: 60, watts: 0.3, memory: 100, processes: 1)
    let other = AppUsage(name: "other", cpu: 1, watts: 0, memory: 200, processes: 1)
    let later = noon.addingTimeInterval(60)
    let records = [
        Record(time: noon, app: busy),
        Record(time: noon, app: other),
        Record(time: later, app: AppUsage(name: "busy", cpu: 0, watts: 0, memory: 300, processes: 2)),
    ]
    let apps = summary(records).sorted { $0.name < $1.name }
    #expect(apps.map(\.cpu) == [30, 0.5])  // other is missing from the second sample: it counts as idle
    #expect(apps[0].memory == 300)  // the latest, not an average
    #expect(apps[0].processes == 2)
}
