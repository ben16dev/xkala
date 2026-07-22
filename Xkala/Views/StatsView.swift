import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]

    var body: some View {
        let snapshot = StatsCalculator.snapshot(from: workouts)
        let testStateSnapshot = CurrentTestStateCalculator.snapshot(from: workouts)

        ScrollView {
            VStack(spacing: 12) {
                if testStateSnapshot.hasData {
                    CurrentTestStateSection(snapshot: testStateSnapshot)
                }

                RecentActivitySection(snapshot: snapshot)

                HistoryStatsSection(snapshot: snapshot)

                if let climbing = snapshot.climbingStats {
                    ClimbingStatsSection(snapshot: climbing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .xkalaScreenBackground(.calendar)
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct RecentActivitySection: View {
    let snapshot: GlobalStatsSnapshot

    private var metrics: [(label: String, value: String, comparison: String?, comparisonColor: Color?)] {
        var items: [(label: String, value: String, comparison: String?, comparisonColor: Color?)] = [
            (
                "Entrenos 30 días",
                "\(snapshot.workoutsLast30Days)",
                Self.formattedDelta(snapshot.workoutsLast30DaysDelta),
                Self.deltaColor(snapshot.workoutsLast30DaysDelta)
            )
        ]
        if let load7 = snapshot.sessionLoadLast7Days {
            items.append(("Carga últimos 7 días", "\(load7)", nil, nil))
        }
        if let load30 = snapshot.sessionLoadLast30Days {
            let delta = snapshot.sessionLoadLast30DaysDelta ?? 0
            items.append((
                "Carga últimos 30 días",
                "\(load30)",
                Self.formattedDelta(delta),
                Self.deltaColor(delta)
            ))
        }
        if let lastMethod = snapshot.lastTrainingMethod {
            items.append(("Último objetivo", lastMethod.displayName, nil, nil))
        }
        return items
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actividad reciente")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    RecentActivityMetricCell(
                        label: metric.label,
                        value: metric.value,
                        comparison: metric.comparison,
                        comparisonColor: metric.comparisonColor
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
    }

    private static func formattedDelta(_ delta: Int) -> String {
        if delta > 0 { return "↑ +\(delta)" }
        if delta < 0 { return "↓ \(delta)" }
        return "= 0"
    }

    private static func deltaColor(_ delta: Int) -> Color {
        if delta > 0 { return .green }
        if delta < 0 { return .red }
        return .yellow
    }
}

private struct RecentActivityMetricCell: View {
    let label: String
    let value: String
    var comparison: String? = nil
    var comparisonColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let comparison {
                    Text(comparison)
                        .font(.subheadline)
                        .foregroundStyle(comparisonColor ?? .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryStatsSection: View {
    let snapshot: GlobalStatsSnapshot

    private var metrics: [(label: String, value: String)] {
        [
            ("Entrenos totales", "\(snapshot.totalWorkouts)"),
            ("Tiempo total entrenado", DurationFormatting.formatSpanish(duration: snapshot.totalTrainingTime)),
            ("Ejercicios totales", "\(snapshot.totalCompletedExercises)")
        ]
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Historial")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    RecentActivityMetricCell(label: metric.label, value: metric.value)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
    }
}

private struct ClimbingStatsSection: View {
    let snapshot: ClimbingStatsSnapshot

    private var showsBlocks: Bool { snapshot.blocksTotal > 0 }
    private var showsTraverses: Bool { snapshot.traversesTotal > 0 }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .topLeading),
        GridItem(.flexible(), spacing: 12, alignment: .topLeading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bloques y Travesías")
                .font(.headline)
                .foregroundStyle(.primary)

            Group {
                if showsBlocks && showsTraverses {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        blocksSummary
                        traversesSummary
                    }
                } else if showsBlocks {
                    blocksSummary
                } else if showsTraverses {
                    traversesSummary
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
    }

    private var blocksSummary: some View {
        ClimbingDisciplineSummary(
            title: "Bloques",
            totalLabel: "Bloques realizados",
            totalValue: "\(snapshot.blocksTotal)",
            successLabel: "Bloques con éxito",
            successValue: "\(snapshot.blocksSuccess)",
            rateLabel: "Tasa éxito bloques",
            rateValue: snapshot.blockSuccessRateText
        )
    }

    private var traversesSummary: some View {
        ClimbingDisciplineSummary(
            title: "Travesías",
            totalLabel: "Travesías realizadas",
            totalValue: "\(snapshot.traversesTotal)",
            successLabel: "Travesías con éxito",
            successValue: "\(snapshot.traversesSuccess)",
            rateLabel: "Tasa éxito travesías",
            rateValue: snapshot.traverseSuccessRateText
        )
    }
}

private struct ClimbingDisciplineSummary: View {
    let title: String
    let totalLabel: String
    let totalValue: String
    let successLabel: String
    let successValue: String
    let rateLabel: String
    let rateValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            ClimbingDisciplineMetric(label: totalLabel, value: totalValue)
            ClimbingDisciplineMetric(label: successLabel, value: successValue)
            if let rateValue {
                ClimbingDisciplineMetric(label: rateLabel, value: rateValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ClimbingDisciplineMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(XkalaTheme.mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }
}

private struct CurrentTestStateSection: View {
    let snapshot: CurrentTestStateSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estado actual")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(snapshot.orderedCapacities, id: \.self) { capacity in
                    if let result = snapshot.resultsByCapacity[capacity] {
                        TestCapacityRow(
                            capacity: capacity.displayName,
                            result: result.resultText,
                            age: result.ageText()
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
        .padding(.bottom, 4)
    }
}

private struct TestCapacityRow: View {
    let capacity: String
    let result: String
    let age: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(capacity)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(result)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                Text(age)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
