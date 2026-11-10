#if DEBUG
import AppKit
import JayceMouseCore

/// End-to-end self test: injects synthetic mouse/keyboard events at the HID level, lets the real
/// event tap and remap engine process them, and records what comes out the other side.
/// Debug builds only. Run with: CONFIG=debug Scripts/build-app.sh && open -n build/JayceMouse.app --args --e2e /path/to/report.txt
enum E2E {
    static let testTag: Int64 = 0x7E57

    struct Seen {
        let t: TimeInterval
        let type: CGEventType
        let userData: Int64
        let button: Int
        let keyCode: Int
        let flags: UInt64
        let pointY: Int
        let pointX: Int
        let phase: Int64
        let momentum: Int64
        let continuous: Bool

        var ours: Bool { userData == Synth.marker }
        var tagged: Bool { userData == E2E.testTag }
    }

    final class Recorder {
        private var items: [Seen] = []
        private let lock = NSLock()
        private var port: CFMachPort?

        var count: Int { lock.lock(); defer { lock.unlock() }; return items.count }

        func events(since index: Int) -> [Seen] {
            lock.lock(); defer { lock.unlock() }
            return Array(items[min(index, items.count)...])
        }

        func start() -> Bool {
            let types: [CGEventType] = [
                .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel,
                .keyDown, .keyUp,
            ]
            let bits = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
            let callback: CGEventTapCallBack = { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                Unmanaged<Recorder>.fromOpaque(refcon).takeUnretainedValue().record(type, event)
                return Unmanaged.passUnretained(event)
            }
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap,
                eventsOfInterest: bits, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else { return false }
            port = tap
            let thread = Thread {
                let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                CFRunLoopRun()
            }
            thread.name = "JayceMouse.E2ERecorder"
            thread.start()
            return true
        }

