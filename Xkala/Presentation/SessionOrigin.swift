import SwiftUI

/// Origen visible de sesión para capa de presentación (sin persistencia).
enum SessionOrigin: String, CaseIterable {
    case gym
    case rock

    var displayName: String {
        switch self {
        case .gym: "Rocódromo"
        case .rock: "Roca"
        }
    }

    /// Mismos colores conceptuales que los iconos de sesión en ContentView y calendario.
    var chartColor: Color {
        switch self {
        case .gym: XkalaTheme.sessionTraining
        case .rock: XkalaTheme.sessionClimbing
        }
    }

    init(sessionType: WorkoutDay.SessionType) {
        switch sessionType {
        case .climbing: self = .rock
        case .training: self = .gym
        }
    }
}

extension WorkoutDay {
    var sessionOrigin: SessionOrigin {
        SessionOrigin(sessionType: sessionTypeEnum)
    }
}

extension InsightsBucket {
    func sessionCount(for origin: SessionOrigin) -> Int {
        switch origin {
        case .gym: trainingSessions
        case .rock: climbingSessions
        }
    }

    func timeSeconds(for origin: SessionOrigin) -> TimeInterval {
        switch origin {
        case .gym: trainingTypeTimeSeconds
        case .rock: climbingTypeTimeSeconds
        }
    }
}

extension SessionOrigin {
    /// Orígenes con al menos un valor > 0 en los buckets visibles.
    static func originsPresent(
        in buckets: [InsightsBucket],
        value: (InsightsBucket, SessionOrigin) -> Double
    ) -> [SessionOrigin] {
        allCases.filter { origin in
            buckets.contains { value($0, origin) > 0 }
        }
    }
}

/// Leyenda mínima para gráficos por origen de sesión.
struct SessionOriginChartLegend: View {
    let origins: [SessionOrigin]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(origins, id: \.rawValue) { origin in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(origin.chartColor)
                        .frame(width: 12, height: 12)
                    Text(origin.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
