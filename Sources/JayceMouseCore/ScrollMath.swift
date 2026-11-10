import Foundation

public extension ScrollSmoothness {
    /// Time constant (seconds) of the exponential glide. Zero means no smoothing.
    var timeConstant: Double {
        switch self {
        case .off: return 0
        case .low: return 0.07
        case .regular: return 0.13
        case .high: return 0.32
        }
    }
}

public extension ScrollSpeed {
    var basePixelsPerTick: Double {
        switch self {
        case .low: return 36
        case .medium: return 66
        case .high: return 108
        }
    }

    var maxAccelerationGain: Double {
        switch self {
        case .low: return 2.2
        case .medium: return 3.6
        case .high: return 5.5
        }
    }
}

public enum ScrollAcceleration {
    public static let fastInterval = 0.018
    public static let slowInterval = 0.16

    /// Multiplier for a tick based on how soon it follows the previous tick.
    public static func gain(interval: Double, maxGain: Double) -> Double {
        let t = (slowInterval - interval) / (slowInterval - fastInterval)
        let clamped = min(max(t, 0), 1)
        let smooth = clamped * clamped * (3 - 2 * clamped)
        return 1 + (maxGain - 1) * smooth
    }

    public static func tickPixels(
        speed: ScrollSpeed,
        interval: Double,
        precise: Bool,
        quick: Bool
    ) -> Double {
        if precise { return speed.basePixelsPerTick * 0.22 }
        var px = speed.basePixelsPerTick * gain(interval: interval, maxGain: speed.maxAccelerationGain)
        if quick { px *= 3.5 }
        return px
    }
}

/// Distributes impulses over time with exponential decay. The integral of the output
/// across all frames equals the total of the impulses fed in.
public struct ScrollAnimator {
    public var timeConstant: Double
    private var velocity = 0.0
    private var carry = 0.0
    public private(set) var emittedThisGesture = 0.0

    public init(timeConstant: Double) {
        self.timeConstant = timeConstant
    }

    public var isActive: Bool { abs(velocity) > 12 || abs(carry) >= 1 }

    public var currentVelocity: Double { velocity }

    public mutating func addImpulse(_ pixels: Double) {
        if timeConstant <= 0 {
            carry += pixels
        } else {
            velocity += pixels / timeConstant
        }
    }

    public mutating func cancel() {
        velocity = 0
        carry = 0
    }

    /// Returns the (fractional) distance to emit for a frame of `dt` seconds.
    public mutating func step(dt: Double) -> Double {
        var out = carry
        carry = 0
        if timeConstant > 0, velocity != 0 {
            let decay = exp(-dt / timeConstant)
            out += velocity * timeConstant * (1 - decay)
            velocity *= decay
            if abs(velocity) < 12 {
                out += velocity * timeConstant
                velocity = 0
            }
        }
        emittedThisGesture += out
        return out
    }
}

/// Converts fractional pixel output into integer pixels, carrying the remainder.
public struct PixelQuantizer {
    private var remainder = 0.0
    public init() {}

    public mutating func quantize(_ value: Double) -> Int {
        let total = value + remainder
        let whole = total.rounded(.towardZero)
        remainder = total - whole
        return Int(whole)
    }

    public mutating func reset() { remainder = 0 }
}

public enum PointerCurve {
    /// Maps the 0...1 sliders to the HID acceleration scalar used by the system (0 disables acceleration).
    public static func hidAcceleration(sensitivity: Double, acceleration: Double) -> Double {
        let s = min(max(sensitivity, 0), 1)
        let a = min(max(acceleration, 0), 1)
        let tracking = 0.1 + 3.4 * s * s
        return a <= 0.001 ? -1 : tracking * (0.4 + 1.6 * a)
    }
}
