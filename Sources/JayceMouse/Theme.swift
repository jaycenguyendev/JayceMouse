import SwiftUI

enum Theme {
    static let violet = Color(red: 0.45, green: 0.36, blue: 0.98)
    static let cyan = Color(red: 0.10, green: 0.74, blue: 0.92)
    static let pink = Color(red: 0.98, green: 0.36, blue: 0.62)
    static let mint = Color(red: 0.20, green: 0.84, blue: 0.62)

    static var gradient: LinearGradient {
        LinearGradient(colors: [violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var warmGradient: LinearGradient {
        LinearGradient(colors: [pink, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Theme.violet.opacity(0.28), .clear], center: .topTrailing, startRadius: 20, endRadius: 520)
            RadialGradient(colors: [Theme.cyan.opacity(0.16), .clear], center: .bottomLeading, startRadius: 20, endRadius: 560)
        }
        .ignoresSafeArea()
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
            )
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tr(title))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(tr(subtitle))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct GradientButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(prominent ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct Chip: View {
    let symbol: String
    let title: String
    var selected = false
    var tint: Color = Theme.violet

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(tr(title)).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.primary.opacity(0.07)))
        )
        .overlay(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(selected ? 0 : 0.06)))
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

struct SegmentedPills<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = option }
                } label: {
                    Text(tr(title(option)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? Color.white : Color.primary.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == option {
                                Capsule(style: .continuous).fill(Theme.gradient).matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.07)))
    }
}

struct SettingToggleRow: View {
    let symbol: String
    let title: String
    var detail: String?
    @Binding var isOn: Bool
    var tint: Color = Theme.violet

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(title)).font(.system(size: 14, weight: .semibold))
                if let detail {
                    Text(tr(detail)).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).tint(tint)
        }
        .padding(.vertical, 4)
    }
}

struct MouseDiagram: View {
    var pressed: Set<Int> = []
    var highlighted: Int?
    var pulse = 0

    private func lit(_ button: Int) -> Bool { pressed.contains(button) || highlighted == button }

    var body: some View {
        ZStack {
            body(width: 168, height: 262)
        }
        .frame(width: 210, height: 290)
    }

    private func body(width: CGFloat, height: CGFloat) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: width * 0.5, bottomLeadingRadius: width * 0.46,
            bottomTrailingRadius: width * 0.46, topTrailingRadius: width * 0.5, style: .continuous
        )
        return ZStack {
            shape
                .fill(LinearGradient(colors: [Color.primary.opacity(0.16), Color.primary.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.18), lineWidth: 1.5))
                .shadow(color: Theme.violet.opacity(0.25), radius: 24, y: 12)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(lit(0) ? Theme.violet.opacity(0.65) : .clear)
                    Rectangle().fill(lit(1) ? Theme.cyan.opacity(0.65) : .clear)
                }
                .frame(height: height * 0.4)
                Spacer()
            }
            .clipShape(shape)
            .animation(.easeOut(duration: 0.12), value: pressed)

            VStack(spacing: 0) {
                Capsule().fill(Color.primary.opacity(0.2)).frame(width: 1.5, height: height * 0.4)
                Spacer()
            }
            Rectangle().fill(Color.primary.opacity(0.2)).frame(height: 1.5).offset(y: -height * 0.1)

            Capsule()
                .fill(lit(2) ? AnyShapeStyle(Theme.warmGradient) : AnyShapeStyle(Color.primary.opacity(0.28)))
                .frame(width: 16, height: 44)
                .offset(y: -height * 0.28)
                .scaleEffect(lit(2) ? 1.12 : 1)
                .shadow(color: lit(2) ? Theme.pink.opacity(0.8) : .clear, radius: 10)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: highlighted)

            sideButton(3).offset(x: -width * 0.5 + 8, y: -height * 0.02)
            sideButton(4).offset(x: -width * 0.5 + 8, y: height * 0.14)
        }
        .frame(width: width, height: height)
    }

    private func sideButton(_ index: Int) -> some View {
        Capsule()
            .fill(lit(index) ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.primary.opacity(0.22)))
            .frame(width: 12, height: 34)
            .shadow(color: lit(index) ? Theme.cyan.opacity(0.8) : .clear, radius: 8)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.12), value: highlighted)
    }
}
