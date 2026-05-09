import SwiftUI

struct ExerciseProgressSectionView: View {
    let snapshot: ExerciseProgressSnapshot
    /// Pie de métrica para bloque/travesía (menos intentos es mejor).
    let showLowerIsBetterFootnote: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !snapshot.hasEnoughData {
                Text(snapshot.comparisonText)
                    .foregroundStyle(.secondary)
            } else {
                MetricRow(title: "Mejor marca", value: snapshot.bestMarkText)
                MetricRow(title: "Última sesión", value: snapshot.lastSessionText)
                MetricRow(title: "Comparación", value: snapshot.comparisonText)
                if !snapshot.vsBestText.isEmpty {
                    Text(snapshot.vsBestText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if showLowerIsBetterFootnote {
                    Text("En bloque y travesía, menos intentos es mejor.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }

                Text("La evolución visual está en Perfil → Insights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

