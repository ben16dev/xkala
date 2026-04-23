import Foundation

enum ExerciseCatalog {
    static let csv: String = """
Nombre,Categoría,Métrica principal,Permite carga?,Notas opcionales
Dominadas con lastre negativo,Fuerza,reps,si,"Barra fija. Rango típico 4x4. Lastre en kg. Controla bajada; escápulas activas."
Press banca mancuernas,Fuerza,reps,si,"Banco plano. 3x6–8. Mantén hombros retraídos; recorrido controlado."
Dominadas escapulares,Fuerza,reps,no,"Colgado en barra. Sin flexionar codos: solo depresión/retracción escapular. 3x10–12."
Plancha TRX,Core,seconds,no,"Pies en TRX, cuerpo en línea. 3x30–40s. Evita hundir lumbar."
Dominadas tempo lento,Resistencia,reps,si,"Subida y bajada lentas (p.ej. 4s + 4s). 3x5. Técnica estricta."
Remo mancuerna,Fuerza,reps,si,"Remo unilateral apoyado o inclinado. 3x10 por lado. Escápula atrás/abajo."
Plancha con arrastre de mancuerna,Core,reps,si,"Plancha alta. Arrastra mancuerna por debajo sin rotar caderas. 3x8–10 por lado."
Side plank con reach-through,Core,reps,no,"Plancha lateral. Brazo libre pasa por debajo y vuelve arriba. 3x8–12 por lado."
Dominadas a una mano asistidas,Fuerza,reps,si,"Asistencia con goma/polea o mano en toalla. 3x3–5 por brazo. Control escapular."
Press militar mancuernas,Fuerza,reps,si,"De pie. 3x6–8. Costillas 'abajo', no hiperextender lumbar."
Remo con barra,Fuerza,reps,si,"Inclinado. 3x8. Espalda neutra, tirón hacia abdomen."
Hollow body hold,Core,seconds,no,"Lumbar pegada al suelo. 4x30–40s. Progresar extendiendo piernas/brazos."
Dominadas isométricas,Fuerza,seconds,si,"Mantener barbilla sobre barra o a 90°. 4x10s. Escápulas activas."
Plancha lateral,Core,seconds,no,"3x30–40s por lado. Cadera alta; cuello neutral."
Dominadas explosivas,Fuerza,reps,si,"Tirón rápido intentando altura. 5x3. Descanso largo (≈3 min)."
Rollouts rueda,Core,reps,no,"Rueda abdominal. 3x10. No colapsar lumbar; rango según control."
Dead bug,Core,reps,no,"3x10 por lado. Lumbar pegada; movimiento lento y coordinado."
Curl martillo,Fuerza,reps,si,"3x10–12. Agarres neutros; control."
Vuelta fluida,Técnica,reps,no,"≈3 min. Movimientos fáciles, enfoque en fluidez y respiración."
Vuelta técnica,Técnica,reps,no,"≈3 min. Intensidad baja-media: precisión de pies y coordinación."
Suspensiones regleta 20mm (lastre ligero),Hangboard,seconds,si,"Regleta 20 mm. Ej.: 5x10s, rec 2'. Half crimp recomendado."
Suspensiones intermitentes 7''/3'',Hangboard,seconds,si,"Protocolos tipo 7s ON/3s OFF. Registrar rondas y carga/contrapeso."
Suspensiones lastre progresivo,Hangboard,seconds,si,"Series cortas (p.ej. 4x8s). Subir lastre gradualmente; rec 3'."
Suspensiones regleta 18mm,Hangboard,seconds,si,"Regleta 18 mm. Volumen moderado, técnica perfecta, evitar dolor."
Campus básico,Resistencia,reps,no,"Campus board. Subidas controladas, pies opcionales según nivel. 6 series."
Campus coordinación (toques cortos),Técnica,reps,no,"Patrones con 'toques' y coordinación. Mantén hombros activos. 7 series."
Campus dinámico (saltos largos),Fuerza,reps,no,"Movimientos dinámicos grandes. Descanso alto; parar si técnica cae."
Campus doble toque (explosivo),Fuerza,reps,no,"Doble toque por peldaño. Alta demanda; rec 3'."
Campus coordinación (rombo),Técnica,reps,no,"Patrones tipo rombo/cruce. Enfoque en coordinación."
Campus lanzamientos largos,Fuerza,reps,no,"Lanzamientos a peldaños altos. Técnica antes que volumen."
Press banca,Fuerza,reps,si,"Test: peso máximo para 2–3 reps con técnica estricta."
Bíceps,Fuerza,reps,si,"Test: curl con mancuernas/barra. Peso máximo para 2–3 reps, sin balanceo."
Hombro,Fuerza,reps,si,"Test: press hombro. Peso máximo para 2–3 reps, tronco estable."
Dominadas libres,Resistencia,reps,no,"Reps limpias, sin kipping, rango completo."
Dominadas con lastre,Fuerza,reps,si,"Test: lastre máximo para 2–3 reps limpias."
Suspensiones peso negativo,Hangboard,seconds,si,"Test: con contrapeso (peso negativo) buscar mayor tiempo posible. Registrar contrapeso y tiempo."
Suspensiones con lastre,Hangboard,seconds,si,"Test: lastre para 45–60s o intento máximo según protocolo. Registrar lastre y tiempo."
Suspensiones intermitente 7''/3'',Hangboard,seconds,si,"Test: 7s ON/3s OFF hasta fallo o nº rondas objetivo. Registrar carga/contrapeso y rondas."
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
