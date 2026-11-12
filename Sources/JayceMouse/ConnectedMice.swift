import AppKit
import IOKit
import IOKit.ps

struct ConnectedMouse: Equatable {
    let name: String
    let batteryPercent: Int?
}

enum ConnectedMice {
    // Reads registry properties only. Opening the HID devices would require Input Monitoring.
    static func current() -> [ConnectedMouse] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        let accessories = AccessoryBatteries.current()
        var seen = Set<String>()
        var mice: [ConnectedMouse] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard isExternalPointer(entry), let key = identity(of: entry), seen.insert(key).inserted else { continue }
            let product = (property(entry, "Product") as? String)?.trimmingCharacters(in: .whitespaces)
            let name = product?.isEmpty == false ? product! : "Mouse"
            let uniqueID = property(entry, "PhysicalDeviceUniqueID") as? String
            let percent = battery(of: entry) ?? uniqueID.flatMap { accessories.byID[$0] } ?? accessories.byName[name]
            mice.append(ConnectedMouse(name: name, batteryPercent: percent))
        }
        return mice.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // Matching on PrimaryUsage misses combo devices that report as a keyboard first.
    private static func isExternalPointer(_ entry: io_registry_entry_t) -> Bool {
        if (property(entry, "Built-In") as? Bool) == true { return false }
        guard let pairs = property(entry, "DeviceUsagePairs") as? [[String: Any]] else { return false }
        return pairs.contains { ($0["DeviceUsagePage"] as? Int) == 1 && ($0["DeviceUsage"] as? Int) == 2 }
    }

    private static func identity(of entry: io_registry_entry_t) -> String? {
        if let id = property(entry, "PhysicalDeviceUniqueID") as? String { return id }
        if let location = property(entry, "LocationID") as? Int { return "loc-\(location)" }
        let vendor = property(entry, "VendorID") as? Int ?? 0
        let product = property(entry, "ProductID") as? Int ?? 0
        return "\(vendor):\(product):\(property(entry, "Product") as? String ?? "")"
    }

    private static func battery(of entry: io_registry_entry_t) -> Int? {
        let found = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, "BatteryPercent" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively))
        guard let percent = found as? Int, (0...100).contains(percent) else { return nil }
        return percent
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

// Bluetooth LE mice report battery through the Battery Service, which macOS exposes only as an
// accessory power source (what `pmset -g accps` lists), not in the HID registry. The public
// IOPSCopyPowerSourcesInfo leaves accessories out, so this uses the SPI behind pmset and
// degrades to no battery if it ever disappears.
private enum AccessoryBatteries {
    private typealias CopyByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?
    private static let allSources: Int32 = 0

    private static let copyByType: CopyByType? = {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let symbol = dlsym(handle, "IOPSCopyPowerSourcesByType") else { return nil }
        return unsafeBitCast(symbol, to: CopyByType.self)
    }()

    static func current() -> (byID: [String: Int], byName: [String: Int]) {
        guard let copyByType, let info = copyByType(allSources)?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return ([:], [:]) }
        var byID: [String: Int] = [:]
        var byName: [String: Int] = [:]
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? Int else { continue }
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            guard max > 0 else { continue }
            let percent = min(100, Swift.max(0, current * 100 / max))
            if let id = description["Accessory Identifier"] as? String { byID[id] = percent }
            if let name = description[kIOPSNameKey] as? String { byName[name] = percent }
        }
        return (byID, byName)
    }
}

extension ConnectedMouse {
    func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.view = MouseRowView(mouse: self)
        item.setAccessibilityLabel(batteryPercent.map { "\(name), battery \($0)%" } ?? name)
        return item
    }
}

// A plain menu item can't place text in the key-equivalent column, so the battery could only
// line up with ⌘Q by widening the menu. A flexible-width view is stretched to the menu's width
// instead, and draws with the same insets AppKit uses for an item with an image.
private final class MouseRowView: NSView {
    private let mouse: ConnectedMouse
    private let iconX: CGFloat = 18
    private let textX: CGFloat = 37
    private let trailingInset: CGFloat = 15
    private let gap: CGFloat = 12
    private let font = NSFont.menuFont(ofSize: 0)

    init(mouse: ConnectedMouse) {
        self.mouse = mouse
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        autoresizingMask = [.width]
        var tips: [String] = [mouse.name]
        if mouse.batteryPercent == nil { tips.append("This mouse doesn't report its battery level to macOS.") }
        toolTip = tips.joined(separator: "\n")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        var right = bounds.maxX - trailingInset
        if let percent = mouse.batteryPercent {
            let glyph = Self.batteryGlyph(percent: percent)
            right -= glyph.size.width
            glyph.draw(in: NSRect(x: right, y: (bounds.height - glyph.size.height) / 2, width: glyph.size.width, height: glyph.size.height))
            right -= 5
        }
        let detail = NSAttributedString(string: mouse.batteryPercent.map { "\($0)%" } ?? "—", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        right -= detail.size().width
        detail.draw(at: NSPoint(x: right, y: textY(detail)))

        if let symbol = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: font.pointSize, weight: .regular).applying(.init(hierarchicalColor: .labelColor))) {
            symbol.draw(in: NSRect(x: iconX, y: (bounds.height - symbol.size.height) / 2, width: symbol.size.width, height: symbol.size.height))
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let name = NSAttributedString(string: mouse.name, attributes: [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
        let nameRect = NSRect(x: textX, y: textY(name), width: max(0, right - gap - textX), height: name.size().height)
        name.draw(with: nameRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    private func textY(_ text: NSAttributedString) -> CGFloat {
        ((bounds.height - text.size().height) / 2).rounded()
    }

    // Drawn rather than an SF Symbol so the fill tracks the exact percentage like the system menu.
    private static func batteryGlyph(percent: Int) -> NSImage {
        NSImage(size: NSSize(width: 24, height: 10), flipped: false) { _ in
            let body = NSRect(x: 0.5, y: 0.5, width: 21, height: 9)
            NSColor.secondaryLabelColor.setStroke()
            let outline = NSBezierPath(roundedRect: body, xRadius: 2.5, yRadius: 2.5)
            outline.lineWidth = 1
            outline.stroke()

            NSColor.secondaryLabelColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: 22.5, y: 3, width: 1.5, height: 4), xRadius: 0.75, yRadius: 0.75).fill()

            let inner = body.insetBy(dx: 1.5, dy: 1.5)
            let width = max(1.5, inner.width * CGFloat(percent) / 100)
            (percent <= 20 ? NSColor.systemRed : NSColor.labelColor).setFill()
            NSBezierPath(roundedRect: NSRect(x: inner.minX, y: inner.minY, width: width, height: inner.height), xRadius: 1.2, yRadius: 1.2).fill()
            return true
        }
    }
}
