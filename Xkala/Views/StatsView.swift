import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]

    var body: some View {
        let snapshot = StatsCalculator.snapshot(from: workouts)

        ScrollView {
            VStack(spacing: 12) {
                StatCard(
                    title: "Entrenos totales",
                    value: "\(snapshot.totalWorkouts)",
                    systemImage: "calendar.badge.checkmark"
                )
                StatCard(
                    title: "Entrenos últimos 30 días",
                    value: "\(snapshot.workoutsLast30Days)",
                    systemImage: "clock.badge"
                )
                StatCard(
                    title: "Ejercicios completados",
                    value: "\(snapshot.totalCompletedExercises)",
                    systemImage: "checkmark.circle"
                )
                StatCard(
                    title: "Entrenos esta semana",
                    value: "\(snapshot.currentWeekWorkouts)",
                    systemImage: "calendar"
                )
                StatCard(
                    title: "Categoría favorita",
                    value: snapshot.favoriteCategory,
                    systemImage: "star.circle"
                )
                StatCard(
                    title: "Tiempo total entrenado",
                    value: DurationFormatting.formatSpanish(duration: snapshot.totalTrainingTime),
                    systemImage: "timer"
                )

                RecentRecordsSection(records: snapshot.recentRecords)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Estadísticas")
        .navigationBarTitleDisplayMode(.large)
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
