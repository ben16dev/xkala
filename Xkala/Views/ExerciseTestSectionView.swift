import SwiftUI

struct ExerciseTestSectionView: View {
    let exercise: Exercise
    let snapshot: ExerciseTestSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capacidad evaluada: \(exercise.testCapacity.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if !snapshot.hasData {
                Text("Sin registros todavía")
                    .foregroundStyle(.secondary)
            } else {
                TestMetricRow(title: "Último test", value: snapshot.lastResultText)
                TestMetricRow(title: "Mejor marca", value: snapshot.bestResultText)
                if !snapshot.deltaText.isEmpty {
                    HStack(spacing: 12) {
                        Text("Evolución")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(snapshot.deltaText)
                            .foregroundStyle(deltaColor)
                            .fontWeight(snapshot.isImproving ? .semibold : .regular)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var deltaColor: Color {
        if snapshot.deltaText.hasPrefix("↑") { return XkalaTheme.mint }
        if snapshot.deltaText.hasPrefix("↓") { return .red.opacity(0.75) }
        return .secondary
    }
}

private struct TestMetricRow: View {
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
