import Foundation
import JayceMouseCore

enum UILanguage: String {
    case english, vietnamese

    var locale: Locale { Locale(identifier: self == .vietnamese ? "vi_VN" : "en_US") }
}

extension AppLanguage {
    var resolved: UILanguage {
        switch self {
        case .english: return .english
        case .vietnamese: return .vietnamese
        case .system: return Locale.preferredLanguages.first?.hasPrefix("vi") == true ? .vietnamese : .english
        }
    }

    var displayName: String {
        switch self {
        case .system: return tr("System", "Theo hệ thống")
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        }
    }
}

// Strings live in code rather than in .lproj resources: build-app.sh copies only the binary into
// the bundle, so a SwiftPM resource bundle would be missing from release builds, and switching
// language without a relaunch would mean swapping bundles by hand anyway.
enum L10n {
    static var current: UILanguage = .english
}

func tr(_ english: String, _ vietnamese: String) -> String {
    L10n.current == .vietnamese ? vietnamese : english
}
