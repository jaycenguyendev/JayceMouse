import AppKit
import JayceMouseCore

@_silgen_name("CGSGetSymbolicHotKeyValue")
private func CGSGetSymbolicHotKeyValue(_ key: Int32, _ keyEquivalent: UnsafeMutablePointer<UInt16>, _ keyCode: UnsafeMutablePointer<UInt16>, _ modifiers: UnsafeMutablePointer<UInt32>) -> Int32

@_silgen_name("CGSSetSymbolicHotKeyValue")
private func CGSSetSymbolicHotKeyValue(_ key: Int32, _ keyEquivalent: UInt16, _ keyCode: UInt16, _ modifiers: UInt32) -> Int32

@_silgen_name("CGSIsSymbolicHotKeyEnabled")
private func CGSIsSymbolicHotKeyEnabled(_ key: Int32) -> Bool

@_silgen_name("CGSSetSymbolicHotKeyEnabled")
private func CGSSetSymbolicHotKeyEnabled(_ key: Int32, _ enabled: Bool) -> Int32

enum Synth {
    /// Tags every event we post so the tap can ignore its own output.
    static let marker: Int64 = 0x4D46_4C57

    private static let source = CGEventSource(stateID: .hidSystemState)

    static var pointerLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    // MARK: Keys

    static func postKey(_ keyCode: UInt16, flags: ModifierMask = []) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            e.flags = CGEventFlags(rawValue: flags.rawValue)
            e.setIntegerValueField(.eventSourceUserData, value: marker)
            e.post(tap: .cghidEventTap)
        }
    }

    static func postSystemKey(_ key: SystemKey) {
        let code: Int32
        switch key {
        case .volumeUp: code = 0
        case .volumeDown: code = 1
        case .brightnessUp: code = 2
        case .brightnessDown: code = 3
        case .mute: code = 7
        case .playPause: code = 16
        case .nextTrack: code = 17
        case .previousTrack: code = 18
        case .keyboardBrightnessUp: code = 21
        case .keyboardBrightnessDown: code = 22
        }
        for down in [true, false] {
            let state: Int32 = down ? 0xA : 0xB
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: Int((code << 16) | (state << 8)),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    static func describeHotkey(_ hotkey: SymbolicHotkey) -> String {
        var keyEquivalent: UInt16 = 0
        var keyCode: UInt16 = 0
        var modifiers: UInt32 = 0
        let status = CGSGetSymbolicHotKeyValue(Int32(hotkey.rawValue), &keyEquivalent, &keyCode, &modifiers)
        return "status=\(status) enabled=\(CGSIsSymbolicHotKeyEnabled(Int32(hotkey.rawValue))) keyCode=\(keyCode) modifiers=0x\(String(modifiers, radix: 16))"
    }

    static func triggerHotkey(_ hotkey: SymbolicHotkey) {
        let id = Int32(hotkey.rawValue)
        var keyEquivalent: UInt16 = 0
        var keyCode: UInt16 = 0
        var modifiers: UInt32 = 0
        _ = CGSGetSymbolicHotKeyValue(id, &keyEquivalent, &keyCode, &modifiers)
        let wasEnabled = CGSIsSymbolicHotKeyEnabled(id)
        let original = (keyEquivalent, keyCode, modifiers)

        var changedValue = false
        if keyCode == 0xFFFF {
            // No shortcut assigned by the user: borrow an unused one just long enough to fire it.
            keyCode = 0x40
            modifiers = 0
            _ = CGSSetSymbolicHotKeyValue(id, 0xFFFF, keyCode, modifiers)
            changedValue = true
        }
        if !wasEnabled { _ = CGSSetSymbolicHotKeyEnabled(id, true) }

        postKey(keyCode, flags: ModifierMask(rawValue: UInt64(modifiers)))

        if changedValue || !wasEnabled {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
                if changedValue { _ = CGSSetSymbolicHotKeyValue(id, original.0, original.1, original.2) }
                if !wasEnabled { _ = CGSSetSymbolicHotKeyEnabled(id, false) }
            }
        }
    }

    // MARK: Mouse

    static func replayClick(button: Int, count: Int) {
        let location = pointerLocation
        let (downType, upType, cgButton): (CGEventType, CGEventType, CGMouseButton)
        switch button {
        case 0: (downType, upType, cgButton) = (.leftMouseDown, .leftMouseUp, .left)
        case 1: (downType, upType, cgButton) = (.rightMouseDown, .rightMouseUp, .right)
        default: (downType, upType, cgButton) = (.otherMouseDown, .otherMouseUp, .center)
        }
        for i in 1...max(count, 1) {
            for type in [downType, upType] {
                guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: cgButton) else { continue }
                e.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
                e.setIntegerValueField(.mouseEventClickState, value: Int64(i))
                e.setIntegerValueField(.eventSourceUserData, value: marker)
                e.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: Scroll

    static func postScroll(vertical: Int, horizontal: Int, phase: Int64?, momentum: Int64? = nil, continuous: Bool = true) {
        guard let e = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(vertical),
            wheel2: Int32(horizontal),
            wheel3: 0
        ) else { return }
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: continuous ? 1 : 0)
        if let phase { e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase) }
        if let momentum { e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum) }
        e.location = pointerLocation
        e.flags = []
        e.post(tap: .cgSessionEventTap)
    }

    static let phaseBegan: Int64 = 1
    static let phaseChanged: Int64 = 2
    static let phaseEnded: Int64 = 4
    static let momentumEnded: Int64 = 3

    // MARK: Effects

    static func perform(_ effect: Effect) {
        switch effect {
        case .hotkey(let h): triggerHotkey(h)
        case .keyboard(let combo): postKey(combo.keyCode, flags: combo.modifiers)
        case .mouseButton(let b): replayClick(button: b, count: 1)
        case .system(let k): postSystemKey(k)
        case .back: postKey(33, flags: .command)
        case .forward: postKey(30, flags: .command)
        case .smartZoom: postSmartZoom()
        case .drag, .scroll: break
        }
    }

    /// Smart zoom is a trackpad double-tap gesture; synthesising the private gesture event is best-effort.
    private static func postSmartZoom() {
        guard let e = CGEvent(source: source) else { return }
        e.type = CGEventType(rawValue: 32) ?? .null
        e.location = pointerLocation
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        e.post(tap: .cgSessionEventTap)
    }
}
