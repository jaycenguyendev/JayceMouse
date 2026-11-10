import SwiftUI
import JayceMouseCore

private func caption(_ smoothness: ScrollSmoothness) -> String {
    switch smoothness {
    case .off: return "Raw scroll wheel steps, only with the speed and direction you choose."
    case .low: return "Short, snappy glide that stops quickly."
    case .regular: return "Balanced glide — comfortable for documents and the web."
    case .high: return "Long, silky inertia like an Apple trackpad."
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
                        Text("Smoothness").font(.system(size: 14, weight: .semibold))
                        SegmentedPills(options: ScrollSmoothness.allCases, selection: $model.config.scroll.smoothness) { $0.rawValue.capitalized }
                        Text(caption(model.config.scroll.smoothness)).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Speed").font(.system(size: 14, weight: .semibold))
                        SegmentedPills(options: ScrollSpeed.allCases, selection: $model.config.scroll.speed) { $0.rawValue.capitalized }
                        Text("Scroll faster and the distance accelerates automatically.").font(.system(size: 12.5)).foregroundStyle(.secondary)
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
                    Text("Hold a key while scrolling").font(.system(size: 14, weight: .semibold))
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
            Text(key).font(.system(size: 13, weight: .bold))
            Text(action).font(.system(size: 12)).foregroundStyle(.secondary)
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
                    Label("Try it here", systemImage: "hand.point.up.left.fill").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("Scroll with your mouse wheel").font(.system(size: 12)).foregroundStyle(.secondary)
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
                                    Text("Row \(i + 1)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white).padding(.leading, 20)
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
                    Text("Acceleration at the lowest setting makes the pointer move 1:1 with your hand. Changes apply to the system mouse speed while JayceMouse is running and are restored when you quit.")
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }
            .opacity(model.config.pointer.useSystemAcceleration ? 0.55 : 1)
            .allowsHitTesting(true)
        }
    }

    private func slider(title: String, value: Binding<Double>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .semibold))
            HStack(spacing: 12) {
                Text(low).font(.system(size: 12)).foregroundStyle(.secondary)
                Slider(value: value, in: 0...1).tint(Theme.violet)
                Text(high).font(.system(size: 12)).foregroundStyle(.secondary)
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
                }
            }

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "cursorarrow.click.2", title: "Disable button actions", detail: "Temporarily pass every button straight through to macOS.", isOn: $model.config.general.buttonKillSwitch, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "wind", title: "Disable scroll enhancements", detail: "Temporarily hand scrolling back to macOS.", isOn: $model.config.general.scrollKillSwitch, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "lock", title: "Lock pointer during drag", detail: "Freeze the cursor while a Click & Drag gesture is active.", isOn: $model.config.general.lockPointerDuringDrag, tint: Theme.violet)
                }
            }

            Card {
                HStack(spacing: 14) {
                    Image(systemName: model.trusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(model.trusted ? Theme.mint : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility access").font(.system(size: 14, weight: .semibold))
                        Text(model.trusted ? "Granted — JayceMouse can see and adjust your mouse." : "Not granted — nothing will work until you allow it.")
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") { model.openAccessibilitySettings() }.buttonStyle(GradientButtonStyle(prominent: false))
                }
            }

            HStack(spacing: 10) {
                Button("Reveal config file") {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.fileURL])
                }
                .buttonStyle(GradientButtonStyle(prominent: false))
                Button("Reset everything…") { confirmReset = true }
                    .buttonStyle(GradientButtonStyle(prominent: false))
            }
            .confirmationDialog("Reset all JayceMouse settings?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { model.resetAll() }
            } message: {
                Text("Buttons, scrolling, pointer and general settings return to their defaults.")
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
                        Text("JayceMouse").font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        Text("Smooth scrolling, trackpad-style gestures and fully custom buttons for any mouse.")
                            .font(.system(size: 13.5)).foregroundStyle(.secondary)
                    }
                }
            }
            Card {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enjoying JayceMouse?").font(.system(size: 14, weight: .semibold))
                        Text("It is free and always will be. A coffee keeps the updates coming.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link(destination: URL(string: "https://jaycemouse.vercel.app/#support")!) {
                        Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Acknowledgements").font(.system(size: 14, weight: .semibold))
                    Text("JayceMouse is inspired by Mac Mouse Fix by Noah Nuebling. It is an independent implementation written from scratch and shares no code or assets with it.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Link("Mac Mouse Fix on GitHub", destination: URL(string: "https://github.com/noah-nuebling/mac-mouse-fix")!)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }
}
