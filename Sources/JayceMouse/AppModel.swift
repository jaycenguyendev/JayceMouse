import AppKit
import Combine
import os
import ServiceManagement
import SwiftUI
import JayceMouseCore

enum ActivityEvent: Equatable {
    case pressed(Int)
    case scroll(ScrollActivity)
    case action(Effect)
    case dragStarted
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let event: ActivityEvent
    let date = Date()

    var symbol: String {
        switch event {
        case .pressed: return "computermouse"
        case .scroll: return "arrow.up.and.down"
        case .action: return "sparkles"
        case .dragStarted: return "hand.draw"
        }
    }

    var text: String {
        switch event {
        case .pressed(let button): return tr("\(buttonName(button)) pressed", "Đã nhấn \(buttonName(button))")
        case .scroll(let kind): return tr("Scroll", "Cuộn") + " · " + kind.title
        case .action(let effect): return EffectCatalog.title(for: effect)
        case .dragStarted: return tr("Drag started", "Bắt đầu kéo")
        }
    }
}

extension ScrollActivity {
    var title: String {
        switch self {
        case .zoom: return tr("Zoom", "Thu phóng")
        case .switchSpace: return tr("Switch space", "Chuyển Space")
        case .desktopAndLaunchpad: return tr("Desktop & Launchpad", "Màn hình nền & Launchpad")
        case .horizontal: return tr("Horizontal", "Ngang")
        case .quick: return tr("Quick", "Nhanh")
        case .precise: return tr("Precise", "Chính xác")
        case .direct: return tr("Direct", "Trực tiếp")
        case .smooth: return tr("Smooth", "Mượt")
        }
    }
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
    @Published private(set) var language: UILanguage = .english
    @Published private(set) var connectedMice: [ConnectedMouse] = []

    let engine = InputEngine()
    private let pointer = PointerController()
    private var saveTask: Task<Void, Never>?
    private var permissionTimer: Timer?
    private var miceTimer: Timer?

    init() {
        config = ConfigStore.load()
        updateLanguage()
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
        refreshConnectedMice()
        miceTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshConnectedMice() }
        }
    }

    // MARK: Permission and lifecycle

    func refreshConnectedMice() {
        let mice = ConnectedMice.current()
        if mice != connectedMice { connectedMice = mice }
    }

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
        if old.general.language != config.general.language { updateLanguage() }
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

    private func updateLanguage() {
        L10n.current = config.general.language.resolved
        language = L10n.current
    }

    func resetAll() {
        var fresh = AppConfig()
        fresh.general.language = config.general.language
        config = fresh
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
            if down { push(.pressed(b)) }
        case .scroll(let kind):
            scrollPulse &+= 1
            if activity.first?.event != .scroll(kind) { push(.scroll(kind)) }
        case .action(let effect):
            push(.action(effect))
        case .dragStarted:
            push(.dragStarted)
        }
    }

    private func push(_ event: ActivityEvent) {
        activity.insert(ActivityItem(event: event), at: 0)
        if activity.count > 30 { activity.removeLast() }
    }
}
