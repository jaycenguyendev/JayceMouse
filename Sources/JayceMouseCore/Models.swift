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

    public init() {}
}

public struct PointerSettings: Codable, Equatable {
    public var useSystemAcceleration = true
    public var sensitivity: Double = 0.5
    public var acceleration: Double = 0.5

    public init() {}
}

public struct GeneralSettings: Codable, Equatable {
    public var showMenuBarItem = true
    public var launchAtLogin = false
    public var buttonKillSwitch = false
    public var scrollKillSwitch = false
    public var lockPointerDuringDrag = false

    public init() {}
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
