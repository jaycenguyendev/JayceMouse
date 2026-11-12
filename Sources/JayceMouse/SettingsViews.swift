import SwiftUI
import JayceMouseCore

private func caption(_ smoothness: ScrollSmoothness) -> String {
    switch smoothness {
    case .off: return tr("Raw scroll wheel steps, only with the speed and direction you choose.", "Bước cuộn gốc của bánh xe, chỉ áp dụng tốc độ và hướng bạn chọn.")
    case .low: return tr("Short, snappy glide that stops quickly.", "Lướt ngắn, gọn và dừng nhanh.")
    case .regular: return tr("Balanced glide — comfortable for documents and the web.", "Lướt cân bằng — dễ chịu khi đọc tài liệu và lướt web.")
    case .high: return tr("Long, silky inertia like an Apple trackpad.", "Quán tính dài, mượt như trackpad của Apple.")
    }
}

struct ScrollSettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: tr("Scrolling", "Cuộn"), subtitle: tr("Make a plain scroll wheel glide like a trackpad.", "Giúp bánh xe cuộn thường lướt mượt như trackpad."))

            Card {
                VStack(alignment: .leading, spacing: 18) {
                    SettingToggleRow(symbol: "wind", title: tr("Enhance scrolling", "Tăng cường cuộn"), detail: tr("Turn off to hand scrolling back to macOS.", "Tắt để trả việc cuộn lại cho macOS."), isOn: $model.config.scroll.enabled, tint: Theme.cyan)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Smoothness", "Độ mượt")).font(.system(size: 14, weight: .semibold))
                        SegmentedPills(options: ScrollSmoothness.allCases, selection: $model.config.scroll.smoothness) { $0.title }
                        Text(caption(model.config.scroll.smoothness)).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Speed", "Tốc độ")).font(.system(size: 14, weight: .semibold))
                        SegmentedPills(options: ScrollSpeed.allCases, selection: $model.config.scroll.speed) { $0.title }
                        Text(tr("Scroll faster and the distance accelerates automatically.", "Cuộn càng nhanh, quãng đường càng tự động tăng tốc.")).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(model.config.scroll.enabled ? 1 : 0.55)

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "arrow.up.arrow.down", title: tr("Reverse direction", "Đảo chiều cuộn"), detail: tr("Flip the direction macOS gives the scroll wheel. Off follows your System Settings.", "Đảo hướng cuộn mà macOS áp dụng cho bánh xe. Khi tắt sẽ theo Cài đặt hệ thống."), isOn: $model.config.scroll.reverseDirection, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "hand.draw", title: tr("Trackpad simulation", "Giả lập trackpad"), detail: tr("Sends trackpad-style phases so apps use rubber banding and momentum.", "Gửi các pha cuộn như trackpad để ứng dụng có hiệu ứng nảy và quán tính."), isOn: $model.config.scroll.trackpadSimulation, tint: Theme.violet)
                    Divider()
                    SettingToggleRow(symbol: "tortoise", title: tr("Precise by default", "Mặc định cuộn chính xác"), detail: tr("Smaller steps for detail work. Hold ⌥ Option for this on demand.", "Bước nhỏ hơn cho công việc tỉ mỉ. Giữ ⌥ Option để dùng khi cần."), isOn: $model.config.scroll.preciseByDefault, tint: Theme.mint)
                }
            }
            .opacity(model.config.scroll.enabled ? 1 : 0.55)

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("Hold a key while scrolling", "Giữ phím khi cuộn")).font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 10) {
                        shortcutChip("⇧ Shift", ScrollActivity.horizontal.title)
                        shortcutChip("⌃ Control", ScrollActivity.quick.title)
                        shortcutChip("⌥ Option", ScrollActivity.precise.title)
                        shortcutChip("⌘ Command", ScrollActivity.zoom.title)
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
                    Label(tr("Try it here", "Thử ở đây"), systemImage: "hand.point.up.left.fill").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(tr("Scroll with your mouse wheel", "Cuộn bằng bánh xe chuột")).font(.system(size: 12)).foregroundStyle(.secondary)
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
                                    Text(tr("Row \(i + 1)", "Hàng \(i + 1)")).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white).padding(.leading, 20)
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
            PageHeader(title: tr("Pointer", "Con trỏ"), subtitle: tr("Tune how the cursor tracks your mouse.", "Điều chỉnh cách con trỏ bám theo chuột."))

            Card {
                VStack(alignment: .leading, spacing: 20) {
                    SettingToggleRow(symbol: "gearshape.2", title: tr("Use system settings", "Dùng cài đặt hệ thống"), detail: tr("Leave pointer speed and acceleration exactly as macOS has them.", "Giữ nguyên tốc độ và gia tốc con trỏ như macOS đang đặt."), isOn: $model.config.pointer.useSystemAcceleration, tint: Theme.violet)
                    Divider()
                    slider(title: tr("Sensitivity", "Độ nhạy"), value: $model.config.pointer.sensitivity, low: tr("Slow", "Chậm"), high: tr("Fast", "Nhanh"))
                    slider(title: tr("Acceleration", "Gia tốc"), value: $model.config.pointer.acceleration, low: tr("Linear", "Tuyến tính"), high: tr("Strong", "Mạnh"))
                    Text(tr("Acceleration at the lowest setting makes the pointer move 1:1 with your hand. Changes apply to the system mouse speed while JayceMouse is running and are restored when you quit.",
                             "Gia tốc ở mức thấp nhất giúp con trỏ di chuyển đúng 1:1 theo tay bạn. Thay đổi áp dụng cho tốc độ chuột của hệ thống khi JayceMouse đang chạy và được khôi phục khi bạn thoát."))
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
            PageHeader(title: tr("General", "Cài đặt chung"), subtitle: tr("Startup, menu bar, language and safety switches.", "Khởi động, thanh menu, ngôn ngữ và công tắc an toàn."))

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "globe")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.violet.gradient))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Language", "Ngôn ngữ")).font(.system(size: 14, weight: .semibold))
                            Text(tr("Changes the app and menu bar text right away.", "Đổi ngôn ngữ của ứng dụng và menu trên thanh menu ngay lập tức."))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    SegmentedPills(options: AppLanguage.allCases, selection: $model.config.general.language) { $0.displayName }
                }
            }

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "power", title: tr("Launch at login", "Mở khi đăng nhập"), detail: tr("Start JayceMouse automatically when you sign in.", "Tự động mở JayceMouse khi bạn đăng nhập."), isOn: $model.config.general.launchAtLogin, tint: Theme.mint)
                    if model.config.general.launchAtLogin && model.loginItemStatus != .enabled {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange)
                            Text(model.loginItemStatus == .requiresApproval
                                 ? tr("macOS is blocking JayceMouse from opening at login. Turn it on under Open at Login / Allow in the Background.",
                                      "macOS đang chặn JayceMouse mở khi đăng nhập. Hãy bật trong Mở khi đăng nhập / Cho phép chạy nền.")
                                 : tr("macOS has not registered JayceMouse as a login item. Check Login Items in System Settings.",
                                      "macOS chưa đăng ký JayceMouse làm mục đăng nhập. Hãy kiểm tra Mục đăng nhập trong Cài đặt hệ thống."))
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Button(tr("Open Login Items", "Mở Mục đăng nhập")) { model.openLoginItemsSettings() }.buttonStyle(GradientButtonStyle(prominent: false))
                        }
                    }
                    Divider()
                    SettingToggleRow(symbol: "menubar.rectangle", title: tr("Show menu bar icon", "Hiện biểu tượng trên thanh menu"), detail: tr("Quick access to pause features without opening the window.", "Truy cập nhanh để tạm dừng tính năng mà không cần mở cửa sổ."), isOn: $model.config.general.showMenuBarItem, tint: Theme.cyan)
                }
            }

            Card {
                VStack(spacing: 10) {
                    SettingToggleRow(symbol: "cursorarrow.click.2", title: tr("Disable button actions", "Tắt thao tác nút"), detail: tr("Temporarily pass every button straight through to macOS.", "Tạm thời chuyển thẳng mọi nút cho macOS xử lý."), isOn: $model.config.general.buttonKillSwitch, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "wind", title: tr("Disable scroll enhancements", "Tắt tăng cường cuộn"), detail: tr("Temporarily hand scrolling back to macOS.", "Tạm thời trả việc cuộn lại cho macOS."), isOn: $model.config.general.scrollKillSwitch, tint: Theme.pink)
                    Divider()
                    SettingToggleRow(symbol: "lock", title: tr("Lock pointer during drag", "Khóa con trỏ khi kéo"), detail: tr("Freeze the cursor while a Click & Drag gesture is active.", "Giữ yên con trỏ khi đang thực hiện cử chỉ Nhấn & Kéo."), isOn: $model.config.general.lockPointerDuringDrag, tint: Theme.violet)
                }
            }

            Card {
                HStack(spacing: 14) {
                    Image(systemName: model.trusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(model.trusted ? Theme.mint : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Accessibility access", "Quyền Trợ năng")).font(.system(size: 14, weight: .semibold))
                        Text(model.trusted ? tr("Granted — JayceMouse can see and adjust your mouse.", "Đã cấp — JayceMouse có thể nhận và điều chỉnh chuột của bạn.") : tr("Not granted — nothing will work until you allow it.", "Chưa cấp — mọi tính năng sẽ không hoạt động cho tới khi bạn cho phép."))
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(tr("Open Settings", "Mở Cài đặt")) { model.openAccessibilitySettings() }.buttonStyle(GradientButtonStyle(prominent: false))
                }
            }

            HStack(spacing: 10) {
                Button(tr("Reveal config file", "Hiện tệp cấu hình")) {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.fileURL])
                }
                .buttonStyle(GradientButtonStyle(prominent: false))
                Button(tr("Reset everything…", "Đặt lại tất cả…")) { confirmReset = true }
                    .buttonStyle(GradientButtonStyle(prominent: false))
            }
            .confirmationDialog(tr("Reset all JayceMouse settings?", "Đặt lại toàn bộ cài đặt JayceMouse?"), isPresented: $confirmReset) {
                Button(tr("Reset", "Đặt lại"), role: .destructive) { model.resetAll() }
            } message: {
                Text(tr("Buttons, scrolling, pointer and general settings return to their defaults. Your language choice is kept.", "Nút bấm, cuộn, con trỏ và cài đặt chung sẽ về mặc định. Lựa chọn ngôn ngữ được giữ nguyên."))
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: tr("About", "Giới thiệu"), subtitle: tr("A modern take on a great idea.", "Một cách làm hiện đại cho một ý tưởng tuyệt vời."))
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
                        Text(tr("Version", "Phiên bản") + " " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(tr("Smooth scrolling, trackpad-style gestures and fully custom buttons for any mouse.", "Cuộn mượt, cử chỉ như trackpad và nút bấm tùy chỉnh hoàn toàn cho mọi loại chuột."))
                            .font(.system(size: 13.5)).foregroundStyle(.secondary)
                    }
                }
            }
            Card {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Enjoying JayceMouse?", "Bạn thích JayceMouse?")).font(.system(size: 14, weight: .semibold))
                        Text(tr("It is free and always will be. A coffee keeps the updates coming.", "Ứng dụng miễn phí và sẽ luôn miễn phí. Một ly cà phê giúp các bản cập nhật tiếp tục ra đời."))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link(destination: URL(string: "https://jaycemouse.vercel.app/#support")!) {
                        Label(tr("Buy me a coffee", "Mời tôi một ly cà phê"), systemImage: "cup.and.saucer.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Acknowledgements", "Ghi nhận")).font(.system(size: 14, weight: .semibold))
                    Text(tr("JayceMouse is inspired by Mac Mouse Fix by Noah Nuebling. It is an independent implementation written from scratch and shares no code or assets with it.",
                             "JayceMouse lấy cảm hứng từ Mac Mouse Fix của Noah Nuebling. Đây là bản hiện thực độc lập, viết lại từ đầu và không dùng chung mã nguồn hay tài nguyên nào."))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Link(tr("Mac Mouse Fix on GitHub", "Mac Mouse Fix trên GitHub"), destination: URL(string: "https://github.com/noah-nuebling/mac-mouse-fix")!)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }
}
