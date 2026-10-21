import OynkyCore
import Testing

func snap(_ seconds: UInt64, cpu: UInt64, memory: UInt64 = 0) -> Snapshot {
    Snapshot(time: seconds * second, procs: [proc(10, chrome, cpu: cpu, memory: memory)])
}

@Test func theFirstSnapshotOnlySetsTheBaseline() {
    var monitor = Monitor()
    let minute = monitor.add(snap(0, cpu: 0))
    #expect(minute == nil)
    #expect(monitor.live.isEmpty)
}

@Test func liveIsTheLastInterval() {
    var monitor = Monitor()
    _ = monitor.add(snap(0, cpu: 0))
    _ = monitor.add(snap(5, cpu: 5 * second))
    #expect(monitor.live.first?.cpu == 100)
}

@Test func aMinuteAveragesIntervalsOfAnyLength() throws {
    var monitor = Monitor()
    _ = monitor.add(snap(0, cpu: 0, memory: 100))
    // 10 s at 100 %, then 50 s idle: the minute averages 16.7 %, its memory is the peak.
    let early = monitor.add(snap(10, cpu: 10 * second, memory: 900))
    #expect(early == nil)
    let added = monitor.add(snap(60, cpu: 10 * second, memory: 300))
    let minute = try #require(added)
    #expect(abs(minute[0].cpu - 100.0 / 6) < 0.001)
    #expect(minute[0].memory == 900)
}

@Test func theNextMinuteStartsFromZero() throws {
    var monitor = Monitor()
    _ = monitor.add(snap(0, cpu: 0))
    _ = monitor.add(snap(60, cpu: 60 * second))
    let added = monitor.add(snap(120, cpu: 60 * second))
    let minute = try #require(added)
    #expect(minute[0].cpu == 0)
}
