import Darwin
import Foundation
@testable import OynkyCore
import Testing

let ghostty = "/Applications/Ghostty.app/Contents/MacOS/ghostty"

@Test func aToolStartedFromATerminalIsLaunchedByIt() {
    // Ghostty → login → zsh → node: the shells in between are skipped.
    let s = Snapshot(time: 0, procs: [
        Proc(pid: 10, ppid: 1, start: 0, path: ghostty, cpu: 0, energy: 0, memory: 0),
        Proc(pid: 11, ppid: 10, start: 0, path: "/usr/bin/login", cpu: 0, energy: 0, memory: 0),
        Proc(pid: 12, ppid: 11, start: 0, path: "/bin/zsh", cpu: 0, energy: 0, memory: 0),
        Proc(pid: 13, ppid: 12, start: 0, path: "/opt/homebrew/bin/node", cpu: 0, energy: 0, memory: 0),
        Proc(pid: 14, ppid: 10, start: 0, path: ghostty, cpu: 0, energy: 0, memory: 0),
    ])
    let found = launchers(in: s, lookup: { _ in nil })
    #expect(found["node"] == "Ghostty")
    #expect(found["Ghostty"] == nil)  // an app's own child processes do not launch the app
}

@Test func aServiceStartedByLaunchdHasNoLauncher() {
    let s = Snapshot(time: 0, procs: [Proc(pid: 20, ppid: 1, start: 0, path: "/usr/libexec/trustd", cpu: 0, energy: 0, memory: 0)])
    #expect(launchers(in: s, lookup: { _ in nil }).isEmpty)
}

@Test func aRootProcessInTheChainIsCrossed() {
    // Ghostty → login (root: not in the snapshot) → zsh → claude.
    let s = Snapshot(time: 0, procs: [
        Proc(pid: 10, ppid: 1, start: 0, path: ghostty, cpu: 0, energy: 0, memory: 0),
        Proc(pid: 12, ppid: 11, start: 0, path: "/bin/zsh", cpu: 0, energy: 0, memory: 0),
        Proc(pid: 13, ppid: 12, start: 0, path: "/Users/me/.local/bin/claude", cpu: 0, energy: 0, memory: 0),
    ])
    let found = launchers(in: s, lookup: { $0 == 11 ? (ppid: 10, path: "/usr/bin/login") : nil })
    #expect(found["claude"] == "Ghostty")
}

@Test func theParentOfARootProcessIsReadable() {
    // launchd's parent is the kernel (pid 0): readable although launchd belongs to root.
    #expect(parent(of: 1)?.ppid == 0)
    #expect(parent(of: 1)?.path == "/sbin/launchd")
}

@Test func snapshotReadsTheParentProcess() throws {
    let me = try #require(snapshot().procs.first { $0.pid == getpid() })
    #expect(me.ppid == getppid())
}

@Test func macOSBinariesAreSignedByApple() {
    #expect(signature(path: "/bin/ls") == .author("Apple"))
    #expect(signature(path: "/no/such/file") == nil)
}

@Test func manualPagesGiveAOneLineSummary() {
    #expect(manSummary("mds") == "metadata server")
    #expect(manSummary("no-such-program") == nil)
}

@Test func launchServicesKnowMacOSOwnServices() {
    #expect(launchServices().values.contains("com.apple.mediaanalysisd"))
}

@Test func signerNamesDropTheCertificateKindAndTeam() {
    #expect(signerName("Developer ID Application: Google LLC (EQHXZ8M8AV)", issuer: "Developer ID Certification Authority") == "Google LLC")
    #expect(signerName("macOS Software Signing", issuer: "Apple Code Signing Certification Authority") == "Apple")
    #expect(signerName("Apple Mac OS Application Signing", issuer: "Apple Worldwide Developer Relations Certification Authority") == "App Store")
}
