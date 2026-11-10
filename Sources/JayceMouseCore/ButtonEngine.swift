import Foundation

public enum ButtonAction: Equatable {
    case perform(Effect)
    case replayClick(button: Int, count: Int)
    case dragBegin(DragEffect, button: Int)
    case dragMove(dx: Double, dy: Double)
    case dragEnd
}

public struct EngineResult {
    public var swallow: Bool
    public var actions: [ButtonAction]
    public var wake: TimeInterval?

    static func pass(_ actions: [ButtonAction] = [], wake: TimeInterval?) -> EngineResult {
        EngineResult(swallow: false, actions: actions, wake: wake)
    }
}

public final class ButtonEngine {
    public var holdThreshold: TimeInterval = 0.3
    public var multiClickWindow: TimeInterval = 0.28
    public var dragThreshold: Double = 7

    private struct State {
        var down = false
        var swallowed = false
        var downTime: TimeInterval = 0
        var lastUp: TimeInterval = 0
        var clickCount = 0
        var holdFired = false
        var dragActive = false
        var dragDistance: (dx: Double, dy: Double) = (0, 0)
        var usedAsModifier = false
        var scrollUsed = false
        var matched: [Remap] = []
    }

    private var remaps: [Remap] = []
    private var managed: Set<Int> = []
    private var states: [Int: State] = [:]

    public init(remaps: [Remap] = []) {
        setRemaps(remaps)
    }

    public func setRemaps(_ new: [Remap]) {
        remaps = new
        managed = Set(new.map(\.button)).union(new.compactMap(\.modifierButton))
    }

    public func isManaged(_ button: Int) -> Bool { managed.contains(button) }

    public func reset() { states = [:] }

    // MARK: Input

    public func buttonDown(_ button: Int, flags: ModifierMask, now: TimeInterval) -> EngineResult {
        var actions = flushExpired(now)
        guard managed.contains(button) else { return .pass(actions, wake: nextWake()) }

        var s = states[button] ?? State()
        s.down = true
        s.swallowed = true
        s.downTime = now
        s.holdFired = false
        s.dragActive = false
        s.dragDistance = (0, 0)
        s.usedAsModifier = false
        s.scrollUsed = false
        s.matched = matching(button: button, flags: flags)
        if s.clickCount > 0 && now - s.lastUp > multiClickWindow {
            actions += fireClick(button, count: s.clickCount, matched: s.matched)
            s.clickCount = 0
        }
        states[button] = s

        for r in s.matched {
            if let m = r.modifierButton { states[m]?.usedAsModifier = true }
        }
        return EngineResult(swallow: true, actions: actions, wake: nextWake())
    }

    public func buttonUp(_ button: Int, now: TimeInterval) -> EngineResult {
        var actions = flushExpired(now)
        guard var s = states[button], s.swallowed else { return .pass(actions, wake: nextWake()) }

        s.down = false
        s.swallowed = false

        if s.dragActive {
            actions.append(.dragEnd)
            s.dragActive = false
            s.clickCount = 0
        } else if s.holdFired || s.scrollUsed || s.usedAsModifier {
            s.clickCount = 0
        } else {
            let maxLevel = s.matched.compactMap { $0.gesture.clickLevel }.max() ?? 0
            if maxLevel == 0 {
                actions.append(.replayClick(button: button, count: 1))
                s.clickCount = 0
            } else {
                s.clickCount += 1
                s.lastUp = now
                if s.clickCount >= maxLevel {
                    actions += fireClick(button, count: s.clickCount, matched: s.matched)
                    s.clickCount = 0
                }
            }
        }
        states[button] = s
        return EngineResult(swallow: true, actions: actions, wake: nextWake())
    }

    public func pointerMoved(dx: Double, dy: Double, now: TimeInterval) -> [ButtonAction] {
        var actions = flushExpired(now)
        for (button, var s) in states where s.down && s.swallowed && !s.holdFired {
            if s.dragActive {
                actions.append(.dragMove(dx: dx, dy: dy))
                continue
            }
            guard let drag = best(.drag, in: s.matched), case .drag(let effect) = drag.effect else { continue }
            s.dragDistance.dx += dx
            s.dragDistance.dy += dy
            if hypot(s.dragDistance.dx, s.dragDistance.dy) >= dragThreshold {
                s.dragActive = true
                s.clickCount = 0
                actions.append(.dragBegin(effect, button: button))
                actions.append(.dragMove(dx: s.dragDistance.dx, dy: s.dragDistance.dy))
            }
            states[button] = s
        }
        return actions
    }

    public func isDragActive() -> Bool { states.values.contains { $0.dragActive } }

    public func scrollEffect() -> ScrollEffect? {
        for (button, var s) in states where s.down && s.swallowed {
            if let r = best(.scroll, in: s.matched), case .scroll(let effect) = r.effect {
                s.scrollUsed = true
                states[button] = s
                return effect
            }
        }
        return nil
    }

    public func tick(now: TimeInterval) -> EngineResult {
        var actions = flushExpired(now)
        for (button, var s) in states where s.down && s.swallowed && !s.holdFired && !s.dragActive {
            guard let hold = best(.hold, in: s.matched), now - s.downTime >= holdThreshold else { continue }
            actions.append(.perform(hold.effect))
            s.holdFired = true
            s.clickCount = 0
            states[button] = s
        }
        return EngineResult(swallow: false, actions: actions, wake: nextWake())
    }

    // MARK: Internals

    private func matching(button: Int, flags: ModifierMask) -> [Remap] {
        let kb = flags.intersection(.all)
        return remaps.filter { r in
            guard r.button == button, r.keyboardModifiers == kb else { return false }
            if let m = r.modifierButton { return states[m]?.down == true && m != button }
            return true
        }
    }

    private func best(_ gesture: ButtonGesture, in matched: [Remap]) -> Remap? {
        let candidates = matched.filter { $0.gesture == gesture }
        return candidates.first(where: { $0.modifierButton != nil }) ?? candidates.first
    }

    private func fireClick(_ button: Int, count: Int, matched: [Remap]) -> [ButtonAction] {
        var level = count
        while level >= 1 {
            let gesture: ButtonGesture = level == 1 ? .click : (level == 2 ? .doubleClick : .tripleClick)
            if let r = best(gesture, in: matched) {
                var actions: [ButtonAction] = [.perform(r.effect)]
                if level < count { actions.append(.replayClick(button: button, count: count - level)) }
                return actions
            }
            level -= 1
        }
        return [.replayClick(button: button, count: count)]
    }

    private func flushExpired(_ now: TimeInterval) -> [ButtonAction] {
        var actions: [ButtonAction] = []
        for (button, var s) in states where !s.down && s.clickCount > 0 && now - s.lastUp >= multiClickWindow {
            actions += fireClick(button, count: s.clickCount, matched: s.matched)
            s.clickCount = 0
            states[button] = s
        }
        return actions
    }

    private func nextWake() -> TimeInterval? {
        var wake: TimeInterval?
        func consider(_ t: TimeInterval) { wake = min(wake ?? t, t) }
        for s in states.values {
            if s.down && s.swallowed && !s.holdFired && !s.dragActive && best(.hold, in: s.matched) != nil {
                consider(s.downTime + holdThreshold)
            }
            if !s.down && s.clickCount > 0 { consider(s.lastUp + multiClickWindow) }
        }
        return wake
    }
}
