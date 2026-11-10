import AppKit
import JayceMouseCore

enum ActivityKind {
    case button(Int, down: Bool)
    case scroll(String)
    case action(String)
    case drag(String)
}

/// Smooth-scroll animation driven by a run-loop timer on the tap thread.
final class ScrollSynth {
    private enum Phase { case idle, gesture, momentum }

    private var settings = ScrollSettings()
    private var vertical = ScrollAnimator(timeConstant: 0.3)
    private var horizontal = ScrollAnimator(timeConstant: 0.3)
    private var verticalQuantizer = PixelQuantizer()
    private var horizontalQuantizer = PixelQuantizer()
    private var lastTick: [Bool: TimeInterval] = [:]
    private var phase = Phase.idle
    private var momentumStarted = false
    private var lastInput: TimeInterval = 0
    private var lastFrame: TimeInterval = 0
    private var timer: CFRunLoopTimer?

    /// How long after the last wheel tick the "finger" is considered still on the trackpad.
    private let gestureHold = 0.06

    func configure(_ new: ScrollSettings) {
        settings = new
        vertical.timeConstant = new.smoothness.timeConstant
        horizontal.timeConstant = new.smoothness.timeConstant
    }

    func addTicks(_ ticks: Double, horizontalAxis: Bool, precise: Bool, quick: Bool, now: TimeInterval) {
        guard ticks != 0 else { return }
        let interval = now - (lastTick[horizontalAxis] ?? 0)
        lastTick[horizontalAxis] = now
        var pixels = ScrollAcceleration.tickPixels(speed: settings.speed, interval: interval, precise: precise, quick: quick)
        pixels *= abs(ticks)
        let direction: Double = (ticks > 0 ? 1 : -1) * (settings.reverseDirection ? -1 : 1)
        let impulse = pixels * direction

        // Reversing direction must take effect at once instead of fighting the glide in flight.
        if horizontalAxis {
            if horizontal.currentVelocity * impulse < 0 { horizontal.cancel() }
            horizontal.addImpulse(impulse)
        } else {
            if vertical.currentVelocity * impulse < 0 { vertical.cancel() }
            vertical.addImpulse(impulse)
        }
        lastInput = now
        if phase == .momentum { endMomentum() }
        startTimerIfNeeded(now: now)
    }

    func cancel() {
        vertical.cancel()
        horizontal.cancel()
        finish()
        stopTimer()
    }

    private func startTimerIfNeeded(now: TimeInterval) {
        guard timer == nil else { return }
        lastFrame = now
        let t = CFRunLoopTimerCreateWithHandler(nil, CFAbsoluteTimeGetCurrent(), 1.0 / 120.0, 0, 0) { [weak self] _ in
            self?.frame()
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), t, .commonModes)
        timer = t
    }

    private func stopTimer() {
        if let timer { CFRunLoopTimerInvalidate(timer) }
        timer = nil
    }

    private func frame() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(max(now - lastFrame, 0.001), 0.05)
        lastFrame = now

        let v = verticalQuantizer.quantize(vertical.step(dt: dt))
        let h = horizontalQuantizer.quantize(horizontal.step(dt: dt))
        let moving = vertical.isActive || horizontal.isActive

        if settings.trackpadSimulation {
            let touching = now - lastInput < gestureHold
            if touching {
                if v != 0 || h != 0 {
                    Synth.postScroll(vertical: v, horizontal: h, phase: phase == .gesture ? Synth.phaseChanged : Synth.phaseBegan)
                    phase = .gesture
                }
            } else {
                if phase == .gesture {
                    Synth.postScroll(vertical: 0, horizontal: 0, phase: Synth.phaseEnded)
                    phase = .momentum
                    momentumStarted = false
                }
                if v != 0 || h != 0 {
                    // The glide after the "finger" lifts is momentum, so apps stop it at the edge instead of stretching.
                    Synth.postScroll(vertical: v, horizontal: h, phase: nil, momentum: momentumStarted ? Synth.phaseChanged : Synth.phaseBegan)
                    momentumStarted = true
                    phase = .momentum
                }
            }
        } else if v != 0 || h != 0 {
            Synth.postScroll(vertical: v, horizontal: h, phase: nil)
        }

        if !moving {
            finish()
            stopTimer()
        }
    }

    private func endMomentum() {
        if momentumStarted { Synth.postScroll(vertical: 0, horizontal: 0, phase: nil, momentum: Synth.momentumEnded) }
        momentumStarted = false
        phase = .idle
    }

    private func finish() {
        if settings.trackpadSimulation {
            switch phase {
            case .gesture: Synth.postScroll(vertical: 0, horizontal: 0, phase: Synth.phaseEnded)
            case .momentum: endMomentum()
            case .idle: break
            }
        }
        phase = .idle
        momentumStarted = false
        verticalQuantizer.reset()
        horizontalQuantizer.reset()
    }
}

