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
                VStack(spacing: 0) {
                    homeHeader

                    calendarSection

                    selectedDaySessionsList
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .xkalaScreenBackground(.calendar)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
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

                newWorkoutFAB
                    .padding(.trailing, 18)
                    .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            NavigationLink {
                ProfileView()
            } label: {
                AvatarView(size: 84, mood: AvatarMoodCalculator.mood(for: workouts))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                    )
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir perfil")

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 12) {
                Text("XKALA")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)

                HStack(spacing: 10) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        XkalaToolbarIconButton(systemImage: "chart.bar.xaxis")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Estadísticas")

                    NavigationLink {
                        XkalaProgressView()
                    } label: {
                        XkalaToolbarIconButton(systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Progreso")

                    NavigationLink {
                        ImportView()
                    } label: {
                        XkalaToolbarIconButton(systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Importar CSV")

                    Button {
                        exportJSONForSharing()
                    } label: {
                        XkalaToolbarIconButton(systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exportar JSON")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Calendario (fijo, sin scroll)

    private var calendarSection: some View {
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
        .padding(.bottom, 10)
    }

    // MARK: - Lista del día seleccionado (única zona scrollable; List para swipeActions)

    private var selectedDaySessionsList: some View {
        List {
            if workoutsForSelectedDay.isEmpty {
                emptySelectedDayRow
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 24, trailing: 16))
            } else {
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
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteWorkout(workout)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteWorkout(workout)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptySelectedDayRow: some View {
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
    }

    // MARK: - FAB

    private var newWorkoutFAB: some View {
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
            .shadow(color: XkalaTheme.cardPrimaryShadow, radius: 18, x: 0, y: 10)
            .shadow(color: XkalaTheme.cardSecondaryShadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Crear sesión de rocódromo")
        .onAppear { fabHaptic.prepare() }
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
        return workout.sessionTypeEnum == .climbing ? "Sesión de roca" : "Sesión Rocódromo"
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
