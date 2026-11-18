import Foundation

public struct ModifierMask: OptionSet, Codable, Hashable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let shift = ModifierMask(rawValue: 0x20000)
    public static let control = ModifierMask(rawValue: 0x40000)
    public static let option = ModifierMask(rawValue: 0x80000)
    public static let command = ModifierMask(rawValue: 0x100000)
    public static let all: ModifierMask = [.shift, .control, .option, .command]
}

public enum SymbolicHotkey: Int, Codable, CaseIterable, Hashable {
    case missionControl = 32
    case appExpose = 33
    case showDesktop = 36
    case spotlight = 64
    case lookUp = 70
    case appSwitcher = 71
    case moveLeftSpace = 79
    case moveRightSpace = 81
    case launchpad = 160
    case notificationCenter = 163
    case doNotDisturb = 175
    case siri = 176
}

public enum SystemKey: String, Codable, CaseIterable, Hashable {
    case brightnessUp, brightnessDown
    case volumeUp, volumeDown, mute
    case playPause, nextTrack, previousTrack
    case keyboardBrightnessUp, keyboardBrightnessDown
}

public enum DragEffect: String, Codable, CaseIterable, Hashable {
    case twoFingerSwipe
    case threeFingerSwipe
}

public enum ScrollEffect: String, Codable, CaseIterable, Hashable {
    case zoom
    case horizontalScroll
    case quickScroll
    case preciseScroll
    case spacesSwitch
    case desktopAndLaunchpad
}

public struct KeyCombo: Codable, Hashable {
    public var keyCode: UInt16
    public var modifiers: ModifierMask
    public init(keyCode: UInt16, modifiers: ModifierMask) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum Effect: Codable, Hashable {
    case hotkey(SymbolicHotkey)
    case smartZoom
    case keyboard(KeyCombo)
    case mouseButton(Int)
    case system(SystemKey)
    case back
    case forward
    case drag(DragEffect)
    case scroll(ScrollEffect)
}

public enum ButtonGesture: String, Codable, CaseIterable, Hashable {
    case click, doubleClick, tripleClick, hold, drag, scroll

    public var clickLevel: Int? {
        switch self {
        case .click: return 1
        case .doubleClick: return 2
        case .tripleClick: return 3
        default: return nil
        }
    }

    public var isContinuous: Bool { self == .drag || self == .scroll }
}

public struct Remap: Codable, Hashable, Identifiable {
    public var id: UUID
    public var button: Int
    public var gesture: ButtonGesture
    public var modifierButton: Int?
    public var keyboardModifiers: ModifierMask
    public var effect: Effect

    public init(
        id: UUID = UUID(),
        button: Int,
        gesture: ButtonGesture,
        modifierButton: Int? = nil,
        keyboardModifiers: ModifierMask = [],
        effect: Effect
    ) {
        self.id = id
        self.button = button
        self.gesture = gesture
        self.modifierButton = modifierButton
        self.keyboardModifiers = keyboardModifiers
        self.effect = effect
    }

    public var slotKey: String {
        "\(button)|\(gesture.rawValue)|\(modifierButton.map(String.init) ?? "-")|\(keyboardModifiers.rawValue)"
    }
}

public enum ScrollSmoothness: String, Codable, CaseIterable, Hashable {
    case off, low, regular, high
}

public enum ScrollSpeed: String, Codable, CaseIterable, Hashable {
    case low, medium, high
}

/// How scroll-to-zoom is sent to apps.
public enum ZoomStyle: String, Codable, CaseIterable {
    /// A trackpad pinch: zooms in nearly every app, including Excel and WPS.
    case pinch
    /// ⌘= / ⌘−: page zoom in browsers, but other commands in some apps (⌘− deletes cells in Excel).
    case keyboard
}

public struct ScrollSettings: Codable, Equatable {
    public var enabled = true
    public var smoothness: ScrollSmoothness = .high
    public var speed: ScrollSpeed = .medium
    public var reverseDirection = false
    public var trackpadSimulation = true
    public var preciseByDefault = false
    public var horizontalModifier: ModifierMask = .shift
    public var quickModifier: ModifierMask = .control
    public var preciseModifier: ModifierMask = .option
    public var zoomModifier: ModifierMask = .command
    public var zoomStyle: ZoomStyle = .pinch

    public init() {}

    // Missing or unknown keys fall back to defaults, so older config files keep their scroll settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ScrollSettings()
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? d.enabled
        smoothness = (try? c.decodeIfPresent(ScrollSmoothness.self, forKey: .smoothness)) ?? d.smoothness
        speed = (try? c.decodeIfPresent(ScrollSpeed.self, forKey: .speed)) ?? d.speed
        reverseDirection = (try? c.decodeIfPresent(Bool.self, forKey: .reverseDirection)) ?? d.reverseDirection
        trackpadSimulation = (try? c.decodeIfPresent(Bool.self, forKey: .trackpadSimulation)) ?? d.trackpadSimulation
        preciseByDefault = (try? c.decodeIfPresent(Bool.self, forKey: .preciseByDefault)) ?? d.preciseByDefault
        horizontalModifier = (try? c.decodeIfPresent(ModifierMask.self, forKey: .horizontalModifier)) ?? d.horizontalModifier
        quickModifier = (try? c.decodeIfPresent(ModifierMask.self, forKey: .quickModifier)) ?? d.quickModifier
        preciseModifier = (try? c.decodeIfPresent(ModifierMask.self, forKey: .preciseModifier)) ?? d.preciseModifier
        zoomModifier = (try? c.decodeIfPresent(ModifierMask.self, forKey: .zoomModifier)) ?? d.zoomModifier
        zoomStyle = (try? c.decodeIfPresent(ZoomStyle.self, forKey: .zoomStyle)) ?? d.zoomStyle
    }

