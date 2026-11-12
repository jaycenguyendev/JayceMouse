import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var model: AppModel
    let navigate: (Page) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            if !model.trusted { permissionCard }
            HStack(spacing: 16) {
                tile(
                    symbol: "wind", title: "Smooth Scrolling",
                    detail: tr(model.config.scroll.smoothness == .off ? "Direct" : model.config.scroll.smoothness.rawValue.capitalized),
                    tint: Theme.cyan,
                    isOn: Binding(get: { !model.config.general.scrollKillSwitch }, set: { model.config.general.scrollKillSwitch = !$0 })
                ) { navigate(.scroll) }
                tile(
                    symbol: "cursorarrow.click.2", title: "Button Actions",
                    detail: tr("%@ remaps", "\(model.config.remaps.count)"),
                    tint: Theme.violet,
                    isOn: Binding(get: { !model.config.general.buttonKillSwitch }, set: { model.config.general.buttonKillSwitch = !$0 })
                ) { navigate(.buttons) }
                tile(
                    symbol: "arrow.up.arrow.down", title: "Reverse Scroll",
                    detail: tr(model.config.scroll.reverseDirection ? "Reversed" : "Follows system"),
                    tint: Theme.pink,
                    isOn: $model.config.scroll.reverseDirection
                ) { navigate(.scroll) }
            }
            activityCard
        }
    }

    private var hero: some View {
        Card(padding: 28) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tr(model.trusted ? "Your mouse, supercharged." : "One step to get started."))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gradient)
                    Text(tr(model.trusted
                         ? "Smooth scrolling, trackpad-style gestures and fully custom buttons — working system-wide. Press any button on your mouse to see it light up."
                         : "JayceMouse needs Accessibility access to read your mouse and add smooth scrolling and button actions."))
                        .font(.system(size: 14.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button { navigate(.buttons) } label: { Label(tr("Customize Buttons"), systemImage: "wand.and.stars") }
                            .buttonStyle(GradientButtonStyle())
                        Button { navigate(.scroll) } label: { Label(tr("Tune Scrolling"), systemImage: "dial.medium") }
                            .buttonStyle(GradientButtonStyle(prominent: false))
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
                MouseDiagram(pressed: model.pressedButtons, pulse: model.scrollPulse)
            }
        }
    }

    private var permissionCard: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.warmGradient)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Allow Accessibility access")).font(.system(size: 15, weight: .semibold))
                    Text(tr("Open %@ and switch JayceMouse on. This page updates automatically.", AppModel.accessibilitySettingsPath))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(tr("Grant Access")) {
                    model.requestPermission()
                    model.openAccessibilitySettings()
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
    }

    private func tile(symbol: String, title: String, detail: String, tint: Color, isOn: Binding<Bool>, open: @escaping () -> Void) -> some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.gradient))
                    Spacer()
                    Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr(title)).font(.system(size: 14.5, weight: .semibold))
                    Text(tr(detail)).font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    private var activityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(tr("Live activity"), systemImage: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(tr(model.engineRunning ? "Listening" : "Idle"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(model.engineRunning ? Theme.mint : .secondary)
                }
                if model.activity.isEmpty {
                    Text(tr("Move, click or scroll with your mouse and events will show up here."))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.activity.prefix(6)) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.violet)
                                    .frame(width: 20)
                                Text(item.text).font(.system(size: 13))
                                Spacer()
                                Text(item.date, style: .time)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 7)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: model.activity.count)
                }
            }
        }
    }
}
