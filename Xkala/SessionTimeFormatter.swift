import Foundation

/// Formateo y parseo de tiempos de sesión (WorkoutDay).
///
/// Separado de DurationFormatting (texto legible en español)
/// y de SetRecord.seconds (métrica de ejercicios).
enum SessionTimeFormatter {

    /// Formato para timer activo: HH:MM:SS
    /// Ejemplo: 00:12:34
    static func formatActive(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// Formato para duración final: HH:MM
    /// Ejemplo: 01:30
    static func formatFinal(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Calcula los segundos transcurridos desde startedAt hasta endedAt (o Date() si sigue en curso).
    static func seconds(from workout: WorkoutDay) -> Int {
        guard let start = workout.startedAt else { return 0 }
        let end = workout.endedAt ?? Date()
        return max(0, Int(end.timeIntervalSince(start)))
    }

    /// Parsea texto "HH:MM" (ej: "01:30") en segundos totales.
    /// - Devuelve `nil` si el formato no es válido.
    /// - Los minutos deben estar en 0-59.
    static func parseInput(_ text: String) -> Int? {
        let parts = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count == 2,
              let first = Int(parts[0]),
              let second = Int(parts[1]),
              first >= 0, second >= 0, second < 60
        else { return nil }

        return first * 3600 + second * 60
    }
}
