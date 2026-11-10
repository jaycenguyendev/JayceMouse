import Foundation
import IOKit
import IOKit.hidsystem
import JayceMouseCore

/// Adjusts the system mouse acceleration through IOHID and restores it on quit.
final class PointerController {
    private let key = "HIDMouseAcceleration" as CFString
    private static let storedKey = "originalMouseAcceleration"
    private var original: Double? = UserDefaults.standard.object(forKey: PointerController.storedKey) as? Double

    func apply(_ settings: PointerSettings) {
        let handle = NXOpenEventStatus()
        guard handle != 0 else { return }
        defer { NXCloseEventStatus(handle) }

        if original == nil {
            var current = 0.0
            if IOHIDGetAccelerationWithKey(handle, key, &current) == KERN_SUCCESS {
                original = current
                UserDefaults.standard.set(current, forKey: Self.storedKey)
            }
        }
        if settings.useSystemAcceleration {
            if let original { _ = IOHIDSetAccelerationWithKey(handle, key, original) }
        } else {
            let value = PointerCurve.hidAcceleration(sensitivity: settings.sensitivity, acceleration: settings.acceleration)
            _ = IOHIDSetAccelerationWithKey(handle, key, value)
        }
    }

    func restore() {
        guard let original else { return }
        let handle = NXOpenEventStatus()
        guard handle != 0 else { return }
        _ = IOHIDSetAccelerationWithKey(handle, key, original)
        NXCloseEventStatus(handle)
        UserDefaults.standard.removeObject(forKey: Self.storedKey)
        self.original = nil
    }
}
