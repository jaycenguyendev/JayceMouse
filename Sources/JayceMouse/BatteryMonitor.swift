import Darwin
import Foundation
import IOKit
import IOKit.ps

enum DeviceKind: Equatable {
    /// Mice and trackpads.
    case mouse
    case keyboard
    case other
}

struct DeviceBattery: Equatable {
    let name: String
    let percent: Int
    var kind: DeviceKind = .other

    /// SF Symbol matching the charge level.
    var symbol: String {
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

/// Reads the battery level macOS knows for Bluetooth mice, keyboards and other accessories.
/// macOS keeps it in different places depending on the device, so two sources are checked:
/// the IORegistry ("BatteryPercent") and accessory power sources (the list `pmset -g accps` prints).
/// Bluetooth LE devices that macOS does not list are asked directly through their Battery Service.
/// Devices on a USB receiver usually do not report a level at all.
final class BatteryMonitor {
    /// Latest readings, sorted by name. Only touched on the main thread.
    private(set) var batteries: [DeviceBattery] = []
    /// Called on the main thread when the readings change.
    var onChange: (() -> Void)?

    private var timer: Timer?
    private let queue = DispatchQueue(label: "JayceMouse.battery", qos: .utility)
    /// Levels from macOS's own lists (IORegistry, power sources). Main thread only.
    private var systemReadings: [DeviceBattery] = []
    /// Levels read straight from Bluetooth LE devices, for those macOS does not list (e.g. many BLE mice).
    private let bluetooth = BluetoothBatteryReader()
    /// Device kind by lowercased name, from the Bluetooth report ("Minor Type: Mouse"). Main thread only.
    private var kindsByName: [String: DeviceKind] = [:]
    /// When system_profiler last ran. Only used on `queue`.
    private var kindsCheckedAt: Date?

    /// Reading Bluetooth directly needs the Bluetooth permission and only helps mice, so it is optional.
    func start(readBluetooth: Bool) {
        bluetooth.onChange = { [weak self] in self?.publish() }
        if readBluetooth { bluetooth.start() } else { bluetooth.stop() }
        guard timer == nil else { publish(); return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        bluetooth.stop()
        systemReadings = []
        batteries = []
    }

    /// Scans in the background so opening the menu never stutters.
    func refresh() {
        let known = Set(kindsByName.keys)
        let pending = Set(bluetooth.readings.map { $0.name.lowercased() })
        queue.async { [weak self] in
            guard let self else { return }
            let found = BatteryMonitor.registry() + BatteryMonitor.powerSources() + BatteryMonitor.pmsetAccessories()
            // system_profiler takes about a second: run it every 10 minutes, or sooner (at most once a
            // minute) when a device shows up whose kind is not known yet.
            let names = Set(found.map { $0.name.lowercased() }).union(pending)
            let age = self.kindsCheckedAt.map { Date().timeIntervalSince($0) } ?? .infinity
            var kinds: [String: DeviceKind]?
            if age > 600 || (age > 60 && !names.isSubset(of: known)) {
                kinds = BatteryMonitor.bluetoothKinds()
                self.kindsCheckedAt = Date()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let kinds { self.kindsByName = kinds }
                self.systemReadings = found
                self.publish()
            }
        }
        bluetooth.refresh()
    }

    /// Merges all sources (the first one to name a device wins) and reports a change.
    private func publish() {
        var byName: [String: DeviceBattery] = [:]
        for var battery in systemReadings + bluetooth.readings where byName[battery.name.lowercased()] == nil {
            if battery.kind == .other {
                battery.kind = kindsByName[battery.name.lowercased()] ?? BatteryMonitor.guessKind(from: battery.name)
            }
            byName[battery.name.lowercased()] = battery
        }
        let merged = byName.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard merged != batteries else { return }
        batteries = merged
        onChange?()
    }

    // MARK: Source 1: IORegistry

    private static func registry() -> [DeviceBattery] {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [DeviceBattery] = []
        var seen = Set<String>()
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let percent = IORegistryEntryCreateCFProperty(entry, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int,
               (0...100).contains(percent) {
                let name = product(of: entry) ?? tr("Unknown device")
                if seen.insert(name).inserted {
                    result.append(DeviceBattery(name: name, percent: percent, kind: kind(of: entry)))
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// HID usage page 1 (generic desktop): usage 1/2 is a pointer or mouse, 6 a keyboard.
    private static func kind(of entry: io_registry_entry_t) -> DeviceKind {
        let options = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        let page = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, "PrimaryUsagePage" as CFString, kCFAllocatorDefault, options) as? Int
        let usage = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, "PrimaryUsage" as CFString, kCFAllocatorDefault, options) as? Int
        guard page == 1 else { return .other }
        switch usage {
        case 1, 2: return .mouse
        case 6: return .keyboard
        default: return .other
        }
    }

    /// Last resort: the device name ("Magic Mouse", "MX Keys keyboard"…).
    fileprivate static func guessKind(from name: String) -> DeviceKind {
        let lower = name.lowercased()
        if ["mouse", "trackpad", "chuột"].contains(where: { lower.contains($0) }) { return .mouse }
        if ["keyboard", "keys", "bàn phím"].contains(where: { lower.contains($0) }) { return .keyboard }
        return .other
    }

    /// The device name sits on the entry itself or on one of its parents.
    private static func product(of entry: io_registry_entry_t) -> String? {
        let options = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        let name = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, "Product" as CFString, kCFAllocatorDefault, options) as? String
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}

// MARK: Source 2: accessory power sources

extension BatteryMonitor {
    /// IOPSCopyPowerSourcesInfo only lists the Mac's own battery and UPSs. Accessories such as Bluetooth mice
    /// are returned by IOPSCopyPowerSourcesByType, which IOKit exports but the public SDK does not declare,
    /// so it is looked up at run time (the same list `pmset -g accps` prints).
    fileprivate static func powerSources() -> [DeviceBattery] {
        typealias CopyByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return [] }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "IOPSCopyPowerSourcesByType") else { return [] }
        let copyByType = unsafeBitCast(symbol, to: CopyByType.self)

        var result: [DeviceBattery] = []
        // 0 = all sources, 4 = accessories only.
        for type: Int32 in [0, 4] {
            guard let info = copyByType(type)?.takeRetainedValue(),
                  let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { continue }
            for source in list {
                guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else { continue }
                // Skip the Mac's own battery.
                if description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType { continue }
                guard let name = description[kIOPSNameKey] as? String, !name.isEmpty,
                      let current = description[kIOPSCurrentCapacityKey] as? Int else { continue }
                let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
                let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : current
                // Accessories carry a category such as "Mouse", "Keyboard" or "Trackpad".
                let category = (description["Accessory Category"] as? String ?? "").lowercased()
                let kind: DeviceKind = category.contains("keyboard") ? .keyboard
                    : (category.contains("mouse") || category.contains("trackpad")) ? .mouse : .other
                if (0...100).contains(percent) { result.append(DeviceBattery(name: name, percent: percent, kind: kind)) }
            }
        }
        return result
    }

    /// Fallback: read the same list from `pmset -g accps`, whose lines look like
    /// " -HyperWork TS01 (id=53023625)\t62%; ".
    fileprivate static func pmsetAccessories() -> [DeviceBattery] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "accps"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var result: [DeviceBattery] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-"), !trimmed.hasPrefix("-InternalBattery"),
                  let idRange = trimmed.range(of: " (id="),
                  let percentEnd = trimmed.range(of: "%") else { continue }
            let name = trimmed[trimmed.index(after: trimmed.startIndex)..<idRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            // The number just before the first "%".
            let beforePercent = trimmed[..<percentEnd.lowerBound]
            let digits = String(beforePercent.reversed().prefix { $0.isNumber }.reversed())
            guard !name.isEmpty, let percent = Int(digits), (0...100).contains(percent) else { continue }
            result.append(DeviceBattery(name: name, percent: percent))
        }
        return result
    }
}

// MARK: Device kinds from the Bluetooth report

extension BatteryMonitor {
    /// Reads "Minor Type" (Mouse, Keyboard, Trackpad…) for every paired Bluetooth device, keyed by lowercased name.
    fileprivate static func bluetoothKinds() -> [String: DeviceKind] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = json["SPBluetoothDataType"] as? [[String: Any]] else { return [:] }
        var kinds: [String: DeviceKind] = [:]
        for controller in controllers {
            // Devices are grouped (connected / not connected) as lists of one-entry dictionaries:
            // [{"Device name": {"device_minorType": "Mouse", …}}].
            for (_, group) in controller {
                guard let entries = group as? [[String: Any]] else { continue }
                for entry in entries {
                    for (name, value) in entry {
                        guard let details = value as? [String: Any],
                              let minor = details.first(where: { $0.key.lowercased().contains("minortype") })?.value as? String
                        else { continue }
                        let type = minor.lowercased()
                        if type.contains("keyboard") {
                            kinds[name.lowercased()] = .keyboard
                        } else if type.contains("mouse") || type.contains("trackpad") || type.contains("pointing") {
                            kinds[name.lowercased()] = .mouse
                        }
                    }
                }
            }
        }
        return kinds
    }
}
