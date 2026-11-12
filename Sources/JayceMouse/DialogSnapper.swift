import AppKit
import ApplicationServices

/// "Snap to default button": whenever a dialog or sheet appears in any app, move the pointer onto its
/// default button (OK, Save, Allow…), like the "Snap To" mouse option on Windows.
/// Uses the Accessibility API, so it only runs while JayceMouse has Accessibility access.
@MainActor
final class DialogSnapper {
    private(set) var isRunning = false
    private var observers: [pid_t: AXObserver] = [:]
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    /// Windows already handled, so the pointer is not pulled back every time focus returns to them.
    private var recent: [AXUIElement] = []
    private let ownPID = getpid()

    /// Titles used to find a confirm button when a dialog does not mark a default button.
    private let confirmTitles: Set<String> = ["ok", "đồng ý", "allow", "cho phép"]

    func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        for app in NSWorkspace.shared.runningApplications { observe(app) }

        let workspace = NSWorkspace.shared.notificationCenter
        let launched = workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // A freshly launched app may not answer Accessibility requests yet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                MainActor.assumeIsolated { self?.observe(app) }
            }
        }
        let activated = workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.observe(app) }
        }
        let terminated = workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.unobserve(app.processIdentifier) }
        }
        // JayceMouse's own dialogs: Accessibility calls into our own process would block the main thread,
        // so these are handled with AppKit directly.
        let ownKey = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                MainActor.assumeIsolated { self?.snapOwn(window) }
            }
        }
        tokens = [(workspace, launched), (workspace, activated), (workspace, terminated), (NotificationCenter.default, ownKey)]
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        for (center, token) in tokens { center.removeObserver(token) }
        tokens = []
        for pid in Array(observers.keys) { unobserve(pid) }
        recent = []
    }

    // MARK: Observing other apps

    private func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard isRunning, pid > 0, pid != ownPID, observers[pid] == nil, !app.isTerminated else { return }

        var created: AXObserver?
        guard AXObserverCreate(pid, dialogSnapperCallback, &created) == .success, let observer = created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.5)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let names = [kAXWindowCreatedNotification, kAXSheetCreatedNotification, kAXFocusedWindowChangedNotification]
        var added = 0
        for name in names where AXObserverAddNotification(observer, appElement, name as CFString, refcon) == .success {
            added += 1
        }
        guard added > 0 else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func unobserve(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    fileprivate func handle(_ element: AXUIElement, notification: String) {
        let created = notification != kAXFocusedWindowChangedNotification
        // Dialogs animate in and lay out their buttons a little later, so look a few times.
        for delay in [0.15, 0.4, 0.9] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.snap(to: element, created: created) }
            }
        }
    }

    private func snap(to element: AXUIElement, created: Bool) {
        guard isRunning, NSEvent.pressedMouseButtons == 0 else { return }
        AXUIElementSetMessagingTimeout(element, 0.5)
        // The notification may name the parent window; its sheet is then one of its children.
        for target in [element] + childSheets(of: element) {
            guard !recent.contains(where: { CFEqual($0, target) }) else { continue }
            let dialog = isDialog(target)
            // A plain window only counts when it was just created and marks a default button.
            guard dialog || created else { continue }
            guard let button = defaultButton(in: target, searchTitles: dialog),
                  let point = center(of: button) else { continue }
            recent.insert(target, at: 0)
            if recent.count > 20 { recent.removeLast() }
            warp(to: point)
            return
        }
    }

    private func childSheets(of element: AXUIElement) -> [AXUIElement] {
        children(element).filter { string($0, kAXRoleAttribute) == kAXSheetRole }
    }

    private func isDialog(_ element: AXUIElement) -> Bool {
        let role = string(element, kAXRoleAttribute)
        if role == kAXSheetRole { return true }
        guard role == kAXWindowRole else { return false }
        let subrole = string(element, kAXSubroleAttribute)
        return subrole == kAXDialogSubrole || subrole == kAXSystemDialogSubrole || subrole == kAXFloatingWindowSubrole
    }

    private func defaultButton(in window: AXUIElement, searchTitles: Bool) -> AXUIElement? {
        if let button = element(window, kAXDefaultButtonAttribute), isEnabled(button) {
            return button
        }
        return searchTitles ? findConfirmButton(in: window) : nil
    }

    /// Breadth-first search for a button titled OK when the dialog does not expose a default button.
    private func findConfirmButton(in root: AXUIElement) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0
        while !queue.isEmpty, visited < 300 {
            let (element, depth) = queue.removeFirst()
            visited += 1
            if string(element, kAXRoleAttribute) == kAXButtonRole,
               let title = string(element, kAXTitleAttribute)?.trimmingCharacters(in: .whitespaces).lowercased(),
               confirmTitles.contains(title), isEnabled(element) {
                return element
            }
            guard depth < 6 else { continue }
            queue.append(contentsOf: children(element).map { ($0, depth + 1) })
        }
        return nil
    }

    private func center(of element: AXUIElement) -> CGPoint? {
        guard let positionValue = axValue(element, kAXPositionAttribute),
              let sizeValue = axValue(element, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    // MARK: JayceMouse's own windows

    private func snapOwn(_ window: NSWindow) {
        guard isRunning, NSEvent.pressedMouseButtons == 0, window.isVisible,
              window.isSheet || window.styleMask.contains(.docModalWindow) || window is NSPanel,
              let button = (window.defaultButtonCell?.controlView as? NSButton) ?? returnKeyButton(in: window.contentView),
              button.isEnabled, !button.isHidden else { return }
        let inWindow = button.convert(button.bounds, to: nil)
        let onScreen = window.convertToScreen(inWindow)
        // AppKit measures from the bottom-left of the main screen; Quartz from the top-left.
        guard let mainHeight = NSScreen.screens.first?.frame.height else { return }
        warp(to: CGPoint(x: onScreen.midX, y: mainHeight - onScreen.midY))
    }

    /// NSAlert marks its first button with the Return key rather than as the window's default button cell.
    private func returnKeyButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton, button.keyEquivalent == "\r" { return button }
        for sub in view.subviews {
            if let found = returnKeyButton(in: sub) { return found }
        }
        return nil
    }

    /// Opens a test alert so the feature can be checked from Settings.
    func showTestAlert() {
        let alert = NSAlert()
        alert.messageText = tr("Snap to OK test")
        alert.informativeText = tr("If the feature works, the pointer is now on the OK button.")
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: tr("Cancel"))
        alert.runModal()
    }

    // MARK: Helpers

    private func warp(to point: CGPoint) {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 16, &displays, &count) == .success, count > 0 else { return }
        CGWarpMouseCursorPosition(point)
        // Warping briefly freezes the pointer; reconnect it to the mouse right away.
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    private func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success else { return nil }
        return raw
    }

    private func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = copy(element, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    private func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let raw = copy(element, attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        return (raw as! AXValue)
    }

    private func children(_ element: AXUIElement) -> [AXUIElement] {
        (copy(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    private func isEnabled(_ element: AXUIElement) -> Bool {
        (copy(element, kAXEnabledAttribute) as? Bool) ?? true
    }
}

private func dialogSnapperCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let snapper = Unmanaged<DialogSnapper>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated { snapper.handle(element, notification: name) }
}