/// Turns a held-button drag into scroll or desktop-switching gestures.
final class DragSynth {
    private var effect: DragEffect?
    private var total = (dx: 0.0, dy: 0.0)
    private var fired = false
    private var scrolling = false
    private var vq = PixelQuantizer()
    private var hq = PixelQuantizer()

    func begin(_ effect: DragEffect) {
        self.effect = effect
        total = (0, 0)
        fired = false
        scrolling = false
        vq.reset()
        hq.reset()
    }

    func move(dx: Double, dy: Double) {
        guard let effect else { return }
        total.dx += dx
        total.dy += dy
        switch effect {
        case .twoFingerSwipe:
            let v = vq.quantize(dy)
            let h = hq.quantize(dx)
            guard v != 0 || h != 0 else { return }
            Synth.postScroll(vertical: v, horizontal: h, phase: scrolling ? Synth.phaseChanged : Synth.phaseBegan)
            scrolling = true
        case .threeFingerSwipe:
            guard !fired else { return }
            let threshold = 70.0
            if abs(total.dx) >= threshold && abs(total.dx) > abs(total.dy) {
                fired = true
                Synth.triggerHotkey(total.dx > 0 ? .moveLeftSpace : .moveRightSpace)
            } else if abs(total.dy) >= threshold {
                fired = true
                Synth.triggerHotkey(total.dy < 0 ? .missionControl : .appExpose)
            }
        }
    }

    func end() {
        guard let effect else { return }
        if effect == .twoFingerSwipe {
            if scrolling { Synth.postScroll(vertical: 0, horizontal: 0, phase: Synth.phaseEnded) }
            if abs(total.dx) > 120 && abs(total.dx) > 2.5 * abs(total.dy) {
                Synth.perform(total.dx > 0 ? .back : .forward)
            }
        }
        self.effect = nil
    }
}

/// Owns the CGEventTap and all remapping state. Everything inside runs on the tap thread.
final class InputEngine {
    var onActivity: ((ActivityKind) -> Void)?
    var onCaptureButton: ((Int) -> Void)?
    private(set) var captureArmed = false

    private let buttons = ButtonEngine()
    private let scroll = ScrollSynth()
    private let drag = DragSynth()
    private var config = AppConfig()
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    private var wakeTimer: CFRunLoopTimer?
    private var captureSwallowUp: Int?
    private var pointerLocked = false
    private var lastPinchFire: TimeInterval = 0
    private var eventCount = 0
    private let stateLock = NSLock()

    var isRunning: Bool { port != nil }

