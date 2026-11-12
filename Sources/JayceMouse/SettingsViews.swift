import SwiftUI
import JayceMouseCore

private func caption(_ smoothness: ScrollSmoothness) -> String {
    switch smoothness {
    case .off: return tr("Raw scroll wheel steps, only with the speed and direction you choose.")
    case .low: return tr("Short, snappy glide that stops quickly.")
    case .regular: return tr("Balanced glide — comfortable for documents and the web.")
    case .high: return tr("Long, silky inertia like an Apple trackpad.")
    }
}

struct ScrollSettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "Scrolling", subtitle: "Make a plain scroll wheel glide like a trackpad.")

            Card {
                VStack(alignment: .leading, spacing: 18) {
                    SettingToggleRow(symbol: "wind", title: "Enhance scrolling", detail: "Turn off to hand scrolling back to macOS.", isOn: $model.config.scroll.enabled, tint: Theme.cyan)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Smoothness")).font(.system(size: 14, weight: .semibold))
                        SegmentedPills(options: ScrollSmoothness.allCases, selection: $model.config.scroll.smoothness) { $0.rawValue.capitalized }
                        Text(caption(model.config.scroll.smoothness)).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Speed")).font(.system(size: 14, weight: .semibold))
                        SegmentedPills(options: ScrollSpeed.allCases, selection: $model.config.scroll.speed) { $0.rawValue.capitalized }
                        Text(tr("Scroll faster and the distance accelerates automatically.")).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(model.config.scroll.enabled ? 1 : 0.55)

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "arrow.up.arrow.down", title: "Reverse direction", detail: "Flip the direction macOS gives the scroll wheel. Off follows your System Settings.", isOn: $model.config.scroll.reverseDirection, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "hand.draw", title: "Trackpad simulation", detail: "Sends trackpad-style phases so apps use rubber banding and momentum.", isOn: $model.config.scroll.trackpadSimulation, tint: Theme.violet)
                    Divider()
                    SettingToggleRow(symbol: "tortoise", title: "Precise by default", detail: "Smaller steps for detail work. Hold ⌥ Option for this on demand.", isOn: $model.config.scroll.preciseByDefault, tint: Theme.mint)
                }
            }
            .opacity(model.config.scroll.enabled ? 1 : 0.55)

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("Hold a key while scrolling")).font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 10) {
                        shortcutChip("⇧ Shift", "Horizontal")
                        shortcutChip("⌃ Control", "Quick")
                        shortcutChip("⌥ Option", "Precise")
                        shortcutChip("⌘ Command", "Zoom")
                    }
                }
            }

            ScrollPlayground()
        }
    }

    private func shortcutChip(_ key: String, _ action: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tr(key)).font(.system(size: 13, weight: .bold))
            Text(tr(action)).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

struct ScrollPlayground: View {
    private let colors: [Color] = [Theme.violet, Theme.cyan, Theme.pink, Theme.mint]

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(tr("Try it here"), systemImage: "hand.point.up.left.fill").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(tr("Scroll with your mouse wheel")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(20)
                Divider()
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<24, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(colors[i % colors.count].gradient.opacity(0.85))
                                .frame(height: 64)
                                .overlay(alignment: .leading) {
                                    Text(tr("Row %@", "\(i + 1)")).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white).padding(.leading, 20)
                                }
                        }
                    }
                    .padding(20)
                }
                .frame(height: 260)
            }
        }
    }
}

struct PointerView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "Pointer", subtitle: "Tune how the cursor tracks your mouse.")

            Card {
                VStack(alignment: .leading, spacing: 20) {
                    SettingToggleRow(symbol: "gearshape.2", title: "Use system settings", detail: "Leave pointer speed and acceleration exactly as macOS has them.", isOn: $model.config.pointer.useSystemAcceleration, tint: Theme.violet)
                    Divider()
                    slider(title: "Sensitivity", value: $model.config.pointer.sensitivity, low: "Slow", high: "Fast")
                    slider(title: "Acceleration", value: $model.config.pointer.acceleration, low: "Linear", high: "Strong")
                    Text(tr("Acceleration at the lowest setting makes the pointer move 1:1 with your hand. Changes apply to the system mouse speed while JayceMouse is running and are restored when you quit."))
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }
            .opacity(model.config.pointer.useSystemAcceleration ? 0.55 : 1)
            .allowsHitTesting(true)
        }
    }

    private func slider(title: String, value: Binding<Double>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr(title)).font(.system(size: 14, weight: .semibold))
            HStack(spacing: 12) {
                Text(tr(low)).font(.system(size: 12)).foregroundStyle(.secondary)
                Slider(value: value, in: 0...1).tint(Theme.violet)
                Text(tr(high)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .disabled(model.config.pointer.useSystemAcceleration)
    }
}

