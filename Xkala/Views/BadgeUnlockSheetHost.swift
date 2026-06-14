import SwiftUI

/// Presenta el popup de chapa desbloqueada sobre cualquier pantalla (incl. detalle de sesión).
struct BadgeUnlockSheetHost: ViewModifier {
    @ObservedObject var coordinator: BadgeUnlockCoordinator

    func body(content: Content) -> some View {
        content.sheet(item: $coordinator.pendingUnlock) { unlock in
            BadgeUnlockedView(badge: unlock.badge) {
                coordinator.dismissCurrent()
            }
        }
    }
}

extension View {
    func badgeUnlockSheetHost(coordinator: BadgeUnlockCoordinator) -> some View {
        modifier(BadgeUnlockSheetHost(coordinator: coordinator))
    }
}
