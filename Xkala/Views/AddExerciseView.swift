import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Importante: ocultamos archivados
    @Query(
        filter: #Predicate<Exercise> { $0.isArchived == false },
        sort: \Exercise.name
    )
    private var exercises: [Exercise]

    @Bindable var workout: WorkoutDay

    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Todas"

    @State private var showNewExercise: Bool = false
    @State private var isImporting: Bool = false

    var body: some View {
        let filtered = filteredExercises(
            exercises: exercises,
            searchText: searchText,
            selectedCategory: selectedCategory
        )

        return List {
            if isImporting {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Importando catálogo…")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .xkalaCard()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // Filtros en tarjeta (full width)
            Section {
                VStack(spacing: 12) {
                    TextField("Buscar ejercicio…", text: $searchText)
                        .disabled(isImporting)

                    Divider().opacity(0.25)

                    HStack {
                        Text("Categoría")
                        Spacer()
                        Picker("Categoría", selection: $selectedCategory) {
                            ForEach(categoryList, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isImporting)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .xkalaCard()
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Resultados
            Section {
                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 26))
                            .foregroundStyle(.secondary)

                        Text(isImporting ? "Importando… espera un momento." : "No hay resultados")
                            .font(.headline)

                        Text("Prueba a cambiar la categoría o el texto de búsqueda.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .xkalaCard()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } else {
                    ForEach(filtered) { ex in
                        Button {
                            let template = SetTemplates.defaultEntryTemplate(for: ex)
                            let entry = WorkoutEntry(
                                exercise: ex,
                                intensity: template.intensity,
                                isDone: false,
                                entryNotes: "",
                                sets: template.sets
                            )
                            workout.entries.append(entry)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Importante: NO usamos accent en el título
                                    Text(ex.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("\(ex.category) · \(ex.mode == "seconds" ? "Tiempo" : "Reps") · \(ex.loadAllowed ? "Con carga" : "Sin carga")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if !ex.notes.isEmpty {
                                        Text(ex.notes)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(XkalaTheme.accent)
                                    .opacity(isImporting ? 0.4 : 1.0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .xkalaCard()
                        }
                        .buttonStyle(.plain)
                        .disabled(isImporting)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .navigationTitle("Añadir ejercicio")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showNewExercise = true
                } label: {
                    XkalaActionButton(
                        title: "Nuevo",
                        systemImage: "plus"
                    )
                }
                .disabled(isImporting)

                Button {
                    Task { await resetAndReimportCatalog() }
                } label: {
                    XkalaActionButton(
                        title: "Reimportar",
                        systemImage: "plus"
                    )
                }
                .disabled(isImporting)
            }
        }
        .sheet(isPresented: $showNewExercise) {
            NavigationStack {
                NewExerciseView { newExercise in
                    do {
                        // UPSERT también para creación manual (evita duplicados)
                        let name = newExercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let category = newExercise.category.trimmingCharacters(in: .whitespacesAndNewlines)
                        let mode = (newExercise.mode == "seconds") ? "seconds" : "reps"

                        try ExerciseImporter.upsertExercise(
                            name: name,
                            category: category,
                            mode: mode,
                            loadAllowed: newExercise.loadAllowed,
                            notes: newExercise.notes,
                            context: context
                        )

                        try? context.save()
                        showNewExercise = false
                    } catch {
                        print("❌ Error guardando ejercicio manual: \(error)")
                    }
                } onCancel: {
                    showNewExercise = false
                }
            }
        }
        .onAppear {
            if exercises.isEmpty && !isImporting {
                Task {
                    await seedExercisesIfNeeded()
                    await BaseExercisesSeeder.ensureBaseExercisesExist(context: context)
                }
            } else {
                Task {
                    await BaseExercisesSeeder.ensureBaseExercisesExist(context: context)
                }
            }
        }
    }

    private var categoryList: [String] {
        let unique = Set(exercises.map { $0.category }).sorted()
        return ["Todas"] + unique
    }

    private func filteredExercises(exercises: [Exercise], searchText: String, selectedCategory: String) -> [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return exercises.filter { ex in
            let matchesCategory = (selectedCategory == "Todas") || (ex.category == selectedCategory)
            let matchesSearch = q.isEmpty || ex.name.lowercased().contains(q)
            return matchesCategory && matchesSearch
        }
    }

    private func seedExercisesIfNeeded() async {
        guard exercises.isEmpty else { return }
        await importFromCSVReplacingExisting(archiveExisting: false)
    }

    private func resetAndReimportCatalog() async {
        await importFromCSVReplacingExisting(archiveExisting: true)
        await MainActor.run {
            searchText = ""
            selectedCategory = "Todas"
        }
    }

    private func importFromCSVReplacingExisting(archiveExisting: Bool) async {
        await MainActor.run { isImporting = true }

        // Parse fuera del main thread
        let rows: [[String]] = await Task.detached(priority: .userInitiated) {
            await ExerciseCatalog.parseRows()
        }.value

        // Import en main thread (SwiftData)
        await MainActor.run {
            do {
                if archiveExisting {
                    // IMPORTANTE:
                    // En vez de borrar (rompe relaciones WorkoutEntry -> Exercise),
                    // archivamos todo lo visible. Luego el UPSERT reactivará lo que vuelva en el CSV.
                    for ex in exercises {
                        ex.isArchived = true
                    }
                    try? context.save()
                }

                try ExerciseImporter.upsertFromCatalogRows(rows, context: context)

                try? context.save()
            } catch {
                print("❌ Error importando catálogo: \(error)")
            }

            isImporting = false
        }
    }
}

private struct NewExerciseView: View {
    var onSave: (Exercise) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var category: String = "Fuerza"
    @State private var mode: String = "reps"
    @State private var loadAllowed: Bool = true
    @State private var notes: String = ""

    private let categories = ["Hangboard", "Fuerza", "Resistencia", "Core", "Técnica", "Movilidad", "Otros"]

    var body: some View {
        Form {
            Section("Básico") {
                TextField("Nombre", text: $name)

                Picker("Categoría", selection: $category) {
                    ForEach(categories, id: \.self) { c in
                        Text(c).tag(c)
                    }
                }

                Picker("Métrica", selection: $mode) {
                    Text("Reps").tag("reps")
                    Text("Tiempo (segundos)").tag("seconds")
                }

                Toggle("Permite carga", isOn: $loadAllowed)
            }

            Section("Notas") {
                TextField("Cómo se hace / protocolo…", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle("Nuevo ejercicio")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancelar") { onCancel() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(Exercise(name: trimmed, category: category, mode: mode, loadAllowed: loadAllowed, notes: notes))
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
