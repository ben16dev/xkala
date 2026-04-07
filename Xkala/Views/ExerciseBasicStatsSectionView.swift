import SwiftUI

struct ExerciseBasicStatsSectionView: View {
    let snapshot: ExerciseBasicStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetricRow(title: "Sesiones", value: "\(snapshot.sessionsCount)")
            MetricRow(title: "Última vez", value: lastSessionLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var lastSessionLabel: String {
        guard let date = snapshot.lastSessionDate else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
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
