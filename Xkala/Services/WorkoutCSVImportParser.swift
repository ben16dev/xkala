import Foundation

// MARK: - Preview-only: parse CSV de entrenos sin persistencia

enum WorkoutCSVImportParser {

    static let expectedHeaderColumns = [
        "date", "workoutName", "exerciseName", "intensity", "isDone",
        "setType", "sets", "value", "loadKg", "entryNotes",
    ]

    struct RowError: Identifiable {
        let id = UUID()
        let lineNumber: Int
        let message: String
    }

    struct ParseOutcome {
        /// Filas de datos (excl. cabecera) presentes en el archivo.
        let rowsRead: Int
        let validRows: [WorkoutImportRow]
        let rowErrors: [RowError]
        /// Mensaje si la primera línea no coincide con la cabecera esperada.
        let headerMismatchMessage: String?

        var errorCount: Int { rowErrors.count }

        var uniqueDates: [Date] {
            let cal = Calendar.current
            let keys = Set(validRows.map { cal.startOfDay(for: $0.date) })
            return keys.sorted()
        }

        var uniqueDateCount: Int { uniqueDates.count }
    }

    static func parse(csvText: String) -> ParseOutcome {
        let rawLines = csvText.split(whereSeparator: \.isNewline).map(String.init)
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        guard let firstRaw = lines.first else {
            return ParseOutcome(
                rowsRead: 0,
                validRows: [],
                rowErrors: [RowError(lineNumber: 1, message: "Archivo vacío")],
                headerMismatchMessage: nil
            )
        }

        let firstLine = stripLeadingBOM(firstRaw)
        let delimiter = detectDelimiter(from: firstLine)
        let headerFields = splitDelimitedLine(firstLine, delimiter: delimiter)

        guard headerFields == expectedHeaderColumns else {
            let expectedList = expectedHeaderColumns.joined(separator: ", ")
            return ParseOutcome(
                rowsRead: max(0, lines.count - 1),
                validRows: [],
                rowErrors: [
                    RowError(
                        lineNumber: 1,
                        message:
                            "Cabecera incorrecta. Columnas esperadas (\(expectedHeaderColumns.count)): \(expectedList)"
                    ),
                ],
                headerMismatchMessage: "La primera línea no coincide con la cabecera requerida."
            )
        }

        let dataLines = Array(lines.dropFirst())
        var valid: [WorkoutImportRow] = []
        var errors: [RowError] = []

        for (offset, line) in dataLines.enumerated() {
            let lineNumber = offset + 2
            var columns = splitDelimitedLine(line, delimiter: delimiter)

            if columns.count > expectedHeaderColumns.count {
                errors.append(
                    RowError(
                        lineNumber: lineNumber,
                        message: "Demasiadas columnas: \(columns.count) (máximo \(expectedHeaderColumns.count))."
                    )
                )
                continue
            }

            while columns.count < expectedHeaderColumns.count {
                columns.append("")
            }

            switch parseDataRow(fields: columns, lineNumber: lineNumber) {
            case .success(let row):
                valid.append(row)
            case .failure(let msg):
                errors.append(RowError(lineNumber: lineNumber, message: msg))
            }
        }

        return ParseOutcome(
            rowsRead: dataLines.count,
            validRows: valid,
            rowErrors: errors,
            headerMismatchMessage: nil
        )
    }

    private static func stripLeadingBOM(_ line: String) -> String {
        if line.hasPrefix("\u{FEFF}") { return String(line.dropFirst()) }
        return line
    }

    private static func detectDelimiter(from headerLine: String) -> Character {
        if headerLine.contains("\t") { return "\t" }
        if headerLine.contains(";") { return ";" }
        return ","
    }

