import SwiftUI
import JayceMouseCore

struct ButtonsView: View {
    @EnvironmentObject var model: AppModel
    @State private var editing: EditorRequest?
    @State private var hoveredRow: UUID?

    private var grouped: [(button: Int, remaps: [Remap])] {
        Dictionary(grouping: model.config.remaps, by: \.button)
            .map { ($0.key, $0.value.sorted { order($0.gesture) < order($1.gesture) }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: tr("Buttons", "Nút bấm"), subtitle: tr("Give every extra button its own click, double click, hold, drag or scroll action.", "Gán cho mỗi nút phụ thao tác riêng khi nhấn, nhấn đúp, giữ, kéo hoặc cuộn.")) {
                HStack(spacing: 10) {
                    Menu {
                        Button(tr("3-button mouse", "Chuột 3 nút")) { model.apply(preset: DefaultRemaps.threeButtons) }
                        Button(tr("5-button mouse", "Chuột 5 nút")) { model.apply(preset: DefaultRemaps.fiveButtons) }
                        Divider()
                        Button(tr("Clear all", "Xóa tất cả"), role: .destructive) { model.apply(preset: []) }
                    } label: {
                        Label(tr("Presets", "Mẫu có sẵn"), systemImage: "square.stack.3d.up")
                    }
                    .menuStyle(.button)
                    .buttonStyle(GradientButtonStyle(prominent: false))
                    .fixedSize()

                    Button { editing = EditorRequest(remap: nil) } label: { Label(tr("Add Action", "Thêm thao tác"), systemImage: "plus") }
                        .buttonStyle(GradientButtonStyle())
                }
            }

            Card(padding: 24) {
                HStack(spacing: 28) {
                    MouseDiagram(pressed: model.pressedButtons, highlighted: nil)
                        .scaleEffect(0.8)
                        .frame(width: 170, height: 232)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Press any button to see it light up", "Nhấn bất kỳ nút nào để thấy nút đó sáng lên"))
                            .font(.system(size: 16, weight: .semibold))
                        Text(tr("Left and right clicks are never remapped on their own — use them as a modifier with a held side button if you want to extend them.",
                                 "Nút trái và nút phải không bao giờ bị gán lại riêng lẻ — nếu muốn mở rộng, hãy dùng chúng kết hợp khi đang giữ một nút bên."))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            ForEach(Array(model.pressedButtons.sorted()), id: \.self) { b in
                                Chip(symbol: "computermouse", title: buttonName(b), selected: true)
                            }
                        }
                        .frame(minHeight: 34)
                    }
                    Spacer(minLength: 0)
                }
            }

