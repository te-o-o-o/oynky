import Darwin
import Foundation
import Security

// What the system itself can say about a process: who signed it, which app launched it,
// whether a background service starts it, and its manual page's one-line summary.
// No network: everything here is read from the Mac.

/// Who signed the code: "Apple", "Google LLC", "App Store"; nil when unsigned or ad-hoc signed.
/// Reads the signature without checking it: it names the author, it does not vouch for the code.
public func signer(path: String) -> String? {
    var code: SecStaticCode?
    guard SecStaticCodeCreateWithPath(URL(filePath: path) as CFURL, [], &code) == errSecSuccess, let code else { return nil }
    var info: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
          let certificates = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [SecCertificate],
          let leaf = certificates.first, let summary = SecCertificateCopySubjectSummary(leaf) as String?
    else { return nil }
    let issuer = certificates.dropFirst().first.flatMap { SecCertificateCopySubjectSummary($0) as String? }
    return signerName(summary, issuer: issuer)
}

/// "Developer ID Application: Google LLC (EQHXZ8M8AV)" → "Google LLC".
/// macOS's own code is told by its issuer: the leaf's name changes between versions
/// ("Software Signing", "macOS Software Signing" on macOS 27).
func signerName(_ summary: String, issuer: String?) -> String {
    if issuer == "Apple Code Signing Certification Authority" { return "Apple" }
    switch summary {
    case "Apple Mac OS Application Signing": return "App Store"
    default:
        let name = summary.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? summary
        return name.replacing(#/ \([A-Z0-9]{10}\)$/#, with: "")
    }
}

/// The app that launched each app's processes, when it is another app: `node` started from a
/// Ghostty shell is "launched by Ghostty". Walks up the parents, through shells and the like;
/// stops at launchd (pid 1), which starts services and apps opened from the Dock or Finder.
public func launchers(in snapshot: Snapshot) -> [String: String] {
    let byPid = Dictionary(snapshot.procs.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
    var found: [String: String] = [:]
    for p in snapshot.procs where found[p.app] == nil {
        var parent = byPid[p.ppid]
        for _ in 0..<16 {
            guard let up = parent, up.pid > 1 else { break }
            if up.app != p.app, up.path.contains(".app/") {
                found[p.app] = up.app
                break
            }
            parent = byPid[up.ppid]
        }
    }
    return found
}

/// Program path → label of the launchd service that starts it, from every launch plist on the Mac.
/// A process listed here starts on its own (at login, at boot, or on demand) rather than from an app.
public func launchServices() -> [String: String] {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let folders = ["/System/Library/LaunchAgents", "/System/Library/LaunchDaemons", "/Library/LaunchAgents", "/Library/LaunchDaemons", home + "/Library/LaunchAgents"]
    var services: [String: String] = [:]
    for folder in folders {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [] where name.hasSuffix(".plist") {
            guard let data = FileManager.default.contents(atPath: folder + "/" + name),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let label = plist["Label"] as? String,
                  let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first
            else { continue }
            services[program] = label
        }
    }
    return services
}

/// The one-line summary of a program's manual page, when it has one: "metadata server" for mds.
public func manSummary(_ program: String) -> String? {
    for section in ["8", "1"] {
        guard let page = try? String(contentsOfFile: "/usr/share/man/man\(section)/\(program).\(section)", encoding: .utf8) else { continue }
        guard let line = page.split(separator: "\n").first(where: { $0.hasPrefix(".Nd ") }) else { return nil }
        let summary = line.dropFirst(4).trimmingCharacters(in: CharacterSet(charactersIn: " \".")).trimmingCharacters(in: .whitespaces)
        return summary.isEmpty ? nil : summary
    }
    return nil
}
