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
                    symbol: "wind", title: tr("Smooth Scrolling", "Cuộn mượt"),
                    detail: model.config.scroll.smoothness == .off ? ScrollActivity.direct.title : model.config.scroll.smoothness.title,
                    tint: Theme.cyan,
                    isOn: Binding(get: { !model.config.general.scrollKillSwitch }, set: { model.config.general.scrollKillSwitch = !$0 })
                ) { navigate(.scroll) }
                tile(
                    symbol: "cursorarrow.click.2", title: tr("Button Actions", "Thao tác nút"),
                    detail: tr("\(model.config.remaps.count) remaps", "\(model.config.remaps.count) thao tác"),
                    tint: Theme.violet,
                    isOn: Binding(get: { !model.config.general.buttonKillSwitch }, set: { model.config.general.buttonKillSwitch = !$0 })
                ) { navigate(.buttons) }
                tile(
                    symbol: "arrow.up.arrow.down", title: tr("Reverse Scroll", "Đảo chiều cuộn"),
                    detail: model.config.scroll.reverseDirection ? tr("Reversed", "Đã đảo chiều") : tr("Follows system", "Theo hệ thống"),
                    tint: Theme.pink,
                    isOn: $model.config.scroll.reverseDirection
                ) { navigate(.scroll) }
            }
            miceCard
            activityCard
        }
    }

    private var hero: some View {
        Card(padding: 28) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.trusted ? tr("Your mouse, supercharged.", "Chuột của bạn, mạnh hơn.") : tr("One step to get started.", "Chỉ một bước để bắt đầu."))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gradient)
                    Text(model.trusted
                         ? tr("Smooth scrolling, trackpad-style gestures and fully custom buttons — working system-wide. Press any button on your mouse to see it light up.",
                              "Cuộn mượt, cử chỉ như trackpad và nút bấm tùy chỉnh hoàn toàn — hoạt động trên toàn hệ thống. Nhấn bất kỳ nút nào trên chuột để thấy nút đó sáng lên.")
                         : tr("JayceMouse needs Accessibility access to read your mouse and add smooth scrolling and button actions.",
                              "JayceMouse cần quyền Trợ năng để đọc chuột và thêm cuộn mượt cùng thao tác nút."))
                        .font(.system(size: 14.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button { navigate(.buttons) } label: { Label(tr("Customize Buttons", "Tùy chỉnh nút"), systemImage: "wand.and.stars") }
                            .buttonStyle(GradientButtonStyle())
                        Button { navigate(.scroll) } label: { Label(tr("Tune Scrolling", "Chỉnh cuộn"), systemImage: "dial.medium") }
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
                    Text(tr("Allow Accessibility access", "Cho phép quyền Trợ năng")).font(.system(size: 15, weight: .semibold))
                    Text(tr("Open System Settings → Privacy & Security → Accessibility and switch JayceMouse on. This page updates automatically.",
                             "Mở Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Trợ năng và bật JayceMouse. Trang này sẽ tự cập nhật."))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(tr("Grant Access", "Cấp quyền")) {
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
                    Text(title).font(.system(size: 14.5, weight: .semibold))
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    private var miceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label(tr("Connected mice", "Chuột đang kết nối"), systemImage: "computermouse.fill")
                    .font(.system(size: 14, weight: .semibold))
                if model.connectedMice.isEmpty {
                    Text(tr("No mouse connected", "Chưa kết nối chuột"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(model.connectedMice.enumerated()), id: \.offset) { _, mouse in
                            HStack(spacing: 10) {
                                Image(systemName: "computermouse")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.cyan)
                                    .frame(width: 20)
                                Text(mouse.name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 12)
                                if let percent = mouse.batteryPercent {
                                    Text("\(percent)%")
                                        .font(.system(size: 13).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    BatteryIcon(percent: percent)
                                } else {
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                        .help(tr("This mouse doesn't report its battery level to macOS.", "Chuột này không báo mức pin cho macOS."))
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private var activityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(tr("Live activity", "Hoạt động trực tiếp"), systemImage: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(model.engineRunning ? tr("Listening", "Đang lắng nghe") : tr("Idle", "Đang chờ"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(model.engineRunning ? Theme.mint : .secondary)
                }
                if model.activity.isEmpty {
                    Text(tr("Move, click or scroll with your mouse and events will show up here.", "Di chuyển, nhấn hoặc cuộn chuột, các sự kiện sẽ hiện ở đây."))
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

struct BatteryIcon: View {
    let percent: Int

    var body: some View {
        HStack(spacing: 1.5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.secondary, lineWidth: 1)
                .frame(width: 24, height: 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(percent <= 20 ? Color.red : Color.primary)
                        .frame(width: max(1.5, 20 * CGFloat(percent) / 100), height: 8)
                        .padding(.leading, 2)
                }
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(.secondary)
                .frame(width: 1.5, height: 4.5)
        }
        .accessibilityHidden(true)
    }
}