    func start() -> Bool {
        guard port == nil else { return true }
        let mask: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel,
        ]
        let bits = mask.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<InputEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: bits,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DebugLog.write("tapCreate FAILED")
            return false
        }
        DebugLog.write("tapCreate ok")
        port = tap

        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            guard let self else { return }
            self.runLoop = CFRunLoopGetCurrent()
            let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "JayceMouse.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        apply(config)
        return true
    }

    func stop() {
        guard let port else { return }
        onTapThread { [self] in
            scroll.cancel()
            releasePointer()
            buttons.reset()
        }
        CGEvent.tapEnable(tap: port, enable: false)
        CFMachPortInvalidate(port)
        if let runLoop { CFRunLoopStop(runLoop) }
        self.port = nil
        runLoop = nil
    }

    func apply(_ new: AppConfig) {
        stateLock.lock()
        config = new
        stateLock.unlock()
        onTapThread { [self] in
            buttons.setRemaps(new.remaps)
            scroll.configure(new.scroll)
            if new.general.buttonKillSwitch { buttons.reset() }
        }
    }

    func armCapture(_ armed: Bool) {
        stateLock.lock()
        captureArmed = armed
        stateLock.unlock()
    }

    private func onTapThread(_ block: @escaping () -> Void) {
        guard let runLoop else { block(); return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    private func snapshot() -> (AppConfig, Bool) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (config, captureArmed)
    }

    // MARK: Tap callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DebugLog.write("tap disabled by system (\(type.rawValue)), re-enabling")
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Synth.marker {
            return Unmanaged.passUnretained(event)
        }
        let (cfg, capturing) = snapshot()
        let now = ProcessInfo.processInfo.systemUptime
        eventCount += 1
        let isMove = type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged
        if !isMove || eventCount % 2000 == 0 {
            DebugLog.write("event #\(eventCount) type=\(type.rawValue) button=\(event.getIntegerValueField(.mouseEventButtonNumber)) continuous=\(event.getIntegerValueField(.scrollWheelEventIsContinuous)) dy=\(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) fixedDy=\(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)) flags=\(event.flags.rawValue & 0x1E0000)")
        }

        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return handleButton(event: event, type: type, down: true, cfg: cfg, capturing: capturing, now: now)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return handleButton(event: event, type: type, down: false, cfg: cfg, capturing: capturing, now: now)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return handleMove(event: event, cfg: cfg, now: now)
        case .scrollWheel:
            return handleScroll(event: event, cfg: cfg, now: now)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func buttonNumber(_ event: CGEvent, _ type: CGEventType) -> Int {
        switch type {
        case .leftMouseDown, .leftMouseUp: return 0
        case .rightMouseDown, .rightMouseUp: return 1
        default: return Int(event.getIntegerValueField(.mouseEventButtonNumber))
        }
    }

    private func handleButton(event: CGEvent, type: CGEventType, down: Bool, cfg: AppConfig, capturing: Bool, now: TimeInterval) -> Unmanaged<CGEvent>? {
        let button = buttonNumber(event, type)
        onActivity?(.button(button, down: down))

        if capturing && button >= 2 {
            if down {
                captureSwallowUp = button
                onCaptureButton?(button)
            }
            return nil
        }
        if !down, captureSwallowUp == button {
            captureSwallowUp = nil
            return nil
        }
        if cfg.general.buttonKillSwitch { return Unmanaged.passUnretained(event) }

        let flags = ModifierMask(rawValue: event.flags.rawValue).intersection(.all)
        let result = down
            ? buttons.buttonDown(button, flags: flags, now: now)
            : buttons.buttonUp(button, now: now)
        run(result.actions, cfg: cfg)
        schedule(wake: result.wake, now: now)
        return result.swallow ? nil : Unmanaged.passUnretained(event)
    }

    private func handleMove(event: CGEvent, cfg: AppConfig, now: TimeInterval) -> Unmanaged<CGEvent>? {
        if cfg.general.buttonKillSwitch { return Unmanaged.passUnretained(event) }
        let dx = event.getDoubleValueField(.mouseEventDeltaX)
        let dy = event.getDoubleValueField(.mouseEventDeltaY)
        let actions = buttons.pointerMoved(dx: dx, dy: dy, now: now)
        run(actions, cfg: cfg)
        return Unmanaged.passUnretained(event)
    }

    private func handleScroll(event: CGEvent, cfg: AppConfig, now: TimeInterval) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
            return Unmanaged.passUnretained(event)
        }
        let flags = ModifierMask(rawValue: event.flags.rawValue).intersection(.all)
        func ticksOf(_ line: CGEventField, _ fixedPoint: CGEventField) -> Double {
            let whole = event.getIntegerValueField(line)
            return whole != 0 ? Double(whole) : event.getDoubleValueField(fixedPoint)
        }
        let vertical = ticksOf(.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1)
        let horizontalTicks = ticksOf(.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2)
        guard vertical != 0 || horizontalTicks != 0 else { return Unmanaged.passUnretained(event) }

        var effect: ScrollEffect?
        if !cfg.general.buttonKillSwitch { effect = buttons.scrollEffect() }
        if effect == nil, !cfg.general.scrollKillSwitch, cfg.scroll.enabled {
            let s = cfg.scroll
            if flags.contains(s.zoomModifier) { effect = .zoom }
            else if flags.contains(s.horizontalModifier) { effect = .horizontalScroll }
            else if flags.contains(s.quickModifier) { effect = .quickScroll }
            else if flags.contains(s.preciseModifier) { effect = .preciseScroll }
        }

        if effect == nil && (cfg.general.scrollKillSwitch || !cfg.scroll.enabled) {
            return Unmanaged.passUnretained(event)
        }

        let ticks = vertical != 0 ? vertical : horizontalTicks

        switch effect {
        case .zoom:
            Synth.postKey(ticks > 0 ? 24 : 27, flags: .command)
            onActivity?(.scroll("Zoom"))
        case .spacesSwitch:
            Synth.triggerHotkey(ticks > 0 ? .moveLeftSpace : .moveRightSpace)
            onActivity?(.scroll("Switch space"))
        case .desktopAndLaunchpad:
            if now - lastPinchFire > 0.7 {
                lastPinchFire = now
                Synth.triggerHotkey(ticks > 0 ? .launchpad : .showDesktop)
                onActivity?(.scroll("Desktop & Launchpad"))
            }
        case .horizontalScroll:
            scroll.addTicks(ticks, horizontalAxis: true, precise: false, quick: false, now: now)
            onActivity?(.scroll("Horizontal"))
        case .quickScroll:
            scroll.addTicks(ticks, horizontalAxis: horizontalTicks != 0 && vertical == 0, precise: false, quick: true, now: now)
            onActivity?(.scroll("Quick"))
        case .preciseScroll:
            scroll.addTicks(ticks, horizontalAxis: horizontalTicks != 0 && vertical == 0, precise: true, quick: false, now: now)
            onActivity?(.scroll("Precise"))
        case nil:
            scroll.addTicks(ticks, horizontalAxis: horizontalTicks != 0 && vertical == 0, precise: cfg.scroll.preciseByDefault, quick: false, now: now)
            onActivity?(.scroll(cfg.scroll.smoothness == .off ? "Direct" : "Smooth"))
        }
        return nil
    }

    // MARK: Actions

    private func run(_ actions: [ButtonAction], cfg: AppConfig) {
        for action in actions {
            switch action {
            case .perform(let effect):
                onActivity?(.action(Self.describe(effect)))
                Synth.perform(effect)
            case .replayClick(let button, let count):
                Synth.replayClick(button: button, count: count)
            case .dragBegin(let effect, _):
                onActivity?(.drag("Drag started"))
                drag.begin(effect)
                if cfg.general.lockPointerDuringDrag { lockPointer() }
            case .dragMove(let dx, let dy):
                drag.move(dx: dx, dy: dy)
            case .dragEnd:
                drag.end()
                releasePointer()
            }
        }
    }

    private func lockPointer() {
        guard !pointerLocked else { return }
        CGAssociateMouseAndMouseCursorPosition(0)
        pointerLocked = true
    }

    private func releasePointer() {
        guard pointerLocked else { return }
        CGAssociateMouseAndMouseCursorPosition(1)
        pointerLocked = false
    }

    private func schedule(wake: TimeInterval?, now: TimeInterval) {
        if let wakeTimer { CFRunLoopTimerInvalidate(wakeTimer) }
        wakeTimer = nil
        guard let wake else { return }
        let fire = CFAbsoluteTimeGetCurrent() + max(wake - now, 0.001)
        let timer = CFRunLoopTimerCreateWithHandler(nil, fire, 0, 0, 0) { [weak self] _ in
            guard let self else { return }
            let t = ProcessInfo.processInfo.systemUptime
            let result = self.buttons.tick(now: t)
            self.run(result.actions, cfg: self.snapshot().0)
            self.schedule(wake: result.wake, now: t)
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        wakeTimer = timer
    }

    static func describe(_ effect: Effect) -> String { EffectCatalog.title(for: effect) }
}
