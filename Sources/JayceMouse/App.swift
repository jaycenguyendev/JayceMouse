import AppKit
import Combine
import SwiftUI
import JayceMouseCore

@main
struct JayceMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("JayceMouse", id: "main") {
            RootView()
                .environmentObject(AppDelegate.model)
                .modifier(MainWindowOpener())
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)
    }
}

private struct MainWindowOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            AppDelegate.openMainWindowAction = { openWindow(id: "main") }
            if !AppDelegate.hidingLaunchWindow { NSApp.setActivationPolicy(.regular) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static let model = AppModel()
    @MainActor static var openMainWindowAction: (() -> Void)?

    /// True for the first moments after launch while the window should stay hidden (start in the menu bar).
    static var hidingLaunchWindow = false

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    /// The window SwiftUI opened at launch and that was hidden; shown again from the menu bar.
    private weak var launchHiddenWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        let (general, trusted) = MainActor.assumeIsolated {
            (AppDelegate.model.config.general, AppDelegate.model.trusted)
        }
        let debugRun = CommandLine.arguments.contains("--e2e")
            || ProcessInfo.processInfo.environment["JAYCEMOUSE_SNAPSHOT_DIR"] != nil
        // Start in the menu bar only, unless the window is wanted, there is no menu bar icon to open it
        // from, or Accessibility access is still missing (the window explains how to grant it).
        guard !general.showWindowAtLaunch, general.showMenuBarItem, trusted, !debugRun else { return }
        AppDelegate.hidingLaunchWindow = true
        NSApp.setActivationPolicy(.accessory)
        // SwiftUI opens its window a moment after launch; hide it whenever it shows up during that time.
        for delay in [0.05, 0.2, 0.5, 1.0, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.hideLaunchWindow() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { AppDelegate.hidingLaunchWindow = false }
    }

    private func hideLaunchWindow() {
        guard AppDelegate.hidingLaunchWindow else { return }
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) && !(window is NSPanel) {
            window.orderOut(nil)
            launchHiddenWindow = window
        }
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppDelegate.model.$config
                .map(\.general.showMenuBarItem)
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] show in self?.setMenuBarItem(visible: show) }
                .store(in: &cancellables)
            NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateDockPresence() }
                .store(in: &cancellables)
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
    // cacheDisplay leaves the main window's page area blank, so pages are drawn from an offscreen RootView.
    private func snapshotPages(into directory: String) {
        let pages = ["overview", "buttons", "scroll", "pointer", "general", "about"]
        let languages: [AppLanguage] = [.english, .vietnamese]
        let model = MainActor.assumeIsolated { AppDelegate.model }
        let original = MainActor.assumeIsolated { model.config.general.language }
        let root = MainActor.assumeIsolated {
            let view = NSHostingView(rootView: RootView().environmentObject(model).frame(width: 1080, height: 900))
            view.frame = NSRect(x: 0, y: 0, width: 1080, height: 900)
            let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
            return view
        }

        func write(_ view: NSView, to path: String) {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }

        func captureExtras(_ folder: String) {
            MainActor.assumeIsolated {
                let editor = NSHostingView(rootView: RemapEditor(initial: model.config.remaps.first) { _ in }.environmentObject(model))
                editor.frame = NSRect(x: 0, y: 0, width: 620, height: 640)
                let window = NSWindow(contentRect: editor.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = editor
                editor.layoutSubtreeIfNeeded()
                write(editor, to: "\(folder)/editor.png")
                if let menu = statusItem?.menu {
                    menuNeedsUpdate(menu)
                    let titles = menu.items.map { $0.isSeparatorItem ? "---" : ($0.view?.toolTip ?? $0.title) }
                    try? titles.joined(separator: "\n").write(toFile: "\(folder)/menu.txt", atomically: true, encoding: .utf8)
                }
            }
        }

        func capture(_ languageIndex: Int, _ pageIndex: Int) {
            guard languageIndex < languages.count else {
                MainActor.assumeIsolated { model.config.general.language = original }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.terminate(nil) }
                return
            }
            let folder = "\(directory)/\(languages[languageIndex].rawValue)"
            guard pageIndex < pages.count else {
                captureExtras(folder)
                capture(languageIndex + 1, 0)
                return
            }
            if pageIndex == 0 {
                try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                MainActor.assumeIsolated { model.config.general.language = languages[languageIndex] }
            }
            UserDefaults.standard.set(pages[pageIndex], forKey: "selectedPage")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                root.layoutSubtreeIfNeeded()
                write(root, to: "\(folder)/\(pages[pageIndex]).png")
                capture(languageIndex, pageIndex + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { capture(0, 0) }
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
        AppDelegate.hidingLaunchWindow = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = launchHiddenWindow, !window.isVisible {
            // Hidden at launch rather than closed, so bring the same window back (once; later
            // reopening after a real close goes through openWindow).
            window.makeKeyAndOrderFront(nil)
            launchHiddenWindow = nil
        } else if let open = MainActor.assumeIsolated({ AppDelegate.openMainWindowAction }) {
            open()
        } else {
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // With the window closed the app keeps running from the menu bar, so drop the Dock icon.
    // Without a menu bar item the Dock icon is the only way back in, so keep it.
    private func updateDockPresence() {
        let hasVisibleWindow = NSApp.windows.contains { $0.canBecomeMain && $0.isVisible }
        let showMenuBarItem = MainActor.assumeIsolated { AppDelegate.model.config.general.showMenuBarItem }
        NSApp.setActivationPolicy(!hasVisibleWindow && showMenuBarItem ? .accessory : .regular)
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
        let menu = NSMenu()
        menu.addItem(withTitle: "", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "", action: #selector(toggleButtons(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "", action: #selector(toggleScroll(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let languages = NSMenu()
        for language in AppLanguage.allCases {
            let choice = NSMenuItem(title: "", action: #selector(selectLanguage(_:)), keyEquivalent: "")
            choice.representedObject = language.rawValue
            choice.target = self
            languages.addItem(choice)
        }
        let languageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        languageItem.tag = Self.languageItemTag
        languageItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        languageItem.submenu = languages
        menu.addItem(languageItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        menu.delegate = self
        localizeTitles(in: menu)
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleButtons(_ sender: NSMenuItem) {
        MainActor.assumeIsolated { AppDelegate.model.config.general.buttonKillSwitch.toggle() }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = AppLanguage(rawValue: raw) else { return }
        MainActor.assumeIsolated { AppDelegate.model.config.general.language = language }
    }

    @objc private func toggleScroll(_ sender: NSMenuItem) {
        MainActor.assumeIsolated { AppDelegate.model.config.general.scrollKillSwitch.toggle() }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        localizeTitles(in: menu)
        MainActor.assumeIsolated {
            let general = AppDelegate.model.config.general
            menu.items.first { $0.action == #selector(toggleButtons(_:)) }?.state = general.buttonKillSwitch ? .on : .off
            menu.items.first { $0.action == #selector(toggleScroll(_:)) }?.state = general.scrollKillSwitch ? .on : .off
        }
        refreshMouseItems(in: menu)
    }

    private static let mouseItemTag = 7_401
    private static let languageItemTag = 7_402

    fileprivate func localizeTitles(in menu: NSMenu) {
        for item in menu.items {
            switch item.action {
            case #selector(showMainWindow): item.title = tr("Jayce Mouse Settings…", "Cài đặt Jayce Mouse…")
            case #selector(toggleButtons(_:)): item.title = tr("Pause Button Actions", "Tạm dừng thao tác nút")
            case #selector(toggleScroll(_:)): item.title = tr("Pause Scroll Enhancements", "Tạm dừng tăng cường cuộn")
            case #selector(NSApplication.terminate(_:)): item.title = tr("Quit JayceMouse", "Thoát JayceMouse")
            default: break
            }
        }
        guard let languageItem = menu.items.first(where: { $0.tag == Self.languageItemTag }) else { return }
        languageItem.title = tr("Language", "Ngôn ngữ")
        let current = MainActor.assumeIsolated { AppDelegate.model.config.general.language }
        for choice in languageItem.submenu?.items ?? [] {
            guard let language = (choice.representedObject as? String).flatMap(AppLanguage.init(rawValue:)) else { continue }
            choice.title = language.displayName
            choice.state = language == current ? .on : .off
        }
    }

    private func refreshMouseItems(in menu: NSMenu) {
        menu.items.filter { $0.tag == Self.mouseItemTag }.forEach(menu.removeItem)
        let general = MainActor.assumeIsolated { AppDelegate.model.config.general }
        guard general.showMiceInMenu || general.showKeyboardsInMenu else { return }
        let devices = ConnectedMice.current(mice: general.showMiceInMenu, keyboards: general.showKeyboardsInMenu)
        var items = devices.map { $0.menuItem() }
        if general.showMiceInMenu && !devices.contains(where: { !$0.isKeyboard }) {
            items.insert(NSMenuItem(title: tr("No mouse connected", "Chưa kết nối chuột"), action: nil, keyEquivalent: ""), at: 0)
        }
        guard !items.isEmpty else { return }
        items.append(.separator())
        for (index, item) in items.enumerated() {
            item.tag = Self.mouseItemTag
            menu.insertItem(item, at: index)
        }
    }
}
