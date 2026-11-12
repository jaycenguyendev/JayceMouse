import AppKit
import Combine
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

    let engine = InputEngine()
    private let pointer = PointerController()
    private let dialogSnapper = DialogSnapper()
    private var saveTask: Task<Void, Never>?
    private var permissionTimer: Timer?

    init() {
        config = ConfigStore.load()
        L10n.language = config.general.language
        engine.apply(config)
        engine.onActivity = { [weak self] kind in
            DispatchQueue.main.async { self?.record(kind) }
        }
        engine.onCaptureButton = { [weak self] button in
            DispatchQueue.main.async { self?.deliverCapture(button) }
        }
        pointer.apply(config.pointer)
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
        updateDialogSnapper()
    }

    func testDialogSnap() {
        dialogSnapper.showTestAlert()
    }

    private func updateDialogSnapper() {
        dialogSnapper.setEnabled(trusted && config.general.snapToDefaultButton)
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Where the Accessibility switch lives in this macOS version, for on-screen instructions.
    static var accessibilitySettingsPath: String {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        if major >= 27 {
            return "System Settings → Privacy & Security → Device Control and Data Access → Accessibility"
        }
        return "System Settings → Privacy & Security → Accessibility"
    }

    /// Opens the Accessibility list in System Settings. The address of that page differs between macOS
    /// versions, so try the newest one first and fall back to older ones, then to Privacy & Security itself.
    func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }

    func shutdown() {
        dialogSnapper.stop()
        engine.stop()
        pointer.restore()
        ConfigStore.save(config)
    }

    // MARK: Config

    private func configChanged(old: AppConfig) {
        L10n.language = config.general.language
        engine.apply(config)
        if old.pointer != config.pointer { pointer.apply(config.pointer) }
        if old.general.launchAtLogin != config.general.launchAtLogin { updateLaunchAtLogin() }
        if old.general.snapToDefaultButton != config.general.snapToDefaultButton { updateDialogSnapper() }
        saveTask?.cancel()
        saveTask = Task { [config] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            ConfigStore.save(config)
        }
    }

    private func updateLaunchAtLogin() {
        do {
            if config.general.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            config.general.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

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
            if down { push("computermouse", tr("%@ pressed", buttonName(b))) }
        case .scroll(let text):
            scrollPulse &+= 1
            let line = tr("Scroll") + " · " + tr(text)
            if activity.first?.text != line { push("arrow.up.and.down", line) }
        case .action(let text):
            push("sparkles", text)
        case .drag(let text):
            push("hand.draw", tr(text))
        }
    }

    private func push(_ symbol: String, _ text: String) {
        activity.insert(ActivityItem(symbol: symbol, text: text), at: 0)
        if activity.count > 30 { activity.removeLast() }
    }
}
