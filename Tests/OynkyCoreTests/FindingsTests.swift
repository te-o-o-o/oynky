import Foundation
import OynkyCore
import Testing

/// One record per minute for `minutes` minutes up to `now`, from `app(minute)`.
func minutes(_ minutes: Int, until now: Date = noon, _ app: (Int) -> AppUsage) -> [Record] {
    (0..<minutes).map { m in Record(time: now - TimeInterval((minutes - 1 - m) * 60), app: app(m)) }
}

func usage(_ name: String, cpu: Double = 0, memory: UInt64 = 0, apple: Bool = false) -> AppUsage {
    AppUsage(name: name, cpu: cpu, watts: 0, memory: memory, processes: 1, apple: apple)
}

let gigabyte: UInt64 = 1_000_000_000

@Test func anAppBusyWhileNotInUseIsABackgroundHog() {
    let records = minutes(30) { _ in usage("Sneaky", cpu: 12) }
    #expect(backgroundHogs(records, inUse: [], now: noon).map(\.name) == ["Sneaky"])
}

@Test func appsInUseOrFromAppleAreNotHogs() {
    let records = minutes(30) { _ in usage("Zen", cpu: 12) } + minutes(30) { _ in usage("mds_stores", cpu: 40, apple: true) }
    #expect(backgroundHogs(records, inUse: ["Zen"], now: noon).isEmpty)
}

@Test func aFewMinutesOfHistoryProveNothing() {
    let records = minutes(5) { _ in usage("Sneaky", cpu: 90) }
    #expect(backgroundHogs(records, inUse: [], now: noon).isEmpty)
}

@Test func memoryThatNeverComesBackDownIsAClimb() {
    // 6 h, growing 100 MB an hour with ups and downs inside each hour, never below the hour before.
    let records = minutes(360) { m in usage("Leaky", memory: gigabyte + UInt64(m / 60) * 100_000_000 + UInt64(m % 7) * 10_000_000) }
    #expect(memoryClimbs(records, now: noon) == [Climb(name: "Leaky", from: gigabyte, to: gigabyte + 500_000_000)])
}

@Test func memoryThatComesBackDownIsNotAClimb() {
    let records = minutes(360) { m in usage("Cache", memory: m / 60 == 3 ? gigabyte : gigabyte * 2 + UInt64(m) * 2_000_000) }
    #expect(memoryClimbs(records, now: noon).isEmpty)
}

@Test func anAppSeenForPartOfTheWindowIsNotAClimb() {
    let records = minutes(120) { m in usage("New", memory: gigabyte + UInt64(m) * 10_000_000) }
    #expect(memoryClimbs(records, now: noon).isEmpty)
}

@Test func longLivedCountsProcessesOlderThanAnHour() {
    let hour: UInt64 = 3_600_000_000_000
    let s = Snapshot(time: 3 * hour, procs: [proc(1, chrome, start: 0), proc(2, renderer, start: 2 * hour + hour / 2), proc(3, "/usr/libexec/trustd", start: 0)])
    #expect(longLived(s, app: "Google Chrome") == 1)
}

@Test func installsNameTheAppAndTheAppBehindAService() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "oynky-installs-\(UUID().uuidString)")
    let apps = root.appending(path: "Applications")
    let agents = root.appending(path: "LaunchAgents")
    try FileManager.default.createDirectory(at: apps.appending(path: "Sneaky.app"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
    let plist: [String: Any] = ["Label": "com.vendor.helper", "ProgramArguments": ["/Applications/Vendor.app/Contents/MacOS/helper", "--daemon"]]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: agents.appending(path: "com.vendor.helper.plist"))
    try Data().write(to: apps.appending(path: ".DS_Store"))

    let found = installs(in: [(apps, .app), (agents, .agent)], since: .distantPast)
    #expect(Set(found.map(\.name)) == ["Sneaky", "Vendor"])
    #expect(installs(in: [(apps, .app), (agents, .agent)], since: .distantFuture).isEmpty)
}

@Test func reportsSayWhatMacOSFlagged() {
    let fixtures = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")
    let found = reports(in: fixtures, since: .distantPast).sorted { $0.name < $1.name }
    #expect(found.map(\.name) == ["Zen", "cloudd"])
    #expect(found.map(\.apple) == [false, true])  // cloudd's report also lists Zen's updater: it must not count
    #expect(found[0].event == "disk writes")
    #expect(found[0].detail.hasPrefix("2147.52 MB of file backed memory dirtied"))
    #expect(found[0].date == Date(timeIntervalSince1970: 1_792_484_015.063))  // its End time, 2026-10-20 15:13:35.063 +0700
    #expect(found[1].date == Date(timeIntervalSince1970: 1_792_301_149))  // no End time: its Date/Time
}