    /// Parte una línea por tab, `;` o `,` según `delimiter`. Conserva celdas vacías.
    private static func splitDelimitedLine(_ line: String, delimiter: Character) -> [String] {
        if delimiter == "\t" {
            return line.split(separator: "\t", maxSplits: Int.max, omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if !line.contains("\"") {
            return line.split(separator: delimiter, maxSplits: Int.max, omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        var fields: [String] = []
        var current = ""
        current.reserveCapacity(line.count)
        var i = line.startIndex
        var inQuotes = false

        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                if inQuotes {
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    inQuotes = true
                }
                i = line.index(after: i)
                continue
            }
            if ch == delimiter, !inQuotes {
                fields.append(unquoteCSVField(current))
                current = ""
                i = line.index(after: i)
                continue
            }
            current.append(ch)
            i = line.index(after: i)
        }
        fields.append(unquoteCSVField(current))
        return fields
    }

    private static func unquoteCSVField(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, t.first == "\"", t.last == "\"" else { return t }
        let inner = String(t.dropFirst().dropLast())
        return inner.replacingOccurrences(of: "\"\"", with: "\"")
    }

    // MARK: - Fila de datos

    private enum RowParse {
        case success(WorkoutImportRow)
        case failure(String)
    }

    private static func parseDataRow(fields: [String], lineNumber: Int) -> RowParse {
        let dateRaw = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let workoutName = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let exerciseName = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let intensityRaw = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let isDoneRaw = fields[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let setTypeRaw = fields[5].trimmingCharacters(in: .whitespacesAndNewlines)
        let setsRaw = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueRaw = fields[7].trimmingCharacters(in: .whitespacesAndNewlines)
        let loadRaw = fields[8].trimmingCharacters(in: .whitespacesAndNewlines)
        let entryNotes = fields[9].trimmingCharacters(in: .whitespacesAndNewlines)

        if dateRaw.isEmpty {
            return .failure("date vacío")
        }
        guard let date = parseDate(dateRaw) else {
            return .failure("date no válida: \(dateRaw)")
        }

        if exerciseName.isEmpty {
            return .failure("exerciseName vacío")
        }

        guard let intensity = Int(intensityRaw), (1 ... 3).contains(intensity) else {
            return .failure("intensity debe ser 1, 2 o 3 (recibido: \(intensityRaw))")
        }

        guard parseBoolRequiredTrue(isDoneRaw) else {
            return .failure("isDone debe ser true (recibido: \(isDoneRaw))")
        }

        let setType = setTypeRaw.lowercased()
        guard setType == "reps" || setType == "seconds" else {
            return .failure("setType debe ser reps o seconds (recibido: \(setTypeRaw))")
        }

        guard let sets = Int(setsRaw), sets > 0 else {
            return .failure("sets debe ser un entero > 0 (recibido: \(setsRaw))")
        }

        guard let value = Int(valueRaw), value > 0 else {
            return .failure("value debe ser un entero > 0 (recibido: \(valueRaw))")
        }

        let loadKg: Double?
        if loadRaw.isEmpty {
            loadKg = nil
        } else {
            guard let v = Double(loadRaw.replacingOccurrences(of: ",", with: ".")) else {
                return .failure("loadKg no numérico: \(loadRaw)")
            }
            loadKg = v
        }

        let row = WorkoutImportRow(
            sourceLineNumber: lineNumber,
            date: date,
            workoutName: workoutName,
            exerciseName: exerciseName,
            intensity: intensity,
            isDone: true,
            setType: setType,
            sets: sets,
            value: value,
            loadKg: loadKg,
            entryNotes: entryNotes
        )
        return .success(row)
    }

    private static func parseBoolRequiredTrue(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s == "true" || s == "1" { return true }
        return false
    }

    private static func parseDate(_ raw: String) -> Date? {
        if let d = iso8601Frac.date(from: raw) { return d }
        if let d = iso8601NoFrac.date(from: raw) { return d }
        if let d = dayOnly.date(from: raw) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = df.date(from: raw) { return d }
        df.dateFormat = "dd/MM/yyyy"
        if let d = df.date(from: raw) { return d }
        df.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return df.date(from: raw)
    }

    private static let iso8601Frac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
