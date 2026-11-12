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
            case .appExpose: return tr("App Exposé", "Exposé ứng dụng")
            case .showDesktop: return tr("Show Desktop", "Hiển thị màn hình nền")
            case .spotlight: return "Spotlight"
            case .lookUp: return tr("Look Up & Data Detectors", "Tra cứu & Bộ phát hiện dữ liệu")
            case .appSwitcher: return tr("App Switcher", "Trình chuyển ứng dụng")
            case .moveLeftSpace: return tr("Move Left a Space", "Sang Space bên trái")
            case .moveRightSpace: return tr("Move Right a Space", "Sang Space bên phải")
            case .launchpad: return "Launchpad"
            case .notificationCenter: return tr("Notification Center", "Trung tâm thông báo")
            case .doNotDisturb: return tr("Do Not Disturb", "Không làm phiền")
            case .siri: return "Siri"
            }
        case .smartZoom: return tr("Smart Zoom (experimental)", "Thu phóng thông minh (thử nghiệm)")
        case .keyboard(let combo): return KeyNames.describe(combo)
        case .mouseButton(let b): return b == 2 ? tr("Middle Click", "Nhấn chuột giữa") : tr("Button \(b + 1) Click", "Nhấn nút \(b + 1)")
        case .system(let k):
            switch k {
            case .brightnessUp: return tr("Brightness Up", "Tăng độ sáng")
            case .brightnessDown: return tr("Brightness Down", "Giảm độ sáng")
            case .volumeUp: return tr("Volume Up", "Tăng âm lượng")
            case .volumeDown: return tr("Volume Down", "Giảm âm lượng")
            case .mute: return tr("Mute", "Tắt tiếng")
            case .playPause: return tr("Play / Pause", "Phát / Tạm dừng")
            case .nextTrack: return tr("Next Track", "Bài tiếp theo")
            case .previousTrack: return tr("Previous Track", "Bài trước")
            case .keyboardBrightnessUp: return tr("Keyboard Backlight Up", "Tăng đèn bàn phím")
            case .keyboardBrightnessDown: return tr("Keyboard Backlight Down", "Giảm đèn bàn phím")
            }
        case .back: return tr("Back", "Quay lại")
        case .forward: return tr("Forward", "Tiến tới")
        case .drag(let d):
            switch d {
            case .twoFingerSwipe: return tr("Scroll & Navigate", "Cuộn & Điều hướng")
            case .threeFingerSwipe: return tr("Spaces & Mission Control", "Spaces & Mission Control")
            }
        case .scroll(let s):
            switch s {
            case .zoom: return tr("Zoom", "Thu phóng")
            case .horizontalScroll: return tr("Horizontal Scroll", "Cuộn ngang")
            case .quickScroll: return tr("Quick Scroll", "Cuộn nhanh")
            case .preciseScroll: return tr("Precise Scroll", "Cuộn chính xác")
            case .spacesSwitch: return tr("Switch Spaces", "Chuyển Space")
            case .desktopAndLaunchpad: return tr("Desktop & Launchpad", "Màn hình nền & Launchpad")
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
            return [EffectGroup(title: tr("Gestures", "Cử chỉ"), effects: DragEffect.allCases.map { .drag($0) })]
        case .scroll:
            return [EffectGroup(title: tr("While scrolling", "Khi cuộn"), effects: ScrollEffect.allCases.map { .scroll($0) })]
        default:
            return [
                EffectGroup(title: "macOS", effects: [
                    .hotkey(.missionControl), .hotkey(.appExpose), .hotkey(.launchpad), .hotkey(.showDesktop),
                    .hotkey(.spotlight), .hotkey(.siri), .hotkey(.notificationCenter), .hotkey(.doNotDisturb),
                    .hotkey(.lookUp), .smartZoom,
                ]),
                EffectGroup(title: "Spaces", effects: [.hotkey(.moveLeftSpace), .hotkey(.moveRightSpace)]),
                EffectGroup(title: tr("Navigation", "Điều hướng"), effects: [.back, .forward]),
                EffectGroup(title: tr("Media & Display", "Đa phương tiện & Màn hình"), effects: SystemKey.allCases.map { .system($0) }),
                EffectGroup(title: tr("Mouse", "Chuột"), effects: [.mouseButton(2)]),
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
        return out + (names[combo.keyCode] ?? tr("Key \(combo.keyCode)", "Phím \(combo.keyCode)"))
    }
}

extension ButtonGesture {
    var title: String {
        switch self {
        case .click: return tr("Click", "Nhấn")
        case .doubleClick: return tr("Double Click", "Nhấn đúp")
        case .tripleClick: return tr("Triple Click", "Nhấn ba lần")
        case .hold: return tr("Hold", "Giữ")
        case .drag: return tr("Click & Drag", "Nhấn & Kéo")
        case .scroll: return tr("Click & Scroll", "Nhấn & Cuộn")
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

extension ScrollSmoothness {
    var title: String {
        switch self {
        case .off: return tr("Off", "Tắt")
        case .low: return tr("Low", "Thấp")
        case .regular: return tr("Regular", "Vừa")
        case .high: return tr("High", "Cao")
        }
    }
}

extension ScrollSpeed {
    var title: String {
        switch self {
        case .low: return tr("Low", "Chậm")
        case .medium: return tr("Medium", "Vừa")
        case .high: return tr("High", "Nhanh")
        }
    }
}

func buttonName(_ button: Int) -> String {
    switch button {
    case 0: return tr("Left Button", "Nút trái")
    case 1: return tr("Right Button", "Nút phải")
    case 2: return tr("Middle Button", "Nút giữa")
    default: return tr("Button \(button + 1)", "Nút \(button + 1)")
    }
}
