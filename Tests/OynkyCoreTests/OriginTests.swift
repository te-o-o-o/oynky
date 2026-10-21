import Darwin
import Foundation
@testable import OynkyCore
import Testing

@Test func aScriptFileIsUnsigned() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: "oynky-\(UUID().uuidString).sh")
    try "#!/bin/sh\necho hi\n".write(to: file, atomically: true, encoding: .utf8)
    #expect(signature(path: file.path) == .unsigned)
}

@Test func theCommandLineAndFolderOfThisProcessAreReadable() {
    #expect(arguments(pid: getpid())?.first.map { URL(filePath: $0).lastPathComponent } == URL(filePath: CommandLine.arguments[0]).lastPathComponent)
    #expect(workingDirectory(pid: getpid()) == FileManager.default.currentDirectoryPath)
}

@Test func interpretersShowTheirScriptOnly() {
    #expect(script(["node", "/Users/me/.npm/_npx/6583/node_modules/.bin/mcp-pdf-server", "--stdio"]) == "mcp-pdf-server")
    #expect(script(["/opt/homebrew/bin/python3", "-u", "-m", "http.server", "8000"]) == "http.server")
    #expect(script(["ruby", "--disable-gems", "server.rb", "--password", "hunter2"]) == "server.rb")
}

@Test func aTokenIsNeverTakenForAScript() {
    #expect(script(["node", "sk9fQ2xLmP4vR7tY1bN8"]) == nil)
    #expect(script(["zen", "file.html"]) == nil)  // not an interpreter
}

@Test func aVersionNamedFileIsNamedAfterItsCommand() {
    #expect(commandName(executable: "/Users/me/.local/share/claude/versions/2.1.306", argv0: "claude") == "claude")
    #expect(commandName(executable: "/opt/homebrew/bin/node", argv0: "node") == nil)
}

@Test func placesAreNamedInWords() {
    let home = "/Users/me"
    #expect(place(path: "/opt/homebrew/Cellar/node/26.10.0_1/bin/node", home: home) == .homebrew)
    #expect(place(path: "/Users/me/.npm/_npx/6583/node_modules/.bin/mcp-pdf-server", home: home) == .npm)
    #expect(place(path: "/Users/me/.cargo/bin/rustc", home: home) == .cargo)
    #expect(place(path: "/private/tmp/claude-501/scratchpad/hog/sneakyhog", home: home) == .temporary)
    #expect(place(path: "/Users/me/workspace/oynky/.build/release/oynky", home: home) == .build)
    #expect(place(path: "/Users/me/Downloads/tool", home: home) == .downloads)
    #expect(place(path: "/Users/me/workspace/tools/sneakyhog", home: home) == .home("~/workspace/tools"))
    #expect(place(path: "/Applications/Zen.app/Contents/MacOS/zen", home: home) == nil)
}

@Test func theQuarantineTagNamesTheDownloaderAndTheDate() throws {
    let tag = "01c1;6ad63226;Zen;24AAF532-ABC5-42B0-B9F5-F26A3C154438"
    #expect(parseQuarantine(tag) == Download(agent: "Zen", date: Date(timeIntervalSince1970: 0x6ad63226), host: nil))
    #expect(parseQuarantine("garbage") == nil)

    // On a real file, as a browser would tag it.
    let file = FileManager.default.temporaryDirectory.appending(path: "oynky-\(UUID().uuidString)")
    try Data().write(to: file)
    _ = tag.withCString { setxattr(file.path, "com.apple.quarantine", $0, strlen($0), 0, 0) }
    #expect(download(path: file.path)?.agent == "Zen")
}
