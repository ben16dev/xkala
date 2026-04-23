import Foundation

/// Plantillas "uniformes":
/// - "series" = número de SetRecord
/// - reps/seconds/loadKg iguales para todas las series
/// - intensity se define en WorkoutEntry (no en SetRecord)
enum SetTemplates {

    struct EntryTemplate {
        let intensity: Int
        let sets: [SetRecord]
    }

    /// Devuelve intensidad + sets por defecto para un Exercise.
    static func defaultEntryTemplate(for exercise: Exercise) -> EntryTemplate {
        let name = normalizeText(exercise.name)
        let category = normalizeText(exercise.category)
        let mode = normalizeMode(exercise.mode)

        // 1) TIEMPO (seconds)
        if mode == "seconds" {
            // Plancha / core en tiempo
            if name.contains("plancha") || category.contains("core") {
                return EntryTemplate(
                    intensity: 1,
                    sets: makeSecondsSets(series: 3, seconds: 40, loadKg: nil)
                )
            }

            // Suspensiones intermitentes (con “carga” negativa tipo -10 kg)
            // Nota: aquí asumimos un protocolo base de 10s si no hay otro dato.
            if name.contains("suspension") || name.contains("suspensión") {
                if exercise.isIntermittentHangboardExercise {
                    let load = exercise.loadAllowed ? -10.0 : nil
                    return EntryTemplate(
                        intensity: 1,
                        sets: makeSecondsSets(series: 3, seconds: 10, loadKg: load)
                    )
                }

                // Suspensiones genéricas (sin intermitente)
                let load = exercise.loadAllowed ? 0.0 : nil
                return EntryTemplate(
                    intensity: 1,
                    sets: makeSecondsSets(series: 3, seconds: 10, loadKg: load)
                )
            }

            // Default tiempo
            let load = exercise.loadAllowed ? 0.0 : nil
            return EntryTemplate(
                intensity: 1,
                sets: makeSecondsSets(series: 3, seconds: 20, loadKg: load)
            )
        }

        // 2) REPS (reps)
        // Vuelta 1: "número de vueltas" = 2 (no “series”)
        // Lo representamos como 1 set con reps = nº vueltas
        if exercise.isVueltaStyleExercise {
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 1, reps: 2, loadKg: nil)
            )
        }

        // Campus básico: "repeticiones" = 4 (sin énfasis en series)
        // Lo representamos como 1 set con reps = 4 (ajústalo si quieres 3 series)
        if category.contains("campus") || name.contains("campus") {
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 1, reps: 4, loadKg: nil)
            )
        }

        // Dominadas libres: 3 series x 6, sin carga
        if name.contains("dominad") && !exercise.loadAllowed {
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 3, reps: 6, loadKg: nil)
            )
        }

        // Bíceps: 3 series x 10 con carga (si se permite)
        if name.contains("biceps") || name.contains("bíceps") {
            let load = exercise.loadAllowed ? 0.0 : nil
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 3, reps: 10, loadKg: load)
            )
        }

        // Fuerza genérica: 3x6
        if category.contains("fuerza") {
            let load = exercise.loadAllowed ? 0.0 : nil
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 3, reps: 6, loadKg: load)
            )
        }

        // Resistencia genérica: 3x10
        if category.contains("resistencia") {
            let load = exercise.loadAllowed ? 0.0 : nil
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 3, reps: 10, loadKg: load)
            )
        }

        // Core en reps: 3x10
        if category.contains("core") {
            let load = exercise.loadAllowed ? 0.0 : nil
            return EntryTemplate(
                intensity: 1,
                sets: makeRepsSets(series: 3, reps: 10, loadKg: load)
            )
        }

        // Default reps: 3 series sin reps predefinidas
        let load = exercise.loadAllowed ? 0.0 : nil
        return EntryTemplate(
            intensity: 1,
            sets: makeRepsSets(series: 3, reps: nil, loadKg: load)
        )
    }

    // MARK: - Uniform builders

    private static func makeRepsSets(series: Int, reps: Int?, loadKg: Double?) -> [SetRecord] {
        guard series > 0 else { return [] }
        return (0..<series).map { _ in
            SetRecord(reps: reps, seconds: nil, loadKg: loadKg)
        }
    }

    private static func makeSecondsSets(series: Int, seconds: Int, loadKg: Double?) -> [SetRecord] {
        guard series > 0 else { return [] }
        return (0..<series).map { _ in
            SetRecord(reps: nil, seconds: seconds, loadKg: loadKg)
        }
    }

    // MARK: - Helpers

    private static func normalizeText(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeMode(_ s: String) -> String {
        let m = normalizeText(s)
        return (m == "seconds") ? "seconds" : "reps"
    }
}