            if model.config.remaps.isEmpty {
                Card(padding: 36) {
                    VStack(spacing: 10) {
                        Image(systemName: "cursorarrow.click.badge.clock").font(.system(size: 34)).foregroundStyle(Theme.gradient)
                        Text(tr("No actions yet", "Chưa có thao tác nào")).font(.system(size: 16, weight: .semibold))
                        Text(tr("Add an action or start from a preset.", "Thêm một thao tác hoặc bắt đầu từ một mẫu có sẵn.")).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(grouped, id: \.button) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "computermouse.fill").foregroundStyle(Theme.violet)
                            Text(buttonName(group.button)).font(.system(size: 15, weight: .semibold))
                        }
                        .padding(.leading, 4)
                        Card(padding: 6) {
                            VStack(spacing: 0) {
                                ForEach(group.remaps) { remap in
                                    row(remap)
                                    if remap.id != group.remaps.last?.id {
                                        Divider().padding(.horizontal, 12)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { request in
            RemapEditor(initial: request.remap) { saved in
                model.save(remap: saved)
            }
            .environmentObject(model)
        }
    }

    private func row(_ remap: Remap) -> some View {
        HStack(spacing: 12) {
            Chip(symbol: remap.gesture.symbol, title: remap.gesture.title, tint: Theme.violet)
            if let m = remap.modifierButton {
                Text(tr("+ hold \(buttonName(m))", "+ giữ \(buttonName(m))")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if !remap.keyboardModifiers.isEmpty {
                Text("+ \(modifierSymbols(remap.keyboardModifiers))").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
            Chip(symbol: EffectCatalog.symbol(for: remap.effect), title: EffectCatalog.title(for: remap.effect), selected: true, tint: Theme.cyan)
            Spacer()
            HStack(spacing: 4) {
                Button { editing = EditorRequest(remap: remap) } label: { Image(systemName: "pencil") }
                Button { withAnimation { model.delete(remap: remap) } } label: { Image(systemName: "trash") }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .opacity(hoveredRow == remap.id ? 1 : 0.25)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(hoveredRow == remap.id ? 0.05 : 0)))
        .onHover { hoveredRow = $0 ? remap.id : (hoveredRow == remap.id ? nil : hoveredRow) }
    }
}

private func order(_ g: ButtonGesture) -> Int { ButtonGesture.allCases.firstIndex(of: g) ?? 0 }

func modifierSymbols(_ mask: ModifierMask) -> String {
    var s = ""
    if mask.contains(.control) { s += "⌃" }
    if mask.contains(.option) { s += "⌥" }
    if mask.contains(.shift) { s += "⇧" }
    if mask.contains(.command) { s += "⌘" }
    return s
}

struct EditorRequest: Identifiable {
    let id = UUID()
    let remap: Remap?
}

final class KeyRecorder {
    private var monitor: Any?

    func start(_ onKey: @escaping (KeyCombo) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var mods: ModifierMask = []
            let f = event.modifierFlags
            if f.contains(.shift) { mods.insert(.shift) }
            if f.contains(.control) { mods.insert(.control) }
            if f.contains(.option) { mods.insert(.option) }
            if f.contains(.command) { mods.insert(.command) }
            onKey(KeyCombo(keyCode: event.keyCode, modifiers: mods))
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit { stop() }
}

struct RemapEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let initial: Remap?
    let onSave: (Remap) -> Void

    @State private var button: Int?
    @State private var gesture: ButtonGesture = .click
    @State private var modifierButton: Int?
    @State private var keyboardModifiers: ModifierMask = []
    @State private var effect: Effect?
    @State private var capturing = false
    @State private var recording = false
    @State private var recorder = KeyRecorder()

    init(initial: Remap?, onSave: @escaping (Remap) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _button = State(initialValue: initial?.button)
        _gesture = State(initialValue: initial?.gesture ?? .click)
        _modifierButton = State(initialValue: initial?.modifierButton)
        _keyboardModifiers = State(initialValue: initial?.keyboardModifiers ?? [])
        _effect = State(initialValue: initial?.effect)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(initial == nil ? tr("New Action", "Thao tác mới") : tr("Edit Action", "Sửa thao tác"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    step("1", tr("Choose a button", "Chọn nút")) { buttonStep }
                    step("2", tr("Choose a trigger", "Chọn cách kích hoạt")) { gestureStep }
                    step("3", tr("Add modifiers (optional)", "Thêm phím bổ trợ (tùy chọn)")) { modifierStep }
                    step("4", tr("Choose an action", "Chọn thao tác")) { effectStep }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Divider()
            HStack {
                Button(tr("Cancel", "Hủy")) { dismiss() }.buttonStyle(GradientButtonStyle(prominent: false))
                Spacer()
                Button(tr("Save Action", "Lưu thao tác")) {
                    guard let button, let effect else { return }
                    onSave(Remap(id: initial?.id ?? UUID(), button: button, gesture: gesture, modifierButton: modifierButton, keyboardModifiers: keyboardModifiers, effect: effect))
                    dismiss()
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(button == nil || effect == nil)
                .opacity(button == nil || effect == nil ? 0.4 : 1)
            }
            .padding(20)
        }
        .frame(width: 620, height: 640)
        .background(Backdrop())
        .onDisappear {
            if capturing { model.cancelCapture() }
            recorder.stop()
        }
    }

    private func step<Content: View>(_ number: String, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(number)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.gradient))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            content()
        }
    }

    private var buttonStep: some View {
        Card(padding: 16) {
            HStack(spacing: 16) {
                MouseDiagram(highlighted: button ?? (capturing ? nil : nil))
                    .scaleEffect(0.42)
                    .frame(width: 90, height: 122)
                VStack(alignment: .leading, spacing: 8) {
                    if capturing {
                        Text(tr("Press a button on your mouse…", "Nhấn một nút trên chuột…"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.violet)
                        Text(model.trusted ? tr("Side, middle or extra buttons only.", "Chỉ nút bên, nút giữa hoặc nút phụ.") : tr("Grant Accessibility access first so JayceMouse can see your mouse.", "Hãy cấp quyền Trợ năng trước để JayceMouse nhận được chuột."))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    } else if let button {
                        Text(buttonName(button)).font(.system(size: 15, weight: .semibold))
                    } else {
                        Text(tr("No button selected", "Chưa chọn nút")).font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(capturing ? tr("Cancel", "Hủy") : (button == nil ? tr("Detect Button", "Nhận diện nút") : tr("Detect Again", "Nhận diện lại"))) { toggleCapture() }
                            .buttonStyle(GradientButtonStyle(prominent: !capturing))
                        Menu(tr("Pick manually", "Chọn thủ công")) {
                            ForEach([2, 3, 4, 5, 6, 7, 8], id: \.self) { b in
                                Button(buttonName(b)) { button = b }
                            }
                        }
                        .menuStyle(.button).fixedSize()
                    }
                }
                Spacer()
            }
        }
    }

    private func toggleCapture() {
        if capturing {
            model.cancelCapture()
            capturing = false
        } else {
            capturing = true
            model.beginCapture { picked in
                button = picked
                capturing = false
            }
        }
    }

    private var gestureStep: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(ButtonGesture.allCases, id: \.self) { g in
                Button {
                    gesture = g
                    if let e = effect, !EffectCatalog.groups(for: g).flatMap(\.effects).contains(e), !isCustomKeyboard(e, for: g) { effect = nil }
                } label: {
                    Chip(symbol: g.symbol, title: g.title, selected: gesture == g)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isCustomKeyboard(_ effect: Effect, for gesture: ButtonGesture) -> Bool {
        if case .keyboard = effect { return !gesture.isContinuous }
        return false
    }

    private var modifierStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(tr("Keyboard", "Bàn phím")).font(.system(size: 12.5)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                ForEach([(ModifierMask.control, "⌃ Control"), (.option, "⌥ Option"), (.shift, "⇧ Shift"), (.command, "⌘ Command")], id: \.0.rawValue) { mask, label in
                    Button {
                        if keyboardModifiers.contains(mask) { keyboardModifiers.remove(mask) } else { keyboardModifiers.insert(mask) }
                    } label: { Chip(symbol: "keyboard", title: label, selected: keyboardModifiers.contains(mask), tint: Theme.pink) }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Text(tr("Hold button", "Giữ nút")).font(.system(size: 12.5)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                Button { modifierButton = nil } label: { Chip(symbol: "xmark", title: tr("None", "Không"), selected: modifierButton == nil, tint: Theme.pink) }.buttonStyle(.plain)
                ForEach([2, 3, 4, 5, 6], id: \.self) { b in
                    if b != button {
                        Button { modifierButton = b } label: { Chip(symbol: "computermouse", title: "\(b + 1)", selected: modifierButton == b, tint: Theme.pink) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var effectStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(EffectCatalog.groups(for: gesture)) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(group.effects, id: \.self) { e in
                            Button { effect = e } label: {
                                Chip(symbol: EffectCatalog.symbol(for: e), title: EffectCatalog.title(for: e), selected: effect == e, tint: Theme.cyan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !gesture.isContinuous {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("KEYBOARD SHORTCUT", "PHÍM TẮT")).font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
                    HStack(spacing: 10) {
                        Button {
                            recording.toggle()
                            if recording {
                                recorder.start { combo in
                                    effect = .keyboard(combo)
                                    recording = false
                                    recorder.stop()
                                }
                            } else {
                                recorder.stop()
                            }
                        } label: {
                            Chip(symbol: "record.circle", title: recording ? tr("Press a shortcut…", "Nhấn tổ hợp phím…") : tr("Record shortcut", "Ghi phím tắt"), selected: recording, tint: Theme.pink)
                        }
                        .buttonStyle(.plain)
                        if case .keyboard(let combo)? = effect {
                            Chip(symbol: "keyboard", title: KeyNames.describe(combo), selected: true, tint: Theme.cyan)
                        }
                    }
                }
            }
        }
    }
}
