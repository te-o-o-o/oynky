import Darwin
import OynkyCore
import Testing

// These read the real machine: they check what libproc actually returns, units included.

@Test func snapshotSeesThisProcess() throws {
    let me = try #require(snapshot().procs.first { $0.pid == getpid() })
    #expect(!me.path.isEmpty)
    #expect(me.memory > 1_000_000)
}

@Test func cpuTimeIsInNanoseconds() throws {
    // Raw rusage times are mach ticks (125/3 ns on Apple Silicon): a missed conversion is off by 41x.
    let before = try #require(snapshot().procs.first { $0.pid == getpid() })
    let end = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) + 200_000_000
    var spin = 0
    while clock_gettime_nsec_np(CLOCK_UPTIME_RAW) < end { spin &+= 1 }
    let after = try #require(snapshot().procs.first { $0.pid == getpid() })
    // Other test threads may burn CPU too, hence the loose upper bound.
    #expect((150_000_000...2_000_000_000).contains(after.cpu - before.cpu), "spun \(spin)")
}
