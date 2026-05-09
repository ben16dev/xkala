import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]

    @State private var selectedDate = Date()
    @State private var visibleMonth = Date()
    @State private var selectedWorkout: WorkoutDay?

    @State private var fabPressed = false
    private let fabHaptic = UIImpactFeedbackGenerator(style: .medium)

    @State private var isExportSharePresented = false
    @State private var exportShareURL: URL?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    WorkoutCalendarView(
                        visibleMonth: visibleMonth,
                        monthGridCells: daysInVisibleMonthWithLeadingBlanks,
                        selectedDate: selectedDate,
                        workouts: workouts,
                        onSelectDay: { day in
                            selectedDate = day
                            visibleMonth = day
                        },
                        onPreviousMonth: goToPreviousMonth,
                        onNextMonth: goToNextMonth
                    )
                    .padding(.vertical, 4)
                    .xkalaCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    List {
                        if workoutsForSelectedDay.isEmpty {
                            Section {
                            VStack(spacing: 10) {
                                Image(systemName: "figure.climbing")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.secondary)

                                Text("No hay sesiones este día")
                                    .font(.headline)

                                Text("Pulsa “Nuevo” para crear una sesión en la fecha seleccionada.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .xkalaCard()
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        } else {
                            Section {
                            ForEach(workoutsForSelectedDay) { workout in
                                Button {
                                    selectedWorkout = workout
                                } label: {
                                    SelectedDaySessionRow(
                                        workout: workout,
                                        title: displayTitle(for: workout),
                                        timeText: displayTime(for: workout)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .xkalaCard()
                                }
                                .buttonStyle(XkalaPressableRowStyle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteWorkout(workout)
                                    } label: {
                                        Label("Borrar", systemImage: "trash")
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                            .onDelete(perform: deleteWorkoutsForSelectedDay)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle("Xkala")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Perfil")

                        NavigationLink {
                            StatsView()
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                        .accessibilityLabel("Estadísticas")

                        Button {
                            exportJSONForSharing()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Exportar JSON")
                    }
                }
                .navigationDestination(item: $selectedWorkout) { workout in
                    WorkoutDetailView(workout: workout)
                }
                .sheet(isPresented: $isExportSharePresented, onDismiss: { exportShareURL = nil }) {
                    if let url = exportShareURL {
                        ActivityView(activityItems: [url])
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 72)
                }

                Button {
                    fabHaptic.impactOccurred()

                    withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                        fabPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            fabPressed = false
                        }
                    }

                    createNewWorkout()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Nuevo")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(XkalaTheme.accent.opacity(0.95))
                    )
                    .foregroundStyle(Color.white)
                    .scaleEffect(fabPressed ? 0.95 : 1.0)
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
                .accessibilityLabel("Nuevo entreno")
                .onAppear { fabHaptic.prepare() }
            }
        }
    }

    // MARK: - Calendario y día seleccionado

    /// Inicio del día seleccionado (alineado con `WorkoutDay.dayKey` / `startOfDay`).
    private var selectedDayKey: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

    /// Días (`startOfDay`) que tienen al menos una sesión.
    private var workoutDaysSet: Set<Date> {
        Set(workouts.map { Calendar.current.startOfDay(for: $0.date) })
    }

    /// Celdas del mes visible: `nil` = hueco; fecha = inicio de día.
    private var daysInVisibleMonthWithLeadingBlanks: [Date?] {
        XkalaMonthGrid.daysInVisibleMonthWithLeadingBlanks(visibleMonth: visibleMonth)
    }

    /// Sesiones del día seleccionado.
    /// Orden: **descendente** por hora de `date` (la más reciente arriba).
    private var workoutsForSelectedDay: [WorkoutDay] {
        workouts
            .filter { isSameDay($0.date, selectedDate) }
            .sorted { $0.date > $1.date }
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func hasWorkout(on date: Date) -> Bool {
        workoutDaysSet.contains(Calendar.current.startOfDay(for: date))
    }

    private func goToPreviousMonth() {
        visibleMonth = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
    }

    private func goToNextMonth() {
        visibleMonth = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
    }

    private func displayTitle(for workout: WorkoutDay) -> String {
        let trimmed = workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let derived = workout.categoriesBasedName, !derived.isEmpty { return derived }
        return "Sesión"
    }

    private func displayTime(for workout: WorkoutDay) -> String {
        workout.date.formatted(date: .omitted, time: .shortened)
    }

    /// Combina el **día** de `selectedDate` con la **hora actual** del reloj.
    private func makeDateForSelectedDayKeepingCurrentTime() -> Date {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: dayStart)
        let timeParts = cal.dateComponents([.hour, .minute, .second], from: now)
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        components.second = timeParts.second
        return cal.date(from: components) ?? dayStart
    }

    private func createNewWorkout() {
        let w = WorkoutDay(
            date: makeDateForSelectedDayKeepingCurrentTime(),
            name: "",
            notes: "",
            entries: []
        )
        context.insert(w)
        try? context.save()
    }

    private func deleteWorkout(_ workout: WorkoutDay) {
        if selectedWorkout?.id == workout.id {
            selectedWorkout = nil
        }
        context.delete(workout)
        try? context.save()
    }

    private func deleteWorkoutsForSelectedDay(_ indexSet: IndexSet) {
        for idx in indexSet {
            let w = workoutsForSelectedDay[idx]
            deleteWorkout(w)
        }
    }

    private func exportJSONForSharing() {
        do {
            exportShareURL = try ExportService.exportTemporaryJSONFile(context: context)
            isExportSharePresented = true
        } catch {
            print(error)
        }
    }
}

// MARK: - Fila sesión del día

private struct SelectedDaySessionRow: View {
    let workout: WorkoutDay
    let title: String
    let timeText: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(timeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                Image(workout.sessionIcon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(
                        workout.sessionTypeEnum == .climbing
                            ? XkalaTheme.sessionClimbing
                            : XkalaTheme.sessionTraining
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
    }
}

// MARK: - ButtonStyle (pop + haptic sin romper swipe)

private struct XkalaPressableRowStyle: ButtonStyle {
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { haptic.impactOccurred() }
            }
            .onAppear { haptic.prepare() }
    }
}
