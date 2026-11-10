import Foundation
import JayceMouseCore

struct EffectGroup: Identifiable {
    let title: String
    let effects: [Effect]
    var id: String { title }
}

enum EffectCatalog {
    static func title(for effect: Effect) -> String {
        switch effect {
        case .hotkey(let h):
            switch h {
            case .missionControl: return "Mission Control"
            case .appExpose: return "App Exposé"
            case .showDesktop: return "Show Desktop"
            case .spotlight: return "Spotlight"
            case .lookUp: return "Look Up & Data Detectors"
            case .appSwitcher: return "App Switcher"
            case .moveLeftSpace: return "Move Left a Space"
            case .moveRightSpace: return "Move Right a Space"
            case .launchpad: return "Launchpad"
            case .notificationCenter: return "Notification Center"
            case .doNotDisturb: return "Do Not Disturb"
            case .siri: return "Siri"
            }
        case .smartZoom: return "Smart Zoom (experimental)"
        case .keyboard(let combo): return KeyNames.describe(combo)
        case .mouseButton(let b): return b == 2 ? "Middle Click" : "Button \(b + 1) Click"
        case .system(let k):
            switch k {
            case .brightnessUp: return "Brightness Up"
            case .brightnessDown: return "Brightness Down"
            case .volumeUp: return "Volume Up"
            case .volumeDown: return "Volume Down"
            case .mute: return "Mute"
            case .playPause: return "Play / Pause"
            case .nextTrack: return "Next Track"
            case .previousTrack: return "Previous Track"
            case .keyboardBrightnessUp: return "Keyboard Backlight Up"
            case .keyboardBrightnessDown: return "Keyboard Backlight Down"
            }
        case .back: return "Back"
        case .forward: return "Forward"
        case .drag(let d):
            switch d {
            case .twoFingerSwipe: return "Scroll & Navigate"
            case .threeFingerSwipe: return "Spaces & Mission Control"
            }
        case .scroll(let s):
            switch s {
            case .zoom: return "Zoom"
            case .horizontalScroll: return "Horizontal Scroll"
            case .quickScroll: return "Quick Scroll"
            case .preciseScroll: return "Precise Scroll"
            case .spacesSwitch: return "Switch Spaces"
            case .desktopAndLaunchpad: return "Desktop & Launchpad"
            }
        }
    }

    static func symbol(for effect: Effect) -> String {
        switch effect {
        case .hotkey(let h):
            switch h {
            case .missionControl: return "rectangle.3.group"
            case .appExpose: return "square.stack.3d.down.right"
            case .showDesktop: return "menubar.dock.rectangle"
            case .spotlight: return "magnifyingglass"
            case .lookUp: return "text.book.closed"
            case .appSwitcher: return "rectangle.on.rectangle"
            case .moveLeftSpace: return "arrow.left.to.line"
            case .moveRightSpace: return "arrow.right.to.line"
            case .launchpad: return "square.grid.3x3.fill"
            case .notificationCenter: return "bell"
            case .doNotDisturb: return "moon.fill"
            case .siri: return "waveform.circle"
            }
        case .smartZoom: return "plus.magnifyingglass"
        case .keyboard: return "keyboard"
        case .mouseButton: return "computermouse"
        case .system(let k):
            switch k {
            case .brightnessUp, .keyboardBrightnessUp: return "sun.max"
            case .brightnessDown, .keyboardBrightnessDown: return "sun.min"
            case .volumeUp: return "speaker.wave.3"
            case .volumeDown: return "speaker.wave.1"
            case .mute: return "speaker.slash"
            case .playPause: return "playpause"
            case .nextTrack: return "forward.end"
            case .previousTrack: return "backward.end"
            }
        case .back: return "chevron.backward"
        case .forward: return "chevron.forward"
        case .drag(let d): return d == .twoFingerSwipe ? "hand.draw" : "hand.point.up.left"
        case .scroll(let s):
            switch s {
            case .zoom: return "magnifyingglass"
            case .horizontalScroll: return "arrow.left.and.right"
            case .quickScroll: return "hare"
            case .preciseScroll: return "tortoise"
            case .spacesSwitch: return "rectangle.split.3x1"
            case .desktopAndLaunchpad: return "square.grid.3x3.topleft.filled"
            }
        }
    }

    static func groups(for gesture: ButtonGesture) -> [EffectGroup] {
        switch gesture {
        case .drag:
            return [EffectGroup(title: "Gestures", effects: DragEffect.allCases.map { .drag($0) })]
        case .scroll:
            return [EffectGroup(title: "While scrolling", effects: ScrollEffect.allCases.map { .scroll($0) })]
        default:
            return [
                EffectGroup(title: "macOS", effects: [
                    .hotkey(.missionControl), .hotkey(.appExpose), .hotkey(.launchpad), .hotkey(.showDesktop),
                    .hotkey(.spotlight), .hotkey(.siri), .hotkey(.notificationCenter), .hotkey(.doNotDisturb),
                    .hotkey(.lookUp), .smartZoom,
                ]),
                EffectGroup(title: "Spaces", effects: [.hotkey(.moveLeftSpace), .hotkey(.moveRightSpace)]),
                EffectGroup(title: "Navigation", effects: [.back, .forward]),
                EffectGroup(title: "Media & Display", effects: SystemKey.allCases.map { .system($0) }),
                EffectGroup(title: "Mouse", effects: [.mouseButton(2)]),
            ]
        }
    }
}

enum KeyNames {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I",
        35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
    ]

    static func describe(_ combo: KeyCombo) -> String {
        var out = ""
        if combo.modifiers.contains(.control) { out += "⌃" }
        if combo.modifiers.contains(.option) { out += "⌥" }
        if combo.modifiers.contains(.shift) { out += "⇧" }
        if combo.modifiers.contains(.command) { out += "⌘" }
        return out + (names[combo.keyCode] ?? "Key \(combo.keyCode)")
    }
}

extension ButtonGesture {
    var title: String {
        switch self {
        case .click: return "Click"
        case .doubleClick: return "Double Click"
        case .tripleClick: return "Triple Click"
        case .hold: return "Hold"
        case .drag: return "Click & Drag"
        case .scroll: return "Click & Scroll"
        }
    }

    var symbol: String {
        switch self {
        case .click: return "cursorarrow.click"
        case .doubleClick: return "cursorarrow.click.2"
        case .tripleClick: return "cursorarrow.rays"
        case .hold: return "hand.tap"
        case .drag: return "arrow.up.and.down.and.arrow.left.and.right"
        case .scroll: return "computermouse"
        }
    }
}

func buttonName(_ button: Int) -> String {
    switch button {
    case 0: return "Left Button"
    case 1: return "Right Button"
    case 2: return "Middle Button"
    default: return "Button \(button + 1)"
    }
}
