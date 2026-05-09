import SwiftUI

enum XkalaTheme {
    static let bg = Color(hex: "#0F2A28")
    static let card = Color(hex: "#163634")
    static let stroke = Color.white.opacity(0.06)
    static let accent = Color(hex: "#7E337C")
    static let mint = Color(hex: "#71B5A0")

    /// Barras “Sesiones” en insights (contraste fuerte sobre verde oscuro; evita confusión con `accent`).
    static let chartSessions = Color(hex: "#FF9A5C")

    /// Turquesa: icono de entrenamiento/rocódromo (iconClimbingShoes)
    static let sessionTraining = Color(hex: "#24FFF8")
    /// Amarillo: icono de roca/montaña (iconMountain)
    static let sessionClimbing = Color(hex: "#FFFF24")
}

struct XkalaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(XkalaTheme.card)
                    .shadow(radius: 18, y: 10)
                    .shadow(radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(XkalaTheme.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func xkalaCard() -> some View { modifier(XkalaCard()) }
    func xkalaScreenBackground() -> some View {
        background(XkalaTheme.bg.ignoresSafeArea())
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
