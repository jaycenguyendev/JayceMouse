import CoreBluetooth
import Foundation

/// Reads the standard Bluetooth LE Battery Service (0x180F, Battery Level 0x2A19) of devices that are already
/// connected to the Mac. Many BLE mice report their level only this way: macOS does not list them in
/// `pmset -g accps`. Needs the Bluetooth permission (NSBluetoothAlwaysUsageDescription in Info.plist).
/// Runs on the main queue.
final class BluetoothBatteryReader: NSObject {
    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")
    private static let hidService = CBUUID(string: "1812")

    /// Latest levels, one per device.
    var readings: [DeviceBattery] { Array(levels.values) }
    /// Called when a level changes.
    var onChange: (() -> Void)?

    private var central: CBCentralManager?
    /// Peripherals must be kept alive while CoreBluetooth talks to them.
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var levels: [UUID: DeviceBattery] = [:]

    func start() {
        guard central == nil else { return }
        // Creating the manager asks for the Bluetooth permission the first time.
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func stop() {
        for peripheral in peripherals.values { central?.cancelPeripheralConnection(peripheral) }
        peripherals = [:]
        levels = [:]
        central = nil
    }

    /// Finds connected devices and asks each for its battery level.
    func refresh() {
        guard let central, central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [Self.batteryService, Self.hidService])
        let ids = Set(connected.map(\.identifier))

        // Forget devices that went away.
        for id in peripherals.keys where !ids.contains(id) {
            peripherals[id] = nil
        }
        let before = levels.count
        levels = levels.filter { ids.contains($0.key) }
        if levels.count != before { onChange?() }

        for peripheral in connected {
            peripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            if peripheral.state == .connected, let characteristic = levelCharacteristic(of: peripheral) {
                peripheral.readValue(for: characteristic)
            } else {
                // The device is already linked to the Mac; this only opens it for this app.
                central.connect(peripheral)
            }
        }
    }

    private func levelCharacteristic(of peripheral: CBPeripheral) -> CBCharacteristic? {
        peripheral.services?
            .first { $0.uuid == Self.batteryService }?
            .characteristics?
            .first { $0.uuid == Self.batteryLevel }
    }
}

extension BluetoothBatteryReader: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            refresh()
        } else {
            peripherals = [:]
            if !levels.isEmpty {
                levels = [:]
                onChange?()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryService])
    }
}

extension BluetoothBatteryReader: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.batteryService }) else { return }
        peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.batteryLevel }) else { return }
        peripheral.readValue(for: characteristic)
        // Get pushed updates too, if the device supports them.
        if characteristic.properties.contains(.notify) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == Self.batteryLevel,
              let value = characteristic.value?.first, value <= 100 else { return }
        let name = peripheral.name?.trimmingCharacters(in: .whitespaces)
        let reading = DeviceBattery(name: (name?.isEmpty ?? true) ? tr("Bluetooth device") : name!, percent: Int(value))
        guard levels[peripheral.identifier] != reading else { return }
        levels[peripheral.identifier] = reading
        onChange?()
    }
}
