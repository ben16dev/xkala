import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var context

    @State private var showImporter = false
    @State private var fileName: String?
    @State private var loadError: String?
    @State private var parsedBackup: XkalaBackupV2?
    @State private var fileSummary: XkalaBackupFileSummary?
    @State private var importResult: XkalaBackupImportResult?
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introSection

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

                if let summary = fileSummary {
                    backupSummarySection(summary)
                }

                if parsedBackup != nil, importResult == nil {
                    importActionSection
                }

                if let result = importResult {
                    importResultSection(result)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Importar backup")
        .navigationBarTitleDisplayMode(.large)
        .xkalaScreenBackground()
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            resetImportState()
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

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Restaura un backup completo de Xkala (formato V2). Solo se admite schemaVersion = 2.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showImporter = true
            } label: {
                Label("Elegir archivo de backup", systemImage: "doc.badge.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(XkalaTheme.accent)
        }
        .xkalaCard()
    }

    private func backupSummarySection(_ summary: XkalaBackupFileSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contenido del backup")
                .font(.headline)

            summaryRow("Ejercicios", summary.exercises)
            summaryRow("Sesiones", summary.sessions)
            summaryRow("Entries", summary.entries)
            summaryRow("Sets", summary.sets)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private var importActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Las sesiones duplicadas (misma fecha, nombre y número de entries) se omitirán automáticamente.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                runImport()
            } label: {
                Label("Importar backup", systemImage: "square.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(XkalaTheme.mint)
            .disabled(isImporting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private func importResultSection(_ result: XkalaBackupImportResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resultado")
                .font(.headline)

            Text("Importados")
                .font(.subheadline.weight(.semibold))

            summaryRow("Ejercicios", result.importedExercises)
            summaryRow("Sesiones", result.importedSessions)
            summaryRow("Entries", result.importedEntries)
            summaryRow("Sets", result.importedSets)

            Divider()

            Text("Omitidos")
                .font(.subheadline.weight(.semibold))
            summaryRow("Sesiones", result.skippedSessions)

            if !result.errors.isEmpty {
                Divider()
                Text("Errores (\(result.errors.count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)

                ForEach(Array(result.errors.enumerated()), id: \.offset) { _, message in
                    Text("• \(message)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
    }

    private func summaryRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func resetImportState() {
        loadError = nil
        fileName = nil
        parsedBackup = nil
        fileSummary = nil
        importResult = nil
    }

    private func ingestFile(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let backup = try XkalaBackupService.parseBackup(data: data)
            parsedBackup = backup
            fileSummary = XkalaBackupService.fileSummary(from: backup)
            fileName = url.lastPathComponent
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func runImport() {
        guard let backup = parsedBackup else { return }
        isImporting = true
        loadError = nil
        defer { isImporting = false }

        do {
            importResult = try XkalaBackupService.importBackup(backup, context: context)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
