import AppKit
import Combine
import JayceMouseCore
import SwiftUI

@main
struct JayceMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("JayceMouse", id: "main") {
            RootView()
                .environmentObject(AppDelegate.model)
                .background(MainWindowBridge())
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static let model = AppModel()

    /// Set once at launch so SwiftUI views can reach the delegate.
    static weak var shared: AppDelegate?
    /// SwiftUI's openWindow action, used to recreate the settings window after it was really closed (⌘W).
    static var openMainWindow: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    /// The settings window. The close button only hides it, so it can be shown again from the menu bar.
    private weak var mainWindow: NSWindow?
    private let batteryMonitor = BatteryMonitor()
    /// Tag for the battery rows at the top of the menu bar menu.
    private let batteryItemTag = 4242

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppDelegate.model.$config
                .map(\.general.showMenuBarItem)
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] show in
                    self?.setMenuBarItem(visible: show)
                    self?.updateDockIcon()
                }
                .store(in: &cancellables)
            // Rebuild the menu in the new language.
            AppDelegate.model.$config
                .map(\.general.language)
                .removeDuplicates()
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.rebuildMenu() }
                .store(in: &cancellables)
            // Battery levels are opt-in; only watch devices while one of the settings is on.
            AppDelegate.model.$config
                .map { [$0.general.showMouseBattery, $0.general.showKeyboardBattery] }
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] flags in self?.setBatteryMonitoring(mouse: flags[0], keyboard: flags[1]) }
                .store(in: &cancellables)
        }
        watchWindowsForDockIcon()
        batteryMonitor.onChange = { [weak self] in
            guard let self, let menu = self.statusItem?.menu else { return }
            self.updateBatteryItems(in: menu)
        }
        #if DEBUG
        E2E.launchIfRequested()
        if let directory = ProcessInfo.processInfo.environment["JAYCEMOUSE_SNAPSHOT_DIR"] {
            snapshotPages(into: directory)
        }
        #else
        DebugLog.removeStaleLog()
        #endif
    }

    #if DEBUG
    private func snapshotPages(into directory: String) {
        let pages = ["overview", "buttons", "scroll", "pointer", "general", "about"]
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        func capture(_ index: Int) {
            guard index < pages.count else { NSApp.terminate(nil); return }
            UserDefaults.standard.set(pages[index], forKey: "selectedPage")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if let view = NSApp.windows.first(where: { $0.canBecomeMain })?.contentView,
                   let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(directory)/\(pages[index]).png"))
                }
                capture(index + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { capture(0) }
    }
    #endif

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AppDelegate.model.shutdown() }
    }

    @objc func showMainWindow() {
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            // The window was really closed (⌘W): let SwiftUI build a new one.
            AppDelegate.openMainWindow?()
        }
        // If no window came up after all, drop the Dock icon again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.updateDockIcon() }
    }

    /// Called by MainWindowBridge when the settings window appears.
    func adopt(mainWindow window: NSWindow) {
        mainWindow = window
        // The red close button hides the window instead of destroying it.
        if let close = window.standardWindowButton(.closeButton) {
            close.target = self
            close.action = #selector(hideMainWindow(_:))
        }
    }

    @objc private func hideMainWindow(_ sender: Any?) {
        mainWindow?.orderOut(nil)
        updateDockIcon()
    }

    // MARK: Dock icon

    /// The Dock icon shows only while the settings window is open (or minimized).
    /// Once the window is closed, JayceMouse lives in the menu bar only.
    private func watchWindowsForDockIcon() {
        let names: [Notification.Name] = [
            NSWindow.didBecomeMainNotification,
            NSWindow.willCloseNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didChangeOcclusionStateNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                if name == NSWindow.willCloseNotification, let window = note.object as? NSWindow,
                   window === self?.mainWindow {
                    self?.mainWindow = nil
                }
                // Run after the close/hide has finished, so the window no longer counts as visible.
                DispatchQueue.main.async { self?.updateDockIcon() }
            }
        }
        updateDockIcon()
    }

    private func updateDockIcon() {
        let showsMenuBarItem = MainActor.assumeIsolated { AppDelegate.model.config.general.showMenuBarItem }
        // Only real app windows count, not the menu bar item, menus or panels.
        let hasWindow = NSApp.windows.contains {
            $0.styleMask.contains(.titled) && !($0 is NSPanel) && ($0.isVisible || $0.isMiniaturized)
        }
        // Without the menu bar icon, keep the Dock icon so the app can still be reached.
        let policy: NSApplication.ActivationPolicy = (hasWindow || !showsMenuBarItem) ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular && hasWindow {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setMenuBarItem(visible: Bool) {
        if !visible {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "JayceMouse")
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: tr("Jayce Mouse Settings…"), action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        let buttons = NSMenuItem(title: tr("Pause Button Actions"), action: #selector(toggleButtons(_:)), keyEquivalent: "")
        let scroll = NSMenuItem(title: tr("Pause Scroll Enhancements"), action: #selector(toggleScroll(_:)), keyEquivalent: "")
        menu.addItem(buttons)
        menu.addItem(scroll)
        menu.addItem(.separator())

        // Interface language. Each language is written in itself so it can always be found.
        let language = NSMenuItem(title: tr("Language"), action: nil, keyEquivalent: "")
        language.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        let languages = NSMenu()
        for (code, title) in [(AppLanguage.english, "English"), (AppLanguage.vietnamese, "Tiếng Việt")] {
            let option = NSMenuItem(title: title, action: #selector(chooseLanguage(_:)), keyEquivalent: "")
            option.representedObject = code.rawValue
            option.target = self
            languages.addItem(option)
        }
        language.submenu = languages
        menu.addItem(language)
        menu.addItem(.separator())

        menu.addItem(withTitle: tr("Quit JayceMouse"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { item in
            guard item.action != nil else { return }
            item.target = item.action == #selector(NSApplication.terminate(_:)) ? NSApp : self
        }
        menu.delegate = self
        languages.delegate = self
        updateBatteryItems(in: menu)
        statusItem.menu = menu
    }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = AppLanguage(rawValue: raw) else { return }
        MainActor.assumeIsolated { AppDelegate.model.config.general.language = language }
    }

    private func setBatteryMonitoring(mouse: Bool, keyboard: Bool) {
        if mouse || keyboard {
            // Asking devices over Bluetooth needs the Bluetooth permission and only helps some mice.
            batteryMonitor.start(readBluetooth: mouse)
        } else {
            batteryMonitor.stop()
        }
        if let menu = statusItem?.menu { updateBatteryItems(in: menu) }
    }

    /// Rebuilds the "Batteries" section at the top of the menu. Hidden when no device reports a level.
    private func updateBatteryItems(in menu: NSMenu) {
        for item in menu.items where item.tag == batteryItemTag { menu.removeItem(item) }
        let general = MainActor.assumeIsolated { AppDelegate.model.config.general }
        // Mice and keyboards follow their own switch; other devices (whose kind is unknown) show with either.
        let batteries = batteryMonitor.batteries.filter { battery in
            switch battery.kind {
            case .mouse: return general.showMouseBattery
            case .keyboard: return general.showKeyboardBattery
            case .other: return general.showsAnyBattery
            }
        }
        guard !batteries.isEmpty else { return }

        var rows: [NSMenuItem] = [NSMenuItem.sectionHeader(title: tr("Batteries"))]
        for battery in batteries {
            // No action, so the row shows greyed out as plain information.
            let row = NSMenuItem(title: "\(battery.name) – \(battery.percent)%", action: nil, keyEquivalent: "")
            row.image = NSImage(systemSymbolName: battery.symbol, accessibilityDescription: nil)
            rows.append(row)
        }
        rows.append(.separator())
        for (index, row) in rows.enumerated() {
            row.tag = batteryItemTag
            menu.insertItem(row, at: index)
        }
    }

    @objc private func toggleButtons(_ sender: NSMenuItem) {
        MainActor.assumeIsolated { AppDelegate.model.config.general.buttonKillSwitch.toggle() }
    }

    @objc private func toggleScroll(_ sender: NSMenuItem) {
        MainActor.assumeIsolated { AppDelegate.model.config.general.scrollKillSwitch.toggle() }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // The language submenu only needs its checkmark.
        if menu !== statusItem?.menu {
            let current = MainActor.assumeIsolated { AppDelegate.model.config.general.language.rawValue }
            for item in menu.items { item.state = (item.representedObject as? String) == current ? .on : .off }
            return
        }
        updateBatteryItems(in: menu)
        // Fetch fresh levels; the rows update in place if they changed.
        if MainActor.assumeIsolated({ AppDelegate.model.config.general.showsAnyBattery }) {
            batteryMonitor.refresh()
        }
        MainActor.assumeIsolated {
            let general = AppDelegate.model.config.general
            menu.items.first { $0.action == #selector(toggleButtons(_:)) }?.state = general.buttonKillSwitch ? .on : .off
            menu.items.first { $0.action == #selector(toggleScroll(_:)) }?.state = general.scrollKillSwitch ? .on : .off
        }
    }
}

/// Hands the settings window and SwiftUI's openWindow action to the AppDelegate.
struct MainWindowBridge: NSViewRepresentable {
    @Environment(\.openWindow) private var openWindow

    func makeNSView(context: Context) -> BridgeView { BridgeView() }

    func updateNSView(_ nsView: BridgeView, context: Context) {
        let open = openWindow
        AppDelegate.openMainWindow = { open(id: "main") }
    }

    final class BridgeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            AppDelegate.shared?.adopt(mainWindow: window)
        }
    }
}
