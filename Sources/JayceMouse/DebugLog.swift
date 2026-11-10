import Foundation

enum DebugLog {
    static let url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/JayceMouse/debug.log")

    #if DEBUG
    private static let queue = DispatchQueue(label: "JayceMouse.log")
    private static let formatter = ISO8601DateFormatter()

    static func write(_ message: @autoclosure () -> String) {
        let line = "\(formatter.string(from: Date())) \(message())\n"
        queue.async {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? Data(line.utf8).write(to: url)
            }
        }
    }
    #else
    @inline(__always) static func write(_ message: @autoclosure () -> String) {}

    // Earlier releases logged every click and scroll here unconditionally.
    static func removeStaleLog() {
        try? FileManager.default.removeItem(at: url)
    }
    #endif
}
