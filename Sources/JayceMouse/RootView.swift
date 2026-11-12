import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case overview, buttons, scroll, pointer, general, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return tr("Overview", "Tổng quan")
        case .buttons: return tr("Buttons", "Nút bấm")
        case .scroll: return tr("Scrolling", "Cuộn")
        case .pointer: return tr("Pointer", "Con trỏ")
        case .general: return tr("General", "Cài đặt chung")
        case .about: return tr("About", "Giới thiệu")
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "sparkles.rectangle.stack"
        case .buttons: return "computermouse.fill"
        case .scroll: return "arrow.up.and.down.text.horizontal"
        case .pointer: return "cursorarrow.motionlines"
        case .general: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("selectedPage") private var pageRaw = Page.overview.rawValue
    @Namespace private var navNamespace

    private var page: Page { Page(rawValue: pageRaw) ?? .overview }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ZStack {
                Backdrop()
                ScrollView {
                    Group {
                        switch page {
                        case .overview: OverviewView(navigate: { pageRaw = $0.rawValue })
                        case .buttons: ButtonsView()
                        case .scroll: ScrollSettingsView()
                        case .pointer: PointerView()
                        case .general: GeneralView()
                        case .about: AboutView()
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 46)
                    .padding(.bottom, 36)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                    .id(page)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
                .scrollIndicators(.hidden)
            }
        }
        .animation(.easeOut(duration: 0.22), value: page)
        .environment(\.locale, model.language.locale)
        .id(model.language)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.gradient))
                Text("JayceMouse")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .padding(.leading, 10)
            .padding(.top, 30)
            .padding(.bottom, 22)

            ForEach(Page.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { pageRaw = item.rawValue }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 20)
                        Text(item.title).font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(page == item ? Color.white : Color.primary.opacity(0.78))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background {
                        if page == item {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.gradient)
                                .matchedGeometryEffect(id: "nav", in: navNamespace)
                                .shadow(color: Theme.violet.opacity(0.4), radius: 8, y: 3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
            statusPill
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 18)
        .frame(width: 214)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1) }
    }

    private var statusPill: some View {
        let active = model.trusted && model.engineRunning
        return HStack(spacing: 8) {
            Circle()
                .fill(active ? Theme.mint : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: (active ? Theme.mint : Color.orange).opacity(0.8), radius: 4)
            Text(active ? tr("Active", "Đang hoạt động") : tr("Needs access", "Cần cấp quyền"))
                .font(.system(size: 12.5, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.07)))
    }
}
