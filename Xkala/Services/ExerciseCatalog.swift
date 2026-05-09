import Foundation

enum ExerciseCatalog {
    static let csv: String = """
Nombre,Categoría,Métrica principal,Permite carga?,Notas opcionales
Press banca mancuernas,Fuerza,reps,si,"Banco plano. 3x6–8. Mantén hombros retraídos; recorrido controlado."
Dominadas escapulares,Resistencia,reps,no,"Colgado en barra. Sin flexionar codos: solo depresión/retracción escapular. 3x10–12."
Plancha TRX,Core,seconds,no,"Pies en TRX, cuerpo en línea. 3x30–40s. Evita hundir lumbar."
Dominadas tempo lento,Resistencia,reps,si,"Subida y bajada lentas (p.ej. 4s + 4s). 3x5. Técnica estricta."
Remo mancuerna,Fuerza,reps,si,"Remo unilateral apoyado o inclinado. 3x10 por lado. Escápula atrás/abajo."
Plancha con arrastre de mancuerna,Core,reps,si,"Plancha alta. Arrastra mancuerna por debajo sin rotar caderas. 3x8–10 por lado."
Side plank con reach-through,Core,reps,no,"Plancha lateral. Brazo libre pasa por debajo y vuelve arriba. 3x8–12 por lado."
Dominadas a una mano asistidas,Resistencia,reps,si,"Asistencia con goma/polea o mano en toalla. 3x3–5 por brazo. Control escapular."
Press militar mancuernas,Fuerza,reps,si,"De pie. 3x6–8. Costillas 'abajo', no hiperextender lumbar."
Remo con barra,Fuerza,reps,si,"Inclinado. 3x8. Espalda neutra, tirón hacia abdomen."
Hollow body hold,Core,seconds,no,"Lumbar pegada al suelo. 4x30–40s. Progresar extendiendo piernas/brazos."
Dominadas isométricas,Resistencia,seconds,si,"Mantener barbilla sobre barra o a 90°. 4x10s. Escápulas activas."
Plancha lateral,Core,seconds,no,"3x30–40s por lado. Cadera alta; cuello neutral."
Dominadas explosivas,Resistencia,reps,si,"Tirón rápido intentando altura. 5x3. Descanso largo (≈3 min)."
Rollouts rueda,Core,reps,no,"Rueda abdominal. 3x10. No colapsar lumbar; rango según control."
Dead bug,Core,reps,no,"3x10 por lado. Lumbar pegada; movimiento lento y coordinado."
Curl martillo,Fuerza,reps,si,"3x10–12. Agarres neutros; control."
Vuelta fluida,Calentamiento,reps,no,"≈3 min. Movimientos fáciles, enfoque en fluidez y respiración."
Vuelta técnica,Calentamiento,reps,no,"≈3 min. Intensidad baja-media: precisión de pies y coordinación."
Suspensiones regleta 20mm (lastre ligero),Hangboard,seconds,si,"Regleta 20 mm. Ej.: 5x10s, rec 2'. Half crimp recomendado."
Suspensiones intermitentes 7''/3'',Hangboard,seconds,si,"Protocolos tipo 7s ON/3s OFF. Registrar rondas y carga/contrapeso."
Suspensiones lastre progresivo,Hangboard,seconds,si,"Series cortas (p.ej. 4x8s). Subir lastre gradualmente; rec 3'."
Suspensiones regleta 18mm,Hangboard,seconds,si,"Regleta 18 mm. Volumen moderado, técnica perfecta, evitar dolor."
Campus básico,Campus,reps,no,"Campus board. Subidas controladas, pies opcionales según nivel. 6 series."
Campus coordinación (toques cortos),Campus,reps,no,"Patrones con 'toques' y coordinación. Mantén hombros activos. 7 series."
Campus dinámico (saltos largos),Campus,reps,no,"Movimientos dinámicos grandes. Descanso alto; parar si técnica cae."
Campus doble toque (explosivo),Campus,reps,no,"Doble toque por peldaño. Alta demanda; rec 3'."
Campus coordinación (rombo),Campus,reps,no,"Patrones tipo rombo/cruce. Enfoque en coordinación."
Campus lanzamientos largos,Campus,reps,no,"Lanzamientos a peldaños altos. Técnica antes que volumen."
Press banca,Fuerza,reps,si,"Banco plano. Peso de trabajo. 3x6–8 con técnica estricta."
Bíceps,Fuerza,reps,si,"Curl con mancuernas o barra. 3x10–12. Agarres neutros o supinados; control."
Hombro,Fuerza,reps,si,"Press hombro. 3x8–10. Tronco estable, costillas abajo."
Dominadas con lastre,Resistencia,reps,si,"Dominadas con lastre adicional. 3x3–5. Rango completo; escápulas activas."
Suspensiones peso negativo,Hangboard,seconds,si,"Regleta con contrapeso (peso negativo). Series moderadas. Registrar contrapeso y tiempo."
Suspensiones con lastre,Hangboard,seconds,si,"Regleta con lastre adicional. Series de 10–15s. Registrar lastre y tiempo."
Test de bíceps,Test,reps,si,"Test: curl con mancuernas/barra. Peso máximo para 2–3 reps, sin balanceo."
Test de dominadas con lastre,Test,reps,si,"Test: lastre máximo para 2–3 reps limpias."
Test de dominadas con lastre negativo,Test,reps,si,"Test: lastre máximo controlando la bajada. Registrar lastre y duración de fase excéntrica."
Test de dominadas libres,Test,reps,no,"Test: máximo de reps limpias, sin kipping, rango completo."
Test de hombro,Test,reps,si,"Test: press hombro. Peso máximo para 2–3 reps, tronco estable."
Test de press banca,Test,reps,si,"Test: peso máximo para 2–3 reps con técnica estricta."
Test de hangboard con lastre,Test,seconds,si,"Test: lastre para 45–60s o intento máximo según protocolo. Registrar lastre y tiempo."
Test de suspensiones intermitentes,Test,seconds,si,"Test: 7s ON/3s OFF hasta fallo o nº rondas objetivo. Registrar carga/contrapeso y rondas."
Test de hangboard peso negativo,Test,seconds,si,"Test: con contrapeso (peso negativo) buscar mayor tiempo posible. Registrar contrapeso y tiempo."
"""

    static func parseRows() -> [[String]] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return [] }

        var rows: [[String]] = []
        for i in 1..<lines.count {
            let row = parseLine(lines[i])
            if !row.isEmpty { rows.append(row) }
        }
        return rows
    }

    private static func parseLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]

            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
                i = line.index(after: i)
                continue
            }

            if ch == ",", !inQuotes {
                fields.append(current)
                current = ""
                i = line.index(after: i)
                continue
            }

            current.append(ch)
            i = line.index(after: i)
        }

        fields.append(current)
        return fields
    }
}
