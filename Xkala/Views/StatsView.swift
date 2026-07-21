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

                RecentRecordsSection(records: snapshot.recentRecords)
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

    private var metrics: [(label: String, value: String)] {
        var items: [(label: String, value: String)] = [
            ("Entrenos últimos 30 días", "\(snapshot.workoutsLast30Days)")
        ]
        if let load7 = snapshot.sessionLoadLast7Days {
            items.append(("Carga últimos 7 días", "\(load7)"))
        }
        if let load30 = snapshot.sessionLoadLast30Days {
            items.append(("Carga últimos 30 días", "\(load30)"))
        }
        if let lastMethod = snapshot.lastTrainingMethod {
            items.append(("Último objetivo", lastMethod.displayName))
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
                    RecentActivityMetricCell(label: metric.label, value: metric.value)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
    }
}

private struct RecentActivityMetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bloques y Travesías")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                ClimbingMetricRow(title: "Bloques realizados", value: "\(snapshot.blocksTotal)")
                ClimbingMetricRow(title: "Bloques con éxito", value: "\(snapshot.blocksSuccess)")
                if let blockRate = snapshot.blockSuccessRateText {
                    ClimbingMetricRow(title: "Tasa éxito bloques", value: blockRate)
                }
                ClimbingMetricRow(title: "Travesías realizadas", value: "\(snapshot.traversesTotal)")
                ClimbingMetricRow(title: "Travesías con éxito", value: "\(snapshot.traversesSuccess)")
                if let traverseRate = snapshot.traverseSuccessRateText {
                    ClimbingMetricRow(title: "Tasa éxito travesías", value: traverseRate)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
    }
}

private struct ClimbingMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct RecentRecordsSection: View {
    let records: [RecentRecordSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Récords recientes")
                .font(.headline)
                .foregroundStyle(.primary)

            if records.isEmpty {
                Text("Sin récords recientes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .xkalaCard()
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        WorkoutDetailView(workout: record.workout)
                    } label: {
                        RecentRecordCard(record: record)
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                }
            }
        }
    }
}

private struct RecentRecordCard: View {
    let record: RecentRecordSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(XkalaTheme.mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(record.bestMark)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(record.recordDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .xkalaCard()
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

            VStack(alignment: .leading, spacing: 12) {
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
            VStack(alignment: .trailing, spacing: 2) {
                Text(result)
                    .font(.body.weight(.medium))
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
