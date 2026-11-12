import AppKit
import Combine
import SwiftUI

@main
struct JayceMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("JayceMouse", id: "main") {
            RootView()
                .environmentObject(AppDelegate.model)
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static let model = AppModel()

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppDelegate.model.$config
                .map(\.general.showMenuBarItem)
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] show in self?.setMenuBarItem(visible: show) }
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
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
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
        let menu = NSMenu()
        menu.addItem(withTitle: "Open JayceMouse", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        let buttons = NSMenuItem(title: "Pause Button Actions", action: #selector(toggleButtons(_:)), keyEquivalent: "")
        let scroll = NSMenuItem(title: "Pause Scroll Enhancements", action: #selector(toggleScroll(_:)), keyEquivalent: "")
        menu.addItem(buttons)
        menu.addItem(scroll)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit JayceMouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
        menu.delegate = self
        item.menu = menu
        statusItem = item
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
        MainActor.assumeIsolated {
            let general = AppDelegate.model.config.general
            menu.items.first { $0.action == #selector(toggleButtons(_:)) }?.state = general.buttonKillSwitch ? .on : .off
            menu.items.first { $0.action == #selector(toggleScroll(_:)) }?.state = general.scrollKillSwitch ? .on : .off
        }
        refreshMouseItems(in: menu)
    }

    private static let mouseItemTag = 7_401

    private func refreshMouseItems(in menu: NSMenu) {
        menu.items.filter { $0.tag == Self.mouseItemTag }.forEach(menu.removeItem)
        var items = ConnectedMice.current().map { $0.menuItem() }
        if items.isEmpty {
            items = [NSMenuItem(title: "No mouse connected", action: nil, keyEquivalent: "")]
        }
        items.append(.separator())
        for (index, item) in items.enumerated() {
            item.tag = Self.mouseItemTag
            menu.insertItem(item, at: index)
        }
    }
}
