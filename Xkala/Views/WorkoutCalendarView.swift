import SwiftUI
import SwiftData

// MARK: - Grid (compartido con ContentView para `daysInVisibleMonthWithLeadingBlanks`)

enum XkalaMonthGrid {
    /// Calendario para rejilla: mismo huso que el sistema, semana empieza en lunes.
    static var calendarForGrid: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    /// Celdas del mes visible: `nil` = hueco antes/después del mes; `Date` = inicio de ese día en `calendarForGrid`.
    static func daysInVisibleMonthWithLeadingBlanks(visibleMonth: Date) -> [Date?] {
        let calendar = calendarForGrid
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let startOfMonth = interval.start
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        let firstWeekday = calendar.firstWeekday
        let startWeekday = calendar.component(.weekday, from: startOfMonth)
        let offset = (startWeekday - firstWeekday + 7) % 7
        let daysInMonth = range.count

        let totalCells = offset + daysInMonth
        let numberOfRows = Int(ceil(Double(totalCells) / 7.0))
        let cellCount = numberOfRows * 7

        var cells: [Date?] = []
        cells.reserveCapacity(cellCount)

        for index in 0..<cellCount {
            if index < offset || index >= offset + daysInMonth {
                cells.append(nil)
            } else {
                let day = index - offset + 1
                var comps = calendar.dateComponents([.year, .month], from: startOfMonth)
                comps.day = day
                let date = calendar.date(from: comps)!
                cells.append(calendar.startOfDay(for: date))
            }
        }

        return cells
    }
}

// MARK: - Clasificación conservadora rocódromo / roca (solo lectura de datos existentes)

private enum CalendarSessionVenueKind {
    /// Sesión en roca (exterior).
    case outdoor
    /// Rocódromo / indoor / no clasificada como roca.
    case indoor
}

private enum XkalaCalendarSessionClassifier {
    private static let foldingLocale = Locale(identifier: "es_ES")

    private static func normalizeText(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: foldingLocale)
    }

    /// Palabras clave de roca; se normalizan igual que el blob (`climbIdentifier` excluido a propósito).
    private static let outdoorNeedles: [String] = Array(
        Set(
            [
                "roca", "outdoor", "montana", "montaña", "segovia",
                "fuertiduena", "fuentidueña", "fuenti", "peñalara", "pedriza",
            ].map { normalizeText($0) }
        )
    )
    /// Señales explícitas de rocódromo/indoor.
    private static let indoorNeedles: [String] = Array(
        Set(
            [
                "rocodromo", "rocódromo", "indoor", "gym", "entreno", "training",
            ].map { normalizeText($0) }
        )
    )

    private static func normalizedBlob(parts: [String]) -> String {
        normalizeText(parts.joined(separator: " "))
    }

    private static func workoutTextParts(_ workout: WorkoutDay) -> [String] {
        var parts: [String] = [workout.name, workout.notes]
        if let derived = workout.categoriesBasedName {
            parts.append(derived)
        }
        return parts
    }

    private static func entryTextParts(_ entry: WorkoutEntry) -> [String] {
        var parts: [String] = [
            entry.exercise.name,
            entry.exercise.category,
            entry.exercise.notes,
            entry.entryNotes,
        ]
        if let kind = entry.climbKind {
            parts.append(kind)
        }
        return parts
    }

    /// Prioriza `sessionType` de la sesión; usa texto solo como fallback para datos legacy.
    private static func workoutSignals(_ workout: WorkoutDay) -> (hasOutdoor: Bool, hasIndoor: Bool) {
        let sessionTypeBlob = normalizeText(workout.sessionType)
        if sessionTypeBlob.contains("climbing") || sessionTypeBlob.contains("roca") {
            return (true, false)
        }
        if sessionTypeBlob.contains("training") || sessionTypeBlob.contains("entreno") {
            return (false, true)
        }
        if workout.sessionType == WorkoutDay.SessionType.climbing.rawValue {
            return (true, false)
        }
        if workout.sessionType == WorkoutDay.SessionType.training.rawValue {
            return (false, true)
        }

        let workoutBlob = normalizedBlob(parts: workoutTextParts(workout))
        var hasOutdoor = containsAnyNeedle(workoutBlob, needles: outdoorNeedles)
        var hasIndoor = containsAnyNeedle(workoutBlob, needles: indoorNeedles)

        for entry in workout.entries {
            let entryBlob = normalizedBlob(parts: entryTextParts(entry))
            if containsAnyNeedle(entryBlob, needles: outdoorNeedles) {
                hasOutdoor = true
            }
            if containsAnyNeedle(entryBlob, needles: indoorNeedles) {
                hasIndoor = true
            }
        }

        // Regla conservadora: cualquier sesión no clasificada como roca cuenta como indoor.
        if !hasOutdoor {
            hasIndoor = true
        }

        return (hasOutdoor, hasIndoor)
    }

    private static func containsAnyNeedle(_ blob: String, needles: [String]) -> Bool {
        needles.contains { blob.contains($0) }
    }

    /// Agrega flags de **todas** las sesiones cuyo día calendario coincide con `dayKey`.
    static func venueFlags(forDayKey dayKey: Date, workouts: [WorkoutDay]) -> (hasOutdoor: Bool, hasIndoor: Bool) {
        let cal = Calendar.current
        var hasOutdoor = false
        var hasIndoor = false
        for w in workouts where cal.isDate(w.date, inSameDayAs: dayKey) {
            let signals = workoutSignals(w)
            hasOutdoor = hasOutdoor || signals.hasOutdoor
            hasIndoor = hasIndoor || signals.hasIndoor
        }
        return (hasOutdoor, hasIndoor)
    }
}

