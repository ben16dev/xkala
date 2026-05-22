import Foundation
import SwiftData

/// Validación de filas importadas frente al catálogo local (sin persistencia).
enum ImportExerciseCatalogValidator {

    static func normalizedExerciseNameKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    /// Una entrada por nombre normalizado; si hay duplicados, prioriza ejercicio no archivado.
    static func exerciseByNormalizedName(_ exercises: [Exercise]) -> [String: Exercise] {
        var map: [String: Exercise] = [:]
        for ex in exercises {
            let key = normalizedExerciseNameKey(ex.name)
            if let existing = map[key] {
                if existing.isArchived, !ex.isArchived {
                    map[key] = ex
                }
            } else {
                map[key] = ex
            }
        }
        return map
    }

    static func validate(
        validRows: [WorkoutImportRow],
        exercises: [Exercise]
    ) -> (importableRows: [WorkoutImportRow], catalogErrors: [ImportCatalogExerciseError]) {
        let map = exerciseByNormalizedName(exercises)
        var errors: [ImportCatalogExerciseError] = []
        var ok: [WorkoutImportRow] = []

        for row in validRows {
            let key = normalizedExerciseNameKey(row.exerciseName)
            guard let ex = map[key] else {
                errors.append(
                    ImportCatalogExerciseError(
                        lineNumber: row.sourceLineNumber,
                        message: "Ejercicio no encontrado: «\(row.exerciseName)»"
                    )
                )
                continue
            }

            var rowHasError = false

            if row.setType == "reps", ex.mode.lowercased() != "reps" {
                errors.append(
                    ImportCatalogExerciseError(
                        lineNumber: row.sourceLineNumber,
                        message:
                            "setType reps pero el ejercicio «\(ex.name)» tiene mode \(ex.mode)."
                    )
                )
                rowHasError = true
            }

            if row.setType == "seconds", ex.mode.lowercased() != "seconds" {
                errors.append(
                    ImportCatalogExerciseError(
                        lineNumber: row.sourceLineNumber,
                        message:
                            "setType seconds pero el ejercicio «\(ex.name)» tiene mode \(ex.mode)."
                    )
                )
                rowHasError = true
            }

            if row.loadKg != nil, !ex.loadAllowed {
                errors.append(
                    ImportCatalogExerciseError(
                        lineNumber: row.sourceLineNumber,
                        message:
                            "loadKg con valor pero el ejercicio «\(ex.name)» no admite carga (loadAllowed = false)."
                    )
                )
                rowHasError = true
            }

            if !rowHasError {
                ok.append(row)
            }
        }

        errors.sort { $0.lineNumber < $1.lineNumber }
        return (ok, errors)
    }
}

struct ImportCatalogExerciseError: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let message: String
}
