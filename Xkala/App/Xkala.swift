import SwiftUI
import SwiftData

@main
struct Xkala: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutDay.self,
            Exercise.self,
            WorkoutEntry.self,
            SetRecord.self,
            UserProfile.self,
            ClimbingSessionData.self,
            ClimbingRouteRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Migración ligera fallida (p. ej. esquema incompatible tras cambio de modelo).
            fatalError("No se pudo cargar SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                XkalaTheme.calendarScreenBackground.ignoresSafeArea()
                ContentView()
            }
            .preferredColorScheme(.dark)
            .tint(XkalaTheme.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}
