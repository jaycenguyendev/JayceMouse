import AppKit
import Combine
import os
import ServiceManagement
import SwiftUI
import JayceMouseCore

struct ActivityItem: Identifiable {
    let id = UUID()
    let symbol: String
    let text: String
    let date = Date()
}

@MainActor
final class AppModel: ObservableObject {
    @Published var config: AppConfig {
        didSet { configChanged(old: oldValue) }
    }
    @Published private(set) var trusted = false
    @Published private(set) var engineRunning = false
    @Published private(set) var pressedButtons: Set<Int> = []
    @Published private(set) var activity: [ActivityItem] = []
    @Published private(set) var scrollPulse = 0
    @Published var captureTarget: ((Int) -> Void)?
    @Published private(set) var loginItemStatus: SMAppService.Status = .notRegistered

    let engine = InputEngine()
    private let pointer = PointerController()
    private var saveTask: Task<Void, Never>?
    private var permissionTimer: Timer?

    init() {
        config = ConfigStore.load()
        engine.apply(config)
        engine.onActivity = { [weak self] kind in
            DispatchQueue.main.async { self?.record(kind) }
        }
        engine.onCaptureButton = { [weak self] button in
            DispatchQueue.main.async { self?.deliverCapture(button) }
        }
        pointer.apply(config.pointer)
        reconcileLaunchAtLogin()
        refreshPermission()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
    }

    // MARK: Permission and lifecycle

    func refreshPermission() {
        let ok = AXIsProcessTrusted()
        if ok != trusted {
            trusted = ok
            DebugLog.write("AXIsProcessTrusted=\(ok) listenAccess=\(CGPreflightListenEventAccess()) postAccess=\(CGPreflightPostEventAccess()) pid=\(getpid())")
        }
        if ok && !engine.isRunning {
            engineRunning = engine.start()
        } else if !ok && engine.isRunning {
            engine.stop()
            engineRunning = false
        } else {
            engineRunning = engine.isRunning
        }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func shutdown() {
        engine.stop()
        pointer.restore()
        ConfigStore.save(config)
    }

    // MARK: Config

    private func configChanged(old: AppConfig) {
        engine.apply(config)
        if old.pointer != config.pointer { pointer.apply(config.pointer) }
        if old.general.launchAtLogin != config.general.launchAtLogin { updateLaunchAtLogin() }
        saveTask?.cancel()
        saveTask = Task { [config] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            ConfigStore.save(config)
        }
    }

    // The system keeps a login item record per signed binary, and ad-hoc builds get a new
    // signature on every update, so an "enabled" record can point at a binary that no longer
    // exists. Re-register once for each new binary while the user still wants it.
    private func reconcileLaunchAtLogin() {
        loginItemStatus = SMAppService.mainApp.status
        Self.log.info("Login item status at launch: \(String(describing: self.loginItemStatus), privacy: .public)")
        // A dev build in build/ would otherwise steal the login item from the installed copy.
        guard Bundle.main.bundlePath.hasPrefix("/Applications/"), config.general.launchAtLogin else { return }
        let fingerprint = Self.binaryFingerprint
        let key = "loginItemRegisteredFor"
        guard loginItemStatus != .requiresApproval,
              UserDefaults.standard.string(forKey: key) != fingerprint || loginItemStatus != .enabled else { return }
        updateLaunchAtLogin()
        if loginItemStatus == .enabled { UserDefaults.standard.set(fingerprint, forKey: key) }
    }

    private static var binaryFingerprint: String {
        let path = Bundle.main.executablePath ?? Bundle.main.bundlePath
        let modified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(path)@\(modified)"
    }

    private func updateLaunchAtLogin() {
        do {
            if config.general.launchAtLogin {
                try? SMAppService.mainApp.unregister()
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.log.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        loginItemStatus = SMAppService.mainApp.status
        Self.log.info("Login item status: \(String(describing: self.loginItemStatus), privacy: .public)")
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static let log = Logger(subsystem: "app.jaycemouse.JayceMouse", category: "login-item")

    func resetAll() {
        config = AppConfig()
    }

    // MARK: Remaps

    func save(remap: Remap) {
        config.remaps.removeAll { $0.id == remap.id || $0.slotKey == remap.slotKey }
        config.remaps.append(remap)
        config.remaps.sort { $0.button < $1.button }
    }

    func delete(remap: Remap) {
        config.remaps.removeAll { $0.id == remap.id }
    }

    func apply(preset: [Remap]) {
        config.remaps = preset.map { Remap(button: $0.button, gesture: $0.gesture, modifierButton: $0.modifierButton, keyboardModifiers: $0.keyboardModifiers, effect: $0.effect) }
    }

    // MARK: Capture

    func beginCapture(_ handler: @escaping (Int) -> Void) {
        captureTarget = handler
        engine.armCapture(true)
    }

    func cancelCapture() {
        captureTarget = nil
        engine.armCapture(false)
    }

    private func deliverCapture(_ button: Int) {
        let handler = captureTarget
        cancelCapture()
        handler?(button)
    }

    // MARK: Activity

    private func record(_ kind: ActivityKind) {
        switch kind {
        case .button(let b, let down):
            if down { pressedButtons.insert(b) } else { pressedButtons.remove(b) }
            if down { push("computermouse", "\(buttonName(b)) pressed") }
        case .scroll(let text):
            scrollPulse &+= 1
            if activity.first?.text != "Scroll · \(text)" { push("arrow.up.and.down", "Scroll · \(text)") }
        case .action(let text):
            push("sparkles", text)
        case .drag(let text):
            push("hand.draw", text)
        }
    }

    private func push(_ symbol: String, _ text: String) {
        activity.insert(ActivityItem(symbol: symbol, text: text), at: 0)
        if activity.count > 30 { activity.removeLast() }
    }
}
