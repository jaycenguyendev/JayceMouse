import Foundation

public enum ConfigStore {
    public static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("JayceMouse", isDirectory: true).appendingPathComponent("config.json")
    }

    /// Settings written under earlier names of the app, newest first.
    private static var legacyFileURLs: [URL] {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ["Scurry", "MouseFlow"].map {
            base.appendingPathComponent($0, isDirectory: true).appendingPathComponent("config.json")
        }
    }

    public static func load(from url: URL = fileURL) -> AppConfig {
        var source = url
        if url == fileURL, !FileManager.default.fileExists(atPath: url.path) {
            source = legacyFileURLs.first { FileManager.default.fileExists(atPath: $0.path) } ?? url
        }
        guard let data = try? Data(contentsOf: source),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return AppConfig() }
        return config
    }

    public static func save(_ config: AppConfig, to url: URL = fileURL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
