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
            ClimbingSessionData.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
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
