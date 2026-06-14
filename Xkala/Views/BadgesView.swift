import SwiftUI
import SwiftData

struct BadgesView: View {
    @Query(sort: \EarnedBadge.earnedAt, order: .reverse) private var allEarnedBadges: [EarnedBadge]

    private var earnedBadges: [EarnedBadge] {
        allEarnedBadges.filter { $0.sourceWorkout != nil }
    }

    var body: some View {
        Group {
            if earnedBadges.isEmpty {
                emptyState
            } else {
                earnedList
            }
        }
        .navigationTitle("Chapas")
        .navigationBarTitleDisplayMode(.inline)
        .xkalaScreenBackground(.calendar)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "medal")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Aún no tienes chapas")
                .font(.headline)

            Text("Completa sesiones y logros para desbloquear tu primera chapa de madera.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var earnedList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(earnedBadges, id: \.persistentModelID) { earned in
                    if let badge = BadgeDefinition.from(badgeId: earned.badgeId),
                       let workout = earned.sourceWorkout {
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            BadgeEarnedRow(badge: badge, earnedAt: earned.earnedAt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Fila de chapa conseguida

private struct BadgeEarnedRow: View {
    let badge: BadgeDefinition
    let earnedAt: Date

    private static let earnedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 16) {
            Image(badge.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(badge.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(badge.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(BadgeEarnedRow.earnedDateFormatter.string(from: earnedAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }
}

// MARK: - Modal al desbloquear

struct BadgeUnlockedView: View {
    let badge: BadgeDefinition
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(badge.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)

            Text("¡Chapa conseguida!")
                .font(.title2.weight(.bold))

            Text(badge.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(badge.unlockCongratulations)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Text("Genial")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(XkalaTheme.accent.opacity(0.95), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
