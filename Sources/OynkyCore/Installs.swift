import Foundation

/// Something added recently to where apps and background services get installed.
public struct Install: Equatable, Sendable {
    public enum Kind: Sendable { case app, agent, daemon }

    /// The app it belongs to, named like `AppUsage.name` so the two can be matched.
    public var name: String
    public var kind: Kind
    public var added: Date

    public init(name: String, kind: Kind, added: Date) {
        self.name = name
        self.kind = kind
        self.added = added
    }
}

/// Where installs land, and the kind each place holds.
public let installPlaces: [(URL, Install.Kind)] = {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return [
        (URL(filePath: "/Applications"), .app),
        (home.appending(path: "Applications"), .app),
        (home.appending(path: "Library/LaunchAgents"), .agent),
        (URL(filePath: "/Library/LaunchAgents"), .agent),
        (URL(filePath: "/Library/LaunchDaemons"), .daemon),
    ]
}()

/// What was added to those places since `since`, one entry per app (its earliest addition).
/// The date is when the item landed in the folder, not when it was built: what "installed" means.
public func installs(in places: [(URL, Install.Kind)] = installPlaces, since: Date) -> [Install] {
    var found: [String: Install] = [:]
    for (folder, kind) in places {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.addedToDirectoryDateKey])) ?? []
        for item in items {
            let values = try? item.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
            guard let added = values?.addedToDirectoryDate ?? values?.creationDate, added >= since,
                  let name = kind == .app ? appName(bundle: item) : appName(launchPlist: item)
            else { continue }
            if found[name].map({ $0.added > added }) ?? true { found[name] = Install(name: name, kind: kind, added: added) }
        }
    }
    return found.values.sorted { $0.added > $1.added }
}

func appName(bundle: URL) -> String? {
    bundle.pathExtension == "app" ? bundle.deletingPathExtension().lastPathComponent : nil
}

/// A launch plist names the program it starts: the app owning that program owns the service.
func appName(launchPlist: URL) -> String? {
    guard launchPlist.pathExtension == "plist" else { return nil }
    let plist = (try? Data(contentsOf: launchPlist)).flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]
    let program = plist?["Program"] as? String ?? (plist?["ProgramArguments"] as? [String])?.first
    return program.map { appName(path: $0) } ?? launchPlist.deletingPathExtension().lastPathComponent
}