        private func record(_ type: CGEventType, _ e: CGEvent) {
            let item = Seen(
                t: ProcessInfo.processInfo.systemUptime,
                type: type,
                userData: e.getIntegerValueField(.eventSourceUserData),
                button: Int(e.getIntegerValueField(.mouseEventButtonNumber)),
                keyCode: Int(e.getIntegerValueField(.keyboardEventKeycode)),
                flags: e.flags.rawValue & 0x1E0000,
                pointY: Int(e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)),
                pointX: Int(e.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)),
                phase: e.getIntegerValueField(.scrollWheelEventScrollPhase),
                momentum: e.getIntegerValueField(.scrollWheelEventMomentumPhase),
                continuous: e.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            )
            lock.lock(); items.append(item); lock.unlock()
        }
    }

    struct Poster {
        let source = CGEventSource(stateID: .hidSystemState)
        var location: CGPoint

        func post(_ e: CGEvent?, flags: CGEventFlags = []) {
            guard let e else { return }
            e.setIntegerValueField(.eventSourceUserData, value: E2E.testTag)
            e.flags = flags
            e.post(tap: .cghidEventTap)
        }

        func button(_ n: Int, down: Bool, flags: CGEventFlags = []) {
            let type: CGEventType = n == 0 ? (down ? .leftMouseDown : .leftMouseUp)
                : n == 1 ? (down ? .rightMouseDown : .rightMouseUp)
                : (down ? .otherMouseDown : .otherMouseUp)
            let btn: CGMouseButton = n == 0 ? .left : n == 1 ? .right : .center
            let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: btn)
            e?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(n))
            e?.setIntegerValueField(.mouseEventClickState, value: 1)
            post(e, flags: flags)
        }

        func drag(button n: Int, dx: Double, dy: Double, to point: CGPoint) {
            let e = CGEvent(mouseEventSource: source, mouseType: .otherMouseDragged, mouseCursorPosition: point, mouseButton: .center)
            e?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(n))
            e?.setDoubleValueField(.mouseEventDeltaX, value: dx)
            e?.setDoubleValueField(.mouseEventDeltaY, value: dy)
            post(e)
        }

        func move(dx: Double, dy: Double, to point: CGPoint) {
            let e = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
            e?.setDoubleValueField(.mouseEventDeltaX, value: dx)
            e?.setDoubleValueField(.mouseEventDeltaY, value: dy)
            post(e)
        }

        func wheel(_ dy: Int32, dx: Int32 = 0, flags: CGEventFlags = []) {
            let e = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
            e?.location = location
            post(e, flags: flags)
        }
    }

    // MARK: Runner

    static func launchIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--e2e"), i + 1 < args.count else { return }
        let path = args[i + 1]
        Thread.detachNewThread { run(reportPath: path) }
    }

    private static func sleep(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    private static func setConfig(_ mutate: (inout AppConfig) -> Void, base: AppConfig) {
        var cfg = base
        mutate(&cfg)
        DispatchQueue.main.sync { MainActor.assumeIsolated { AppDelegate.model.config = cfg } }
        sleep(0.2)
    }

    private static func run(reportPath: String) {
        var lines: [String] = []
        var failures = 0
        func log(_ s: String) { lines.append(s); try? lines.joined(separator: "\n").appending("\n").write(toFile: reportPath, atomically: true, encoding: .utf8) }
        func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
            if !ok { failures += 1 }
            log("\(ok ? "PASS" : "FAIL")  \(name)\(ok ? "" : "  -> " + detail())")
        }
        func finish() {
            log(failures == 0 ? "RESULT: ALL PASSED" : "RESULT: \(failures) FAILED")
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }

        let configBackup = try? Data(contentsOf: ConfigStore.fileURL)
        defer { if let configBackup { try? configBackup.write(to: ConfigStore.fileURL) } }

        var waited = 0.0
        while waited < 20 {
            let ready = DispatchQueue.main.sync { MainActor.assumeIsolated { AppDelegate.model.engineRunning } }
            if ready { break }
            sleep(0.5); waited += 0.5
        }
        let ready = DispatchQueue.main.sync { MainActor.assumeIsolated { AppDelegate.model.engineRunning } }
        log("E2E start  AX=\(AXIsProcessTrusted()) post=\(CGPreflightPostEventAccess()) listen=\(CGPreflightListenEventAccess()) engineRunning=\(ready)")
        guard ready else {
            check("engine running (Accessibility granted)", false, "event tap is not active")
            finish(); return
        }

        let recorder = Recorder()
        guard recorder.start() else {
            check("observer tap created", false, "could not create observer tap")
            finish(); return
        }
        sleep(0.3)

        let original = DispatchQueue.main.sync { MainActor.assumeIsolated { AppDelegate.model.config } }
        let home = Synth.pointerLocation
        let poster = Poster(location: home)

        let mods: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let modMask: ModifierMask = [.control, .option, .command]
        let f13 = 105, f14 = 107, f15 = 113
        var base = original
        base.general = GeneralSettings()
        base.general.showMenuBarItem = original.general.showMenuBarItem
        base.scroll = ScrollSettings()
        base.scroll.smoothness = .regular
        base.scroll.speed = .medium
        base.remaps = [
            Remap(button: 3, gesture: .click, effect: .keyboard(KeyCombo(keyCode: UInt16(f13), modifiers: modMask))),
            Remap(button: 3, gesture: .doubleClick, effect: .keyboard(KeyCombo(keyCode: UInt16(f14), modifiers: modMask))),
            Remap(button: 3, gesture: .hold, effect: .keyboard(KeyCombo(keyCode: UInt16(f15), modifiers: modMask))),
            Remap(button: 4, gesture: .click, effect: .back),
            Remap(button: 4, gesture: .scroll, effect: .scroll(.zoom)),
            Remap(button: 5, gesture: .drag, effect: .drag(.twoFingerSwipe)),
            Remap(button: 7, gesture: .click, effect: .mouseButton(2)),
            Remap(button: 9, gesture: .hold, effect: .back),
        ]
        setConfig({ _ in }, base: base)

        func keys(_ events: [Seen], down: Bool = true) -> [Seen] {
            events.filter { $0.type == (down ? .keyDown : .keyUp) }
        }
        func scrollOut(_ events: [Seen]) -> [Seen] { events.filter { $0.type == .scrollWheel && $0.ours } }
        func rawScroll(_ events: [Seen]) -> [Seen] { events.filter { $0.type == .scrollWheel && !$0.ours } }

        // 1. Plumbing
        do {
            let mark = recorder.count
            poster.move(dx: 1, dy: 0, to: home)
            sleep(0.2)
            let seen = recorder.events(since: mark)
            check("plumbing: injected event reaches the session", seen.contains { $0.type == .mouseMoved }, "nothing observed (post access?)")
            let tagged = seen.first { $0.type == .mouseMoved }
            check("plumbing: userData survives HID -> session", tagged?.tagged == true, "userData=\(String(describing: tagged?.userData)) (marker-based loop protection would fail)")
        }

        // 2. Marker survival for our own output
        do {
            let mark = recorder.count
            Synth.postKey(UInt16(f13), flags: modMask)
            sleep(0.2)
            let k = keys(recorder.events(since: mark))
            check("marker: Synth key output carries our marker", k.first?.ours == true, "keyDown userData=\(String(describing: k.first?.userData))")
        }
        do {
            let mark = recorder.count
            Synth.replayClick(button: 8, count: 1)
            sleep(0.2)
            let seen = recorder.events(since: mark).filter { $0.type == .otherMouseDown }
            check("marker: replayed click carries our marker", seen.first?.ours == true, "userData=\(String(describing: seen.first?.userData)) count=\(seen.count)")
        }

        // 3. Buttons
        do {
            let mark = recorder.count
            poster.button(8, down: true); sleep(0.03); poster.button(8, down: false)
            sleep(0.4)
            let seen = recorder.events(since: mark)
            check("button: unmanaged button passes through untouched",
                  seen.contains { $0.type == .otherMouseDown && $0.button == 8 && $0.tagged } && seen.contains { $0.type == .otherMouseUp && $0.button == 8 && $0.tagged },
                  "\(seen.map { "\($0.type.rawValue):\($0.button):\($0.userData)" })")
        }
        do {
            let mark = recorder.count
            poster.button(3, down: true); sleep(0.04); poster.button(3, down: false)
            sleep(0.6)
            let seen = recorder.events(since: mark)
            let k = keys(seen)
            check("button: click fires its action once", k.count == 1 && k.first?.keyCode == f13 && k.first?.flags == modMask.rawValue, "keys=\(k.map { "\($0.keyCode)/\($0.flags)" })")
            check("button: remapped click is swallowed", !seen.contains { $0.type == .otherMouseDown && $0.button == 3 }, "original click leaked")
        }
        do {
            let mark = recorder.count
            for _ in 0..<2 { poster.button(3, down: true); sleep(0.04); poster.button(3, down: false); sleep(0.07) }
            sleep(0.6)
            let k = keys(recorder.events(since: mark))
            check("button: double click fires only the double-click action", k.count == 1 && k.first?.keyCode == f14, "keys=\(k.map(\.keyCode))")
        }
        do {
            let mark = recorder.count
            poster.button(3, down: true); sleep(0.55); poster.button(3, down: false)
            sleep(0.4)
            let k = keys(recorder.events(since: mark))
            check("button: hold fires hold action (not click)", k.count == 1 && k.first?.keyCode == f15, "keys=\(k.map(\.keyCode))")
        }
        do {
            let mark = recorder.count
            poster.button(4, down: true); sleep(0.04); poster.button(4, down: false)
            sleep(0.5)
            let k = keys(recorder.events(since: mark))
            check("button: Back action sends Cmd+[", k.count == 1 && k.first?.keyCode == 33 && k.first?.flags == ModifierMask.command.rawValue, "keys=\(k.map { "\($0.keyCode)/\($0.flags)" })")
        }
        do {
            let mark = recorder.count
            poster.button(7, down: true); sleep(0.04); poster.button(7, down: false)
            sleep(0.5)
            let seen = recorder.events(since: mark)
            let down = seen.first { $0.type == .otherMouseDown && $0.ours }
            check("button: remap to Middle Click emits a middle click", down?.button == 2, "\(seen.map { "\($0.type.rawValue):\($0.button):\($0.userData)" })")
        }
        do {
            let mark = recorder.count
            poster.button(9, down: true); sleep(0.04); poster.button(9, down: false)
            sleep(0.5)
            let seen = recorder.events(since: mark)
            let down = seen.first { $0.type == .otherMouseDown && $0.ours }
            check("button: hold-only button still clicks normally on a quick press", down?.button == 9 && keys(seen).isEmpty, "\(seen.map { "\($0.type.rawValue):\($0.button):\($0.userData)" })")
        }

        // 4. Drag gesture
        do {
            let mark = recorder.count
            poster.button(5, down: true)
            var point = home
            for _ in 0..<12 {
                point.y += 6
                poster.drag(button: 5, dx: 0, dy: 6, to: point)
                sleep(0.012)
            }
            sleep(0.1)
            poster.button(5, down: false)
            sleep(0.3)
            poster.move(dx: 0, dy: 0, to: home)
            let seen = recorder.events(since: mark)
            let out = scrollOut(seen)
            let total = out.reduce(0) { $0 + $1.pointY }
            check("drag: two-finger swipe emits scroll events", !out.isEmpty && total != 0, "scroll events=\(out.count) total=\(total)")
            check("drag: swipe tracks pointer travel", abs(abs(total) - 72) <= 12, "total=\(total) expected ~72")
        }

        // 5. Scrolling
        func oneTickTotal(_ dy: Int32, flags: CGEventFlags = [], wait: Double = 1.6) -> (events: [Seen], total: Int) {
            let mark = recorder.count
            poster.wheel(dy, flags: flags)
            sleep(wait)
            let seen = recorder.events(since: mark)
            return (seen, scrollOut(seen).reduce(0) { $0 + $1.pointY })
        }

        do {
            let (seen, total) = oneTickTotal(1)
            let out = scrollOut(seen)
            check("scroll: raw wheel event is replaced", rawScroll(seen).filter { !$0.continuous && $0.tagged }.isEmpty, "raw wheel tick leaked through")
            check("scroll: one tick glides ~66px", abs(total - 66) <= 5, "total=\(total) events=\(out.count)")
            check("scroll: glide spreads over multiple frames", out.count >= 8, "frames=\(out.count)")
            check("scroll: gesture begins, hands off to momentum, then ends",
                  out.first?.phase == 1 && out.contains { $0.phase == 4 } && out.contains { $0.momentum == 1 } && out.last?.momentum == 3,
                  "phases=\(out.map { "\($0.phase)/\($0.momentum)" })")
            check("scroll: output marked continuous", out.dropLast().allSatisfy { $0.continuous }, "not continuous")
        }
        do {
            let (_, total) = oneTickTotal(-1)
            check("scroll: negative tick scrolls the other way", abs(total + 66) <= 5, "total=\(total)")
        }
        do {
            let mark = recorder.count
            poster.wheel(3); sleep(0.05); poster.wheel(-1)
            sleep(1.8)
            let total = scrollOut(recorder.events(since: mark)).reduce(0) { $0 + $1.pointY }
            check("scroll: reversing direction cancels the glide in flight", total < -60, "total=\(total) (should end net negative, not be eaten by the old glide)")
        }
        do {
            setConfig({ $0.scroll.reverseDirection = true }, base: base)
            let (_, total) = oneTickTotal(1)
            check("scroll: reverse direction flips sign", abs(total + 66) <= 5, "total=\(total)")
            setConfig({ _ in }, base: base)
        }
        do {
            setConfig({ $0.scroll.smoothness = .off }, base: base)
            let mark = recorder.count
            poster.wheel(1)
            sleep(0.3)
            let out = scrollOut(recorder.events(since: mark))
            let total = out.reduce(0) { $0 + $1.pointY }
            check("scroll: smoothness off emits instantly", abs(total - 66) <= 3 && out.count <= 3, "total=\(total) frames=\(out.count)")
            setConfig({ _ in }, base: base)
        }
        do {
            setConfig({ $0.scroll.trackpadSimulation = false }, base: base)
            let (seen, total) = oneTickTotal(1)
            check("scroll: trackpad simulation off sends no phases", abs(total - 66) <= 5 && scrollOut(seen).allSatisfy { $0.phase == 0 && $0.momentum == 0 }, "phases=\(Set(scrollOut(seen).map { "\($0.phase)/\($0.momentum)" }))")
            setConfig({ _ in }, base: base)
        }
        do {
            setConfig({ $0.scroll.speed = .high }, base: base)
            let (_, total) = oneTickTotal(1)
            check("scroll: speed High = 108px/tick", abs(total - 108) <= 6, "total=\(total)")
            setConfig({ _ in }, base: base)
        }
        do {
            let mark = recorder.count
            for _ in 0..<6 { poster.wheel(1); sleep(0.012) }
            sleep(1.8)
            let total = scrollOut(recorder.events(since: mark)).reduce(0) { $0 + $1.pointY }
            check("scroll: fast flicks accelerate", Double(total) > 6 * 66 * 1.8, "total=\(total) (no-accel would be \(6 * 66))")
        }
        do {
            let (seen, _) = oneTickTotal(1, flags: .maskShift)
            let out = scrollOut(seen)
            let h = out.reduce(0) { $0 + $1.pointX }
            let v = out.reduce(0) { $0 + $1.pointY }
            check("scroll: Shift+scroll goes horizontal", abs(h) >= 55 && v == 0, "h=\(h) v=\(v)")
        }
        do {
            let (_, total) = oneTickTotal(1, flags: .maskAlternate)
            check("scroll: Option+scroll is precise (~15px)", total > 8 && total < 24, "total=\(total)")
        }
        do {
            let (_, total) = oneTickTotal(1, flags: .maskControl)
            check("scroll: Control+scroll is quick (>2x)", total > 66 * 2, "total=\(total)")
        }
        do {
            let mark = recorder.count
            poster.wheel(1, flags: .maskCommand)
            sleep(0.4)
            let seen = recorder.events(since: mark)
            let k = keys(seen)
            check("scroll: Command+scroll sends zoom shortcut", k.first?.keyCode == 24 && k.first?.flags == ModifierMask.command.rawValue && scrollOut(seen).isEmpty, "keys=\(k.map { "\($0.keyCode)/\($0.flags)" })")
        }
        do {
            let mark = recorder.count
            poster.button(4, down: true); sleep(0.05)
            poster.wheel(-1); sleep(0.3)
            poster.button(4, down: false); sleep(0.5)
            let seen = recorder.events(since: mark)
            let k = keys(seen)
            check("scroll: button+scroll gesture zooms and suppresses click", k.count == 1 && k.first?.keyCode == 27, "keys=\(k.map(\.keyCode))")
        }

        // 6. Kill switches
        do {
            setConfig({ $0.general.scrollKillSwitch = true }, base: base)
            let mark = recorder.count
            poster.wheel(1)
            sleep(0.4)
            let seen = recorder.events(since: mark)
            check("switch: scroll kill switch passes events through", seen.contains { $0.type == .scrollWheel && $0.tagged } && scrollOut(seen).isEmpty, "events=\(seen.map { "\($0.type.rawValue):\($0.userData)" })")
            setConfig({ _ in }, base: base)
        }
        do {
            setConfig({ $0.scroll.enabled = false }, base: base)
            let mark = recorder.count
            poster.wheel(1)
            sleep(0.4)
            let seen = recorder.events(since: mark)
            check("switch: 'Enhance scrolling' off passes events through", seen.contains { $0.type == .scrollWheel && $0.tagged } && scrollOut(seen).isEmpty, "events=\(seen.map { "\($0.type.rawValue):\($0.userData)" })")
            setConfig({ _ in }, base: base)
        }
        do {
            setConfig({ $0.general.buttonKillSwitch = true }, base: base)
            let mark = recorder.count
            poster.button(3, down: true); sleep(0.04); poster.button(3, down: false)
            sleep(0.5)
            let seen = recorder.events(since: mark)
            check("switch: button kill switch passes clicks through", seen.contains { $0.type == .otherMouseDown && $0.button == 3 && $0.tagged } && keys(seen).isEmpty, "events=\(seen.map { "\($0.type.rawValue):\($0.button):\($0.userData)" })")
            setConfig({ _ in }, base: base)
        }

        // 7. Capture mode (used by the remap editor)
        do {
            let engine = DispatchQueue.main.sync { MainActor.assumeIsolated { AppDelegate.model.engine } }
            let previous = engine.onCaptureButton
            var captured: Int?
            engine.onCaptureButton = { captured = $0 }
            engine.armCapture(true)
            let mark = recorder.count
            poster.button(6, down: true); sleep(0.04); poster.button(6, down: false)
            sleep(0.3)
            engine.armCapture(false)
            engine.onCaptureButton = previous
            let seen = recorder.events(since: mark)
            check("capture: next side button is reported and swallowed", captured == 6 && !seen.contains { $0.type == .otherMouseDown && $0.button == 6 }, "captured=\(String(describing: captured))")
        }

        // 8. System hotkeys (read-only diagnostics)
        for hotkey in SymbolicHotkey.allCases {
            log("INFO  hotkey \(hotkey) -> \(Synth.describeHotkey(hotkey))")
        }

        setConfig({ $0 = original }, base: original)
        finish()
    }
}
#endif