struct GeneralView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "General", subtitle: "Startup, menu bar and safety switches.")

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "power", title: "Launch at login", detail: "Start JayceMouse automatically when you sign in.", isOn: $model.config.general.launchAtLogin, tint: Theme.mint)
                    Divider()
                    SettingToggleRow(symbol: "menubar.rectangle", title: "Show menu bar icon", detail: "Quick access to pause features without opening the window.", isOn: $model.config.general.showMenuBarItem, tint: Theme.cyan)
                    if !model.config.general.showMenuBarItem {
                        Text(tr("With the menu bar icon off, JayceMouse keeps its Dock icon so you can still open it."))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    SettingToggleRow(symbol: "computermouse", title: "Show mouse battery", detail: "Shows the battery % of your Bluetooth mouse at the top of the menu bar menu.", isOn: $model.config.general.showMouseBattery, tint: Theme.mint)
                    if model.config.general.showMouseBattery {
                        Label(tr("Whether a device shows up depends on the device: many mice do not report their battery level to macOS, so no app can read it."), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    SettingToggleRow(symbol: "keyboard", title: "Show keyboard battery", detail: "Shows the battery % of your Bluetooth keyboard at the top of the menu bar menu.", isOn: $model.config.general.showKeyboardBattery, tint: Theme.mint)
                }
            }

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "cursorarrow.click.2", title: "Disable button actions", detail: "Temporarily pass every button straight through to macOS.", isOn: $model.config.general.buttonKillSwitch, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "wind", title: "Disable scroll enhancements", detail: "Temporarily hand scrolling back to macOS.", isOn: $model.config.general.scrollKillSwitch, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "lock", title: "Lock pointer during drag", detail: "Freeze the cursor while a Click & Drag gesture is active.", isOn: $model.config.general.lockPointerDuringDrag, tint: Theme.violet)
                    Divider()
                    SettingToggleRow(symbol: "cursorarrow.rays", title: "Snap pointer to OK button", detail: "When a dialog asks you to confirm, move the pointer onto its OK (default) button.", isOn: $model.config.general.snapToDefaultButton, tint: Theme.mint)
                    HStack {
                        Spacer()
                        Button(tr("Test with a dialog")) { model.testDialogSnap() }
                            .buttonStyle(GradientButtonStyle(prominent: false))
                            .disabled(!model.config.general.snapToDefaultButton)
                    }
                }
            }

            Card {
                HStack(spacing: 14) {
                    Image(systemName: model.trusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(model.trusted ? Theme.mint : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Accessibility access")).font(.system(size: 14, weight: .semibold))
                        Text(tr(model.trusted ? "Granted — JayceMouse can see and adjust your mouse." : "Not granted — nothing will work until you allow it."))
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(tr("Open Settings")) { model.openAccessibilitySettings() }.buttonStyle(GradientButtonStyle(prominent: false))
                }
            }

            HStack(spacing: 10) {
                Button(tr("Reveal config file")) {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.fileURL])
                }
                .buttonStyle(GradientButtonStyle(prominent: false))
                Button(tr("Reset everything…")) { confirmReset = true }
                    .buttonStyle(GradientButtonStyle(prominent: false))
            }
            .confirmationDialog(tr("Reset all JayceMouse settings?"), isPresented: $confirmReset) {
                Button(tr("Reset"), role: .destructive) { model.resetAll() }
            } message: {
                Text(tr("Buttons, scrolling, pointer and general settings return to their defaults."))
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "About", subtitle: "A modern take on a great idea.")
            Card(padding: 32) {
                HStack(spacing: 24) {
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.gradient))
                        .shadow(color: Theme.violet.opacity(0.4), radius: 16, y: 8)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("JayceMouse")).font(.system(size: 26, weight: .bold, design: .rounded))
                        Text(tr("Version %@", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(tr("Smooth scrolling, trackpad-style gestures and fully custom buttons for any mouse."))
                            .font(.system(size: 13.5)).foregroundStyle(.secondary)
                    }
                }
            }
            Card {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Enjoying JayceMouse?")).font(.system(size: 14, weight: .semibold))
                        Text(tr("It is free and always will be. A coffee keeps the updates coming."))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link(destination: URL(string: "https://jaycemouse.vercel.app/#support")!) {
                        Label(tr("Buy me a coffee"), systemImage: "cup.and.saucer.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Acknowledgements")).font(.system(size: 14, weight: .semibold))
                    Text(tr("JayceMouse is inspired by Mac Mouse Fix by Noah Nuebling. It is an independent implementation written from scratch and shares no code or assets with it."))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Link(tr("Mac Mouse Fix on GitHub"), destination: URL(string: "https://github.com/noah-nuebling/mac-mouse-fix")!)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }
}
