import Foundation

/// Plantilla mínima al añadir un ejercicio: intensidad por defecto, sin sets hasta que el usuario los defina.
enum SetTemplates {

    struct EntryTemplate {
        let intensity: Int
        let sets: [SetRecord]
    }

    static func defaultEntryTemplate(for exercise: Exercise) -> EntryTemplate {
        EntryTemplate(intensity: 1, sets: [])
    }
}
