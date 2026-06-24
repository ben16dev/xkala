import Foundation

/// Snapshot derivado (sin persistencia) con los resultados de un ejercicio Test.
struct ExerciseTestSnapshot: Equatable {
    let hasData: Bool
    /// Texto del último resultado registrado. Vacío si `hasData == false`.
    let lastResultText: String
    /// Texto de la mejor marca histórica. Vacío si `hasData == false`.
    let bestResultText: String
    /// Texto del delta respecto al test anterior. Vacío si solo hay un registro o sin datos.
    let deltaText: String
    /// `true` si el último resultado supera al anterior.
    let isImproving: Bool

    static let empty = ExerciseTestSnapshot(
        hasData: false,
        lastResultText: "",
        bestResultText: "",
        deltaText: "",
        isImproving: false
    )
}
