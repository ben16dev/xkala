import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutDay.date, order: .forward) private var workoutDays: [WorkoutDay]

    @State private var showImporter = false
    @State private var outcome: WorkoutCSVImportParser.ParseOutcome?
    @State private var fileName: String?
    @State private var loadError: String?

    @State private var showCollisionAlert = false
    @State private var collisionMessage = ""
    @State private var showImportSuccess = false

    @State private var showRevertConfirm = false
    @State private var showRevertSuccess = false
    @State private var revertedSessionCount = 0

    private let dayStyle: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()

    private var canRevertLastImport: Bool {
        WorkoutCSVImportExecutor.latestImportBatchId(in: workoutDays) != nil
    }

    private var lastImportSessionCount: Int {
        guard let batchId = WorkoutCSVImportExecutor.latestImportBatchId(in: workoutDays) else { return 0 }
        return WorkoutCSVImportExecutor.workoutDays(forImportBatchId: batchId, in: workoutDays).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Elige un archivo para previsualizar. La importación solo está disponible si no hay errores.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Ejercicios en catálogo: \(exercises.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        loadError = nil
                        showImporter = true
                    } label: {
                        Label("Elegir archivo CSV", systemImage: "doc.badge.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(XkalaTheme.accent)
                }
                .xkalaCard()

                revertLastImportSection

                if let loadError {
                    Text(loadError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .xkalaCard()
                }

                if let fileName {
                    Text("Archivo: \(fileName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let parseOutcome = outcome {
                    let validated = ImportExerciseCatalogValidator.validate(
                        validRows: parseOutcome.validRows,
                        exercises: exercises
                    )

                    summarySection(
                        outcome: parseOutcome,
                        importableRows: validated.importableRows,
                        catalogErrorCount: validated.catalogErrors.count
                    )

                    if let headerMsg = parseOutcome.headerMismatchMessage {
                        Text(headerMsg)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .xkalaCard()
                    }

                    importCommitSection(
                        outcome: parseOutcome,
                        importableRows: validated.importableRows,
                        catalogErrors: validated.catalogErrors
                    )

                    importableRowsSection(validated.importableRows)
                    errorsSection(
                        parseErrors: parseOutcome.rowErrors,
                        catalogErrors: validated.catalogErrors
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Importar CSV")
        .navigationBarTitleDisplayMode(.large)
        .xkalaScreenBackground()
        .alert("Ya existen sesiones en estas fechas", isPresented: $showCollisionAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(
                "No se puede importar porque ya hay un entrenamiento guardado el: \(collisionMessage). Borra o cambia esas sesiones, o ajusta las fechas en el archivo."
            )
        }
        .alert("Importación completada", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Las sesiones del archivo se han guardado en el calendario.")
        }
        .alert("Eliminar última importación", isPresented: $showRevertConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                revertLastImport()
            }
        } message: {
            Text(
                "Se borrarán \(lastImportSessionCount) sesión(es) creadas en la última importación CSV. Esta acción no se puede deshacer."
            )
        }
        .alert("Importación eliminada", isPresented: $showRevertSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Se eliminaron \(revertedSessionCount) sesión(es) de la última importación.")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    loadError = "No se seleccionó ningún archivo."
                    return
                }
                ingestFile(at: url)
            case .failure(let err):
                loadError = err.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var revertLastImportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deshacer importación")
                .font(.headline)

            Text(
                canRevertLastImport
                    ? "Última importación: \(lastImportSessionCount) sesión(es) marcadas en el calendario."
                    : "No hay importaciones CSV recientes que se puedan eliminar."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(role: .destructive) {
                showRevertConfirm = true
            } label: {
                Label("Eliminar última importación", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canRevertLastImport)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private func revertLastImport() {
        loadError = nil
        do {
            let count = try WorkoutCSVImportExecutor.revertLastImport(days: workoutDays, context: context)
            guard count > 0 else { return }
            revertedSessionCount = count
            showRevertSuccess = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func importCommitSection(
        outcome: WorkoutCSVImportParser.ParseOutcome,
        importableRows: [WorkoutImportRow],
        catalogErrors: [ImportCatalogExerciseError]
    ) -> some View {
        let canImport =
            outcome.rowErrors.isEmpty
            && catalogErrors.isEmpty
            && !importableRows.isEmpty

        if canImport {
            VStack(alignment: .leading, spacing: 10) {
                Text("Importar")
                    .font(.headline)

                Text(
                    "Se crearán \(importableRows.count) ejercicios en \(uniqueDayCount(importableRows)) sesión(es) nueva(s). No se crean ejercicios nuevos en el catálogo."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Button {
                    let conflicts = WorkoutCSVImportExecutor.conflictingImportDayKeys(
                        rows: importableRows,
                        existingDays: workoutDays
                    )
                    guard conflicts.isEmpty else {
                        collisionMessage = formatCollisionDayList(conflicts)
                        showCollisionAlert = true
                        return
                    }
                    do {
                        try WorkoutCSVImportExecutor.run(
                            rows: importableRows,
                            exercises: exercises,
                            context: context
                        )
                        self.outcome = nil
                        fileName = nil
                        showImportSuccess = true
                    } catch {
                        loadError = error.localizedDescription
                    }
                } label: {
                    Label("Importar a la app", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(XkalaTheme.mint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .xkalaCard()
        }
    }

    private func uniqueDayCount(_ rows: [WorkoutImportRow]) -> Int {
        Set(rows.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private func formatCollisionDayList(_ dayKeys: [Date]) -> String {
        dayKeys.map { $0.formatted(dayStyle) }.joined(separator: ", ")
    }

    @ViewBuilder
    private func summarySection(
        outcome: WorkoutCSVImportParser.ParseOutcome,
        importableRows: [WorkoutImportRow],
        catalogErrorCount: Int
    ) -> some View {
        let uniqueDates = Set(importableRows.map { Calendar.current.startOfDay(for: $0.date) }).count
        let totalErrors = outcome.errorCount + catalogErrorCount

        VStack(alignment: .leading, spacing: 10) {
            Text("Resumen")
                .font(.headline)

            HStack {
                summaryChip(title: "Filas leídas", value: "\(outcome.rowsRead)")
                summaryChip(title: "Fechas únicas", value: "\(uniqueDates)")
                summaryChip(title: "Errores", value: "\(totalErrors)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func importableRowsSection(_ rows: [WorkoutImportRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filas importables (\(rows.count))")
                .font(.headline)

            if rows.isEmpty {
                Text("Ninguna fila lista para importar (revisa errores de archivo y de catálogo).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    importableRowCard(row)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private func importableRowCard(_ row: WorkoutImportRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("L\(row.sourceLineNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            HStack {
                Text(row.date.formatted(dayStyle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("I\(row.intensity)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                Text(row.setType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("×\(row.sets)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("valor \(row.value)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let kg = row.loadKg {
                    Text(String(format: "%.1f kg", kg))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !row.workoutName.isEmpty {
                Text(row.workoutName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !row.entryNotes.isEmpty {
                Text(row.entryNotes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func errorsSection(
        parseErrors: [WorkoutCSVImportParser.RowError],
        catalogErrors: [ImportCatalogExerciseError]
    ) -> some View {
        let merged: [(line: Int, message: String)] = (parseErrors.map { ($0.lineNumber, $0.message) }
            + catalogErrors.map { ($0.lineNumber, $0.message) })
            .sorted { a, b in
                if a.line != b.line { return a.line < b.line }
                return a.message < b.message
            }

        VStack(alignment: .leading, spacing: 10) {
            Text("Errores (archivo y catálogo)")
                .font(.headline)

            if merged.isEmpty {
                Text("Sin errores de validación")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(merged.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("L\(item.line)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(XkalaTheme.chartSessions)
                            .frame(width: 40, alignment: .leading)
                        Text(item.message)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private func ingestFile(at url: URL) {
        loadError = nil
        fileName = url.lastPathComponent

        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        do {
            var text = try String(contentsOf: url, encoding: .utf8)
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
            outcome = WorkoutCSVImportParser.parse(csvText: text)
        } catch {
            loadError = error.localizedDescription
            outcome = nil
        }
    }
}

#Preview {
    let schema = Schema([
        WorkoutDay.self,
        Exercise.self,
        WorkoutEntry.self,
        SetRecord.self,
        UserProfile.self,
        ClimbingSessionData.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    container.mainContext.insert(
        Exercise(name: "Dominadas", category: "Fuerza general", mode: "reps", loadAllowed: true)
    )
    container.mainContext.insert(
        Exercise(name: "Plancha", category: "Core", mode: "seconds", loadAllowed: false)
    )
    try? container.mainContext.save()

    return NavigationStack {
        ImportView()
    }
    .modelContainer(container)
}
