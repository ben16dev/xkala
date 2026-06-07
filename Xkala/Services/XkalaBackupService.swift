import Foundation
import SwiftData

@MainActor
enum XkalaBackupService {

    private static let supportedSchemaVersion = 2
    private static let appName = "Xkala"

    // MARK: - Export

    static func export(context: ModelContext) throws -> Data {
        let exercises = try context.fetch(
            FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.name, order: .forward)])
        )
        let workoutDays = try context.fetch(
            FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\WorkoutDay.date, order: .forward)])
        )
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())

        let backup = XkalaBackupV2(
            schemaVersion: supportedSchemaVersion,
            exportedAt: Date(),
            appName: appName,
            userProfile: profiles.first.map(mapUserProfile),
            exercises: exercises.map(mapExercise),
            workoutDays: workoutDays.map(mapWorkoutDay)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func exportTemporaryJSONFile(context: ModelContext) throws -> URL {
        let data = try export(context: context)
        let fileName = backupFileName(for: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: url, options: [.atomic])
        return url
    }

    static func backupFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "xkala_backup_v2_\(formatter.string(from: date)).json"
    }

    // MARK: - Parse / resumen

    static func parseBackup(data: Data) throws -> XkalaBackupV2 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: XkalaBackupV2
        do {
            backup = try decoder.decode(XkalaBackupV2.self, from: data)
        } catch {
            throw XkalaBackupError.invalidFormat(error.localizedDescription)
        }
        guard backup.schemaVersion == supportedSchemaVersion else {
            throw XkalaBackupError.unsupportedSchemaVersion(backup.schemaVersion)
        }
        return backup
    }

    static func fileSummary(from backup: XkalaBackupV2) -> XkalaBackupFileSummary {
        let entries = backup.workoutDays.reduce(0) { $0 + $1.entries.count }
        let sets = backup.workoutDays.reduce(0) { partial, day in
            partial + day.entries.reduce(0) { $0 + $1.sets.count }
        }
        return XkalaBackupFileSummary(
            exercises: backup.exercises.count,
            sessions: backup.workoutDays.count,
            entries: entries,
            sets: sets
        )
    }

    // MARK: - Import

    static func importBackup(
        _ backup: XkalaBackupV2,
        context: ModelContext
    ) throws -> XkalaBackupImportResult {
        var result = XkalaBackupImportResult()

        let existingExercises = try context.fetch(
            FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.name, order: .forward)])
        )
        let existingDays = try context.fetch(
            FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\WorkoutDay.date, order: .forward)])
        )

        var exerciseByKey = exerciseLookupMap(from: existingExercises)
        let existingSessionFingerprints = Set(existingDays.map(sessionFingerprint(for:)))

        // 1. Ejercicios
        for dto in backup.exercises {
            let key = exerciseMatchKey(dto.name)
            if exerciseByKey[key] != nil { continue }

            let exercise = Exercise(
                name: dto.name,
                category: dto.category,
                mode: dto.mode,
                loadAllowed: dto.loadAllowed,
                notes: dto.notes,
                isArchived: dto.isArchived
            )
            context.insert(exercise)
            exerciseByKey[key] = exercise
            result.importedExercises += 1
        }

        // 2. Perfil
        if let profileDTO = backup.userProfile {
            try importUserProfile(profileDTO, context: context)
        }

        // 3. Sesiones
        for dayDTO in backup.workoutDays {
            let fingerprint = sessionFingerprint(
                date: dayDTO.date,
                name: dayDTO.name,
                entryCount: dayDTO.entries.count
            )
            if existingSessionFingerprints.contains(fingerprint) {
                result.skippedSessions += 1
                continue
            }

            do {
                let counts = try importWorkoutDay(
                    dayDTO,
                    exerciseByKey: exerciseByKey,
                    context: context
                )
                result.importedSessions += 1
                result.importedEntries += counts.entries
                result.importedSets += counts.sets
            } catch {
                result.errors.append(error.localizedDescription)
            }
        }

        try context.save()
        return result
    }

    // MARK: - Mapeo export

    private static func mapUserProfile(_ profile: UserProfile) -> UserProfileBackupDTO {
        UserProfileBackupDTO(
            name: profile.name,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthDate: profile.birthDate,
            gender: profile.gender
        )
    }

    private static func mapExercise(_ exercise: Exercise) -> ExerciseBackupDTO {
        ExerciseBackupDTO(
            name: exercise.name,
            category: exercise.category,
            mode: exercise.mode,
            loadAllowed: exercise.loadAllowed,
            notes: exercise.notes,
            isArchived: exercise.isArchived
        )
    }

    private static func mapWorkoutDay(_ day: WorkoutDay) -> WorkoutDayBackupDTO {
        WorkoutDayBackupDTO(
            date: day.date,
            startedAt: day.startedAt,
            endedAt: day.endedAt,
            name: day.name,
            notes: day.notes,
            sessionType: day.sessionType,
            durationMinutes: day.durationMinutes,
            rpe: day.rpe,
            perceivedFatigue: day.perceivedFatigue,
            fingerSensation: day.fingerSensation,
            painNotes: day.painNotes,
            trainingMethodRawValue: day.trainingMethodRawValue,
            climbingData: day.climbingData.map(mapClimbingData),
            entries: day.entries.map(mapWorkoutEntry)
        )
    }

    private static func mapClimbingData(_ data: ClimbingSessionData) -> ClimbingSessionDataBackupDTO {
        ClimbingSessionDataBackupDTO(
            location: data.location,
            sector: data.sector,
            routesCount: data.routesCount,
            attemptedRoutesCount: data.attemptedRoutesCount,
            sentRoutesCount: data.sentRoutesCount,
            bestTriedGrade: data.bestTriedGrade,
            bestSentGrade: data.bestSentGrade,
            grades: data.grades,
            routes: data.routes.map(mapClimbingRoute)
        )
    }

    private static func mapClimbingRoute(_ route: ClimbingRouteRecord) -> ClimbingRouteRecordBackupDTO {
        ClimbingRouteRecordBackupDTO(
            name: route.name,
            grade: route.grade,
            isSent: route.isSent
        )
    }

    private static func mapWorkoutEntry(_ entry: WorkoutEntry) -> WorkoutEntryBackupDTO {
        WorkoutEntryBackupDTO(
            exerciseName: entry.exercise.name,
            intensity: entry.intensity,
            isDone: entry.isDone,
            entryNotes: entry.entryNotes,
            climbKind: entry.climbKind,
            climbIdentifier: entry.climbIdentifier,
            climbGradeColor: entry.climbGradeColor,
            climbSuccess: entry.climbSuccess,
            sets: entry.sets.map(mapSetRecord)
        )
    }

    private static func mapSetRecord(_ set: SetRecord) -> SetRecordBackupDTO {
        SetRecordBackupDTO(
            reps: set.reps,
            seconds: set.seconds,
            loadKg: set.loadKg
        )
    }

    // MARK: - Import helpers

    private struct EntryImportCounts {
        var entries: Int
        var sets: Int
    }

    private static func importUserProfile(_ dto: UserProfileBackupDTO, context: ModelContext) throws {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let profile: UserProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = UserProfile()
            context.insert(profile)
        }
        profile.name = dto.name
        profile.heightCm = dto.heightCm
        profile.weightKg = dto.weightKg
        profile.birthDate = dto.birthDate
        profile.gender = dto.gender
    }

    private static func importWorkoutDay(
        _ dto: WorkoutDayBackupDTO,
        exerciseByKey: [String: Exercise],
        context: ModelContext
    ) throws -> EntryImportCounts {
        for entryDTO in dto.entries {
            let key = exerciseMatchKey(entryDTO.exerciseName)
            guard exerciseByKey[key] != nil else {
                throw XkalaBackupError.missingExercise(entryDTO.exerciseName)
            }
        }

        var climbingData: ClimbingSessionData?
        if let climbingDTO = dto.climbingData {
            climbingData = ClimbingSessionData(
                location: climbingDTO.location,
                sector: climbingDTO.sector,
                routesCount: climbingDTO.routesCount,
                attemptedRoutesCount: climbingDTO.attemptedRoutesCount,
                sentRoutesCount: climbingDTO.sentRoutesCount,
                bestTriedGrade: climbingDTO.bestTriedGrade,
                bestSentGrade: climbingDTO.bestSentGrade,
                grades: climbingDTO.grades,
                routes: []
            )
            context.insert(climbingData!)
            for routeDTO in climbingDTO.routes {
                let route = ClimbingRouteRecord(
                    name: routeDTO.name,
                    grade: routeDTO.grade,
                    isSent: routeDTO.isSent
                )
                context.insert(route)
                climbingData?.routes.append(route)
            }
        }

        let day = WorkoutDay(
            date: dto.date,
            name: dto.name,
            notes: dto.notes,
            entries: [],
            startedAt: dto.startedAt,
            endedAt: dto.endedAt,
            sessionType: dto.sessionType,
            climbingData: climbingData
        )
        day.durationMinutes = dto.durationMinutes
        day.rpe = dto.rpe
        day.perceivedFatigue = dto.perceivedFatigue
        day.fingerSensation = dto.fingerSensation
        day.painNotes = dto.painNotes
        day.trainingMethodRawValue = dto.trainingMethodRawValue
        day.normalizePlanningScalars()
        day.applySessionTypeConsistency()
        context.insert(day)

        var importedEntries = 0
        var importedSets = 0

        for entryDTO in dto.entries {
            let exerciseKey = exerciseMatchKey(entryDTO.exerciseName)
            guard let exercise = exerciseByKey[exerciseKey] else {
                throw XkalaBackupError.missingExercise(entryDTO.exerciseName)
            }

            let entry = WorkoutEntry(
                exercise: exercise,
                intensity: entryDTO.intensity,
                isDone: entryDTO.isDone,
                entryNotes: entryDTO.entryNotes,
                sets: [],
                climbKind: entryDTO.climbKind,
                climbIdentifier: entryDTO.climbIdentifier,
                climbGradeColor: entryDTO.climbGradeColor,
                climbSuccess: entryDTO.climbSuccess
            )
            context.insert(entry)

            for setDTO in entryDTO.sets {
                let set = SetRecord(
                    reps: setDTO.reps,
                    seconds: setDTO.seconds,
                    loadKg: setDTO.loadKg
                )
                context.insert(set)
                entry.sets.append(set)
                importedSets += 1
            }

            day.entries.append(entry)
            importedEntries += 1
        }

        return EntryImportCounts(entries: importedEntries, sets: importedSets)
    }

    // MARK: - Duplicados

    private struct SessionFingerprint: Hashable {
        let day: Date
        let normalizedName: String
        let entryCount: Int
    }

    private static func sessionFingerprint(for day: WorkoutDay) -> SessionFingerprint {
        sessionFingerprint(date: day.date, name: day.name, entryCount: day.entries.count)
    }

    private static func sessionFingerprint(
        date: Date,
        name: String,
        entryCount: Int
    ) -> SessionFingerprint {
        SessionFingerprint(
            day: Calendar.current.startOfDay(for: date),
            normalizedName: normalizedSessionName(name),
            entryCount: entryCount
        )
    }

    private static func normalizedSessionName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    private static func exerciseMatchKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    /// Índice por nombre normalizado; si hay duplicados en el store, conserva el primero (orden del fetch).
    private static func exerciseLookupMap(from exercises: [Exercise]) -> [String: Exercise] {
        var map: [String: Exercise] = [:]
        for exercise in exercises {
            let key = exerciseMatchKey(exercise.name)
            if map[key] == nil {
                map[key] = exercise
            }
        }
        return map
    }
}