// MARK: - Vista mensual

struct WorkoutCalendarView: View {
    let visibleMonth: Date
    /// Celdas del mes (`nil` = hueco); debe corresponder a `visibleMonth` (p. ej. `daysInVisibleMonthWithLeadingBlanks` en `ContentView`).
    let monthGridCells: [Date?]
    let selectedDate: Date
    /// Todas las sesiones (misma fuente que la lista del día); se usa para iconos por tipo sin tocar el modelo.
    let workouts: [WorkoutDay]
    let onSelectDay: (Date) -> Void
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    private var gridCalendar: Calendar { XkalaMonthGrid.calendarForGrid }

    private var monthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.calendar = gridCalendar
        df.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return df.string(from: visibleMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = gridCalendar.shortWeekdaySymbols
        let firstIndex = gridCalendar.firstWeekday - 1
        return (0..<symbols.count).map { offset in
            symbols[(firstIndex + offset) % symbols.count]
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }

    var body: some View {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let selectedStart = Calendar.current.startOfDay(for: selectedDate)

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes anterior")

                Text(monthTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes siguiente")
            }

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(monthGridCells.indices, id: \.self) { index in
                    let cellDate = monthGridCells[index]
                    WorkoutCalendarDayCell(
                        cellDate: cellDate,
                        todayStart: todayStart,
                        selectedStart: selectedStart,
                        workouts: workouts,
                        onSelect: onSelectDay
                    )
                }
            }
        }
        .accessibilityLabel(monthTitle)
    }
}

// MARK: - Celda

private struct WorkoutCalendarDayCell: View {
    let cellDate: Date?
    let todayStart: Date
    let selectedStart: Date
    let workouts: [WorkoutDay]
    let onSelect: (Date) -> Void

    private var dayKey: Date? {
        guard let cellDate else { return nil }
        return Calendar.current.startOfDay(for: cellDate)
    }

    private var venueFlags: (hasOutdoor: Bool, hasIndoor: Bool) {
        guard let dayKey else { return (false, false) }
        return XkalaCalendarSessionClassifier.venueFlags(forDayKey: dayKey, workouts: workouts)
    }

    private var hasWorkout: Bool {
        let f = venueFlags
        return f.hasOutdoor || f.hasIndoor
    }

    private var isSelected: Bool {
        guard let dayKey else { return false }
        return dayKey == selectedStart
    }

    private var isToday: Bool {
        guard let dayKey else { return false }
        return dayKey == todayStart
    }

    private var dayNumberText: String {
        guard let cellDate else { return "" }
        return String(Calendar.current.component(.day, from: cellDate))
    }

    private static let sessionIconFrame: CGFloat = 16

    @ViewBuilder
    private var sessionTypeIcons: some View {
        let f = venueFlags
        if f.hasOutdoor && f.hasIndoor {
            HStack(spacing: 2) {
                calendarSessionIcon("iconClimbingShoes", color: XkalaTheme.sessionTraining)
                calendarSessionIcon("iconMountain", color: XkalaTheme.sessionClimbing)
            }
        } else if f.hasOutdoor {
            calendarSessionIcon("iconMountain", color: XkalaTheme.sessionClimbing)
        } else if f.hasIndoor {
            calendarSessionIcon("iconClimbingShoes", color: XkalaTheme.sessionTraining)
        }
    }

    /// Template + color explícito para no heredar el tinte del `Button` sobre el icono.
    private func calendarSessionIcon(_ assetName: String, color: Color) -> some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.sessionIconFrame, height: Self.sessionIconFrame)
            .foregroundStyle(color)
    }

    /// Borde discreto para hoy; si el día está seleccionado, solo el resalte de selección.
    private var borderColor: Color {
        if isSelected { return XkalaTheme.accent.opacity(0.95) }
        if isToday { return Color.secondary.opacity(0.55) }
        return Color.clear
    }

    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        if isToday { return 1 }
        return 0
    }

    var body: some View {
        Group {
            if cellDate == nil {
                Color.clear
                    .frame(minHeight: 48)
            } else {
                Button {
                    guard let dayKey else { return }
                    onSelect(dayKey)
                } label: {
                    VStack(spacing: 3) {
                        Text(dayNumberText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        if hasWorkout {
                            sessionTypeIcons
                        } else {
                            Color.clear.frame(height: Self.sessionIconFrame)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? XkalaTheme.accent.opacity(0.22) : Color.clear)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