    enum CodingKeys: String, CodingKey {
        case enabled, smoothness, speed, reverseDirection, trackpadSimulation, preciseByDefault
        case horizontalModifier, quickModifier, preciseModifier, zoomModifier, zoomStyle
    }
}

public struct PointerSettings: Codable, Equatable {
    public var useSystemAcceleration = true
    public var sensitivity: Double = 0.5
    public var acceleration: Double = 0.5

    public init() {}
}

public enum AppLanguage: String, Codable, CaseIterable, Hashable {
    case system, english, vietnamese
}

public struct GeneralSettings: Codable, Equatable {
    public var showMenuBarItem = true
    public var launchAtLogin = false
    public var buttonKillSwitch = false
    public var scrollKillSwitch = false
    public var lockPointerDuringDrag = false
    public var language: AppLanguage = .system
    /// Open the settings window when JayceMouse starts. Off: it starts in the menu bar only.
    public var showWindowAtLaunch = false
    /// Move the pointer onto a dialog's default button (OK, Save, Allow…) when the dialog appears.
    public var snapToDefaultButton = true
    /// Rows for connected mice and keyboards (with battery) at the top of the menu bar menu.
    public var showMiceInMenu = true
    public var showKeyboardsInMenu = true

    public init() {}

    // Synthesized decoding requires every key, so a config written before a field existed
    // would fail to decode and reset the user's whole configuration.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GeneralSettings()
        showMenuBarItem = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarItem) ?? defaults.showMenuBarItem
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        buttonKillSwitch = try c.decodeIfPresent(Bool.self, forKey: .buttonKillSwitch) ?? defaults.buttonKillSwitch
        scrollKillSwitch = try c.decodeIfPresent(Bool.self, forKey: .scrollKillSwitch) ?? defaults.scrollKillSwitch
        lockPointerDuringDrag = try c.decodeIfPresent(Bool.self, forKey: .lockPointerDuringDrag) ?? defaults.lockPointerDuringDrag
        language = (try? c.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? defaults.language
        showWindowAtLaunch = try c.decodeIfPresent(Bool.self, forKey: .showWindowAtLaunch) ?? defaults.showWindowAtLaunch
        snapToDefaultButton = try c.decodeIfPresent(Bool.self, forKey: .snapToDefaultButton) ?? defaults.snapToDefaultButton
        showMiceInMenu = try c.decodeIfPresent(Bool.self, forKey: .showMiceInMenu) ?? defaults.showMiceInMenu
        showKeyboardsInMenu = try c.decodeIfPresent(Bool.self, forKey: .showKeyboardsInMenu) ?? defaults.showKeyboardsInMenu
    }

    enum CodingKeys: String, CodingKey {
        case showMenuBarItem, launchAtLogin, buttonKillSwitch, scrollKillSwitch, lockPointerDuringDrag, language
        case showWindowAtLaunch, snapToDefaultButton, showMiceInMenu, showKeyboardsInMenu
    }
}

public struct AppConfig: Codable, Equatable {
    public var scroll = ScrollSettings()
    public var pointer = PointerSettings()
    public var general = GeneralSettings()
    public var remaps: [Remap] = DefaultRemaps.threeButtons

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scroll = try c.decodeIfPresent(ScrollSettings.self, forKey: .scroll) ?? ScrollSettings()
        pointer = try c.decodeIfPresent(PointerSettings.self, forKey: .pointer) ?? PointerSettings()
        general = try c.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? GeneralSettings()
        remaps = try c.decodeIfPresent([Remap].self, forKey: .remaps) ?? DefaultRemaps.threeButtons
    }

    enum CodingKeys: String, CodingKey { case scroll, pointer, general, remaps }
}

public enum DefaultRemaps {
    public static let threeButtons: [Remap] = [
        Remap(button: 2, gesture: .click, effect: .hotkey(.lookUp)),
        Remap(button: 2, gesture: .hold, effect: .hotkey(.showDesktop)),
        Remap(button: 2, gesture: .doubleClick, effect: .hotkey(.launchpad)),
        Remap(button: 2, gesture: .drag, effect: .drag(.threeFingerSwipe)),
    ]

    public static let fiveButtons: [Remap] = [
        Remap(button: 3, gesture: .click, effect: .hotkey(.lookUp)),
        Remap(button: 3, gesture: .scroll, effect: .scroll(.spacesSwitch)),
        Remap(button: 3, gesture: .drag, effect: .drag(.threeFingerSwipe)),
        Remap(button: 4, gesture: .click, effect: .smartZoom),
        Remap(button: 4, gesture: .scroll, effect: .scroll(.zoom)),
        Remap(button: 4, gesture: .drag, effect: .drag(.twoFingerSwipe)),
    ]
}
