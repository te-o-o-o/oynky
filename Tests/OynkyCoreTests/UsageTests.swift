import OynkyCore
import Testing

let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
let renderer = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/A/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"

func proc(_ pid: Int32, _ path: String, start: UInt64 = 1, cpu: UInt64 = 0, energy: UInt64 = 0, memory: UInt64 = 0) -> Proc {
    Proc(pid: pid, start: start, path: path, cpu: cpu, energy: energy, memory: memory)
}

let second: UInt64 = 1_000_000_000

@Test func helpersCountAsTheirApp() {
    #expect(appName(path: chrome) == "Google Chrome")
    #expect(appName(path: renderer) == "Google Chrome")
}

@Test func processesOutsideABundleAreNamedAfterTheirExecutable() {
    #expect(appName(path: "/usr/libexec/trustd") == "trustd")
    #expect(appName(path: "/Library/Application Support/Foo/foo-agent") == "foo-agent")
}

@Test func usageAddsUpTheProcessesOfAnApp() {
    let a = Snapshot(time: 0, procs: [proc(10, chrome, cpu: 1 * second), proc(11, renderer, cpu: 5 * second)])
    let b = Snapshot(time: 2 * second, procs: [
        proc(10, chrome, cpu: 2 * second, energy: 0, memory: 100),
        proc(11, renderer, cpu: 7 * second, energy: 0, memory: 300),
    ])
    #expect(usage(from: a, to: b) == [AppUsage(name: "Google Chrome", cpu: 150, watts: 0, memory: 400, processes: 2)])
}

@Test func energyBecomesWatts() {
    let a = Snapshot(time: 0, procs: [proc(10, chrome, energy: 1_000_000_000)])
    let b = Snapshot(time: 4 * second, procs: [proc(10, chrome, energy: 3_000_000_000)])
    #expect(usage(from: a, to: b).first?.watts == 0.5)  // 2 J over 4 s
}

@Test func aProcessStartedDuringTheIntervalCountsInFull() {
    let a = Snapshot(time: 0, procs: [])
    let b = Snapshot(time: second, procs: [proc(10, chrome, cpu: second / 2)])
    #expect(usage(from: a, to: b).first?.cpu == 50)
}

@Test func aReusedPidIsANewProcess() {
    // pid 10 was a busy process that exited; a new one took the pid and used little since.
    let a = Snapshot(time: 0, procs: [proc(10, chrome, start: 1, cpu: 9 * second)])
    let b = Snapshot(time: second, procs: [proc(10, chrome, start: 2, cpu: second / 4)])
    #expect(usage(from: a, to: b).first?.cpu == 25)
}

@Test func noTimeElapsedMeansNoUsage() {
    let a = Snapshot(time: second, procs: [proc(10, chrome)])
    #expect(usage(from: a, to: a).isEmpty)
}

@Test func rankingPutsTheHungriestFirst() {
    let light = AppUsage(name: "light", cpu: 1, watts: 0.5, memory: 10, processes: 1)
    let busy = AppUsage(name: "busy", cpu: 90, watts: 0.1, memory: 5, processes: 1)
    #expect(ranked([light, busy], by: .cpu).map(\.name) == ["busy", "light"])
    #expect(ranked([busy, light], by: .energy).map(\.name) == ["light", "busy"])
    #expect(ranked([busy, light], by: .memory).map(\.name) == ["light", "busy"])
}
