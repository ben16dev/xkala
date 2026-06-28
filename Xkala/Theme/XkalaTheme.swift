import SwiftUI

enum XkalaTheme {
    static let bg = Color(hex: "#0F2A28")
    static let card = Color(hex: "#163634")
    static let stroke = Color.white.opacity(0.06)
    static let accent = Color(hex: "#7E337C")
    static let mint = Color(hex: "#71B5A0")
    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let cardPrimaryShadow = Color.black.opacity(0.35)
    static let cardSecondaryShadow = Color.black.opacity(0.20)
    static let toolbarIconSize: CGFloat = 42
    static let toolbarIconStroke = Color.white.opacity(0.10)

    /// Barras “Sesiones” en insights (contraste fuerte sobre verde oscuro; evita confusión con `accent`).
    static let chartSessions = Color(hex: "#FF9A5C")
    /// Línea de tiempo en insights (turquesa claro sobre fondo oscuro).
    static let chartTimeLine = Color(hex: "#8FD4C8")

    /// Turquesa: icono de entrenamiento (iconClimbingShoes)
    static let sessionTraining = Color(hex: "#24FFF8")
    /// Amarillo: icono de cuerda (iconRope)
    static let sessionClimbing = Color(hex: "#FFFF24")

    static let calendarScreenBackground = LinearGradient(
        colors: [
            bg,
            card.opacity(0.72),
            bg
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum XkalaScreenBackgroundStyle {
    case solid
    case calendar
}

struct XkalaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(XkalaTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: XkalaTheme.cardCornerRadius, style: .continuous)
                    .fill(XkalaTheme.card)
                    .shadow(color: XkalaTheme.cardPrimaryShadow, radius: 18, x: 0, y: 10)
                    .shadow(color: XkalaTheme.cardSecondaryShadow, radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: XkalaTheme.cardCornerRadius, style: .continuous)
                    .stroke(XkalaTheme.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: XkalaTheme.cardCornerRadius, style: .continuous))
    }
}

extension View {
    func xkalaCard() -> some View { modifier(XkalaCard()) }
    @ViewBuilder
    func xkalaScreenBackground(_ style: XkalaScreenBackgroundStyle = .solid) -> some View {
        switch style {
        case .solid:
            background(XkalaTheme.bg.ignoresSafeArea())
        case .calendar:
            background(XkalaTheme.calendarScreenBackground.ignoresSafeArea())
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 255, (int >> 8) & 255, int & 255)

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct XkalaActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))

            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(XkalaTheme.accent.opacity(0.95))
        )
        .foregroundStyle(.white)
    }
}

struct XkalaToolbarIconButton: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(width: XkalaTheme.toolbarIconSize, height: XkalaTheme.toolbarIconSize)
            .background(
                Circle()
                    .fill(.thinMaterial)
            )
            .overlay(
                Circle()
                    .stroke(XkalaTheme.toolbarIconStroke, lineWidth: 1)
            )
    }
}

extension ToolbarContent {
    /// Evita la cápsula/fondo compartido del sistema en la barra de navegación.
    func xkalaIndependentToolbarIcon() -> some ToolbarContent {
        sharedBackgroundVisibility(.hidden)
    }
}
