import Foundation
import JayceMouseCore

var failures = 0
var checks = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    checks += 1
    if condition() {
        print("  ok   \(name)")
    } else {
        failures += 1
        print("  FAIL \(name)")
    }
}

func section(_ title: String) { print("\n\(title)") }

section("ScrollAnimator")
for smoothness in ScrollSmoothness.allCases {
    var animator = ScrollAnimator(timeConstant: smoothness.timeConstant)
    animator.addImpulse(300)
    var total = 0.0
    var frames = 0
    while animator.isActive && frames < 2000 {
        total += animator.step(dt: 1.0 / 120)
        frames += 1
    }
    total += animator.step(dt: 1.0 / 120)
    check(abs(total - 300) < 0.5, "\(smoothness.rawValue): total emitted ≈ impulse (\(Int(total)))")
    check(frames < 240, "\(smoothness.rawValue): settles within 2s (\(frames) frames)")
}

section("PixelQuantizer")
var quantizer = PixelQuantizer()
var sum = 0
for _ in 0..<100 { sum += quantizer.quantize(0.37) }
check(abs(sum - 37) <= 1, "carries remainders (\(sum))")

section("ScrollAcceleration")
let slow = ScrollAcceleration.gain(interval: 0.5, maxGain: 4)
let fast = ScrollAcceleration.gain(interval: 0.01, maxGain: 4)
check(slow == 1, "slow ticks have gain 1")
check(fast == 4, "fast ticks reach max gain")
check(ScrollAcceleration.tickPixels(speed: .medium, interval: 0.5, precise: true, quick: false)
      < ScrollAcceleration.tickPixels(speed: .medium, interval: 0.5, precise: false, quick: false), "precise is slower")

section("ButtonEngine")
func engine(_ remaps: [Remap]) -> ButtonEngine { ButtonEngine(remaps: remaps) }

do {
    let e = engine([])
    let r = e.buttonDown(3, flags: [], now: 0)
    check(!r.swallow, "unmanaged button passes through")
}

do {
    let e = engine([Remap(button: 3, gesture: .click, effect: .back)])
    let d = e.buttonDown(3, flags: [], now: 0)
    let u = e.buttonUp(3, now: 0.05)
    check(d.swallow && u.swallow, "managed button is swallowed")
    check(u.actions == [.perform(.back)], "single click fires immediately when only click is mapped")
}

do {
    let e = engine([
        Remap(button: 3, gesture: .click, effect: .back),
        Remap(button: 3, gesture: .doubleClick, effect: .forward),
    ])
    _ = e.buttonDown(3, flags: [], now: 0)
    let u1 = e.buttonUp(3, now: 0.05)
    check(u1.actions.isEmpty && u1.wake != nil, "single click waits when double click is mapped")
    let t = e.tick(now: 0.4)
    check(t.actions == [.perform(.back)], "single click fires after the multi-click window")

    _ = e.buttonDown(3, flags: [], now: 1.0)
    _ = e.buttonUp(3, now: 1.05)
    _ = e.buttonDown(3, flags: [], now: 1.1)
    let u2 = e.buttonUp(3, now: 1.15)
    check(u2.actions == [.perform(.forward)], "double click fires immediately at max level")
}

do {
    let e = engine([Remap(button: 3, gesture: .doubleClick, effect: .forward)])
    _ = e.buttonDown(3, flags: [], now: 0)
    _ = e.buttonUp(3, now: 0.05)
    let t = e.tick(now: 0.5)
    check(t.actions == [.replayClick(button: 3, count: 1)], "unmapped single click is replayed")
}

do {
    let e = engine([
        Remap(button: 3, gesture: .click, effect: .back),
        Remap(button: 3, gesture: .hold, effect: .hotkey(.missionControl)),
    ])
    _ = e.buttonDown(3, flags: [], now: 0)
    let t = e.tick(now: 0.35)
    check(t.actions == [.perform(.hotkey(.missionControl))], "hold fires after threshold")
    let u = e.buttonUp(3, now: 0.5)
    check(u.actions.isEmpty, "release after hold does not click")
}

do {
    let e = engine([
        Remap(button: 3, gesture: .click, effect: .back),
        Remap(button: 3, gesture: .drag, effect: .drag(.twoFingerSwipe)),
    ])
    _ = e.buttonDown(3, flags: [], now: 0)
    check(e.pointerMoved(dx: 2, dy: 1, now: 0.01).isEmpty, "small movement does not start drag")
    let moved = e.pointerMoved(dx: 10, dy: 0, now: 0.02)
    check(moved.first == .dragBegin(.twoFingerSwipe, button: 3), "drag begins past threshold")
    let u = e.buttonUp(3, now: 0.1)
    check(u.actions == [.dragEnd], "release ends drag and skips click")
}

do {
    let e = engine([
        Remap(button: 4, gesture: .click, effect: .smartZoom),
        Remap(button: 4, gesture: .scroll, effect: .scroll(.zoom)),
    ])
    _ = e.buttonDown(4, flags: [], now: 0)
    check(e.scrollEffect() == .zoom, "scroll while held yields scroll effect")
    let u = e.buttonUp(4, now: 0.5)
    check(u.actions.isEmpty, "release after scroll does not click")
}

do {
    let e = engine([Remap(button: 4, gesture: .click, modifierButton: 3, effect: .smartZoom)])
    check(e.isManaged(3) && e.isManaged(4), "modifier button is managed")
    _ = e.buttonDown(3, flags: [], now: 0)
    _ = e.buttonDown(4, flags: [], now: 0.1)
    let u4 = e.buttonUp(4, now: 0.15)
    check(u4.actions == [.perform(.smartZoom)], "chord click fires effect")
    let u3 = e.buttonUp(3, now: 0.3)
    check(u3.actions.isEmpty, "modifier button release does not click after being used")
}

do {
    let e = engine([Remap(button: 3, gesture: .click, keyboardModifiers: .shift, effect: .back)])
    _ = e.buttonDown(3, flags: [], now: 0)
    let u = e.buttonUp(3, now: 0.05)
    check(u.actions == [.replayClick(button: 3, count: 1)], "keyboard-modifier remap ignored without modifier")
    _ = e.buttonDown(3, flags: .shift, now: 1)
    let u2 = e.buttonUp(3, now: 1.05)
    check(u2.actions == [.perform(.back)], "keyboard-modifier remap fires with modifier")
}

section("Config")
do {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("jaycemouse-selftest-\(UUID().uuidString).json")
    var config = AppConfig()
    config.scroll.smoothness = .low
    config.remaps = DefaultRemaps.fiveButtons
    ConfigStore.save(config, to: url)
    let loaded = ConfigStore.load(from: url)
    check(loaded == config, "round-trips through JSON")
    try? FileManager.default.removeItem(at: url)
    check(ConfigStore.load(from: url) == AppConfig(), "missing file yields defaults")
}

print("\n\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
