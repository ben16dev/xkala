import Foundation

enum ExerciseCatalog {
    /// Nombres históricos / variantes de catálogo → nombre canónico en el CSV actual.
    /// La importación actualiza el **mismo** `Exercise` cuando encuentra coincidencia por alias.
    static let renameMap: [String: String] = [
        "Press banca mancuernas": "Press banca",
        "Side plank con reach-through": "Plancha lateral con rotación",
        "Dominadas a una mano asistidas": "Dominadas asistidas",
        "Bíceps": "Curl martillo",
        "Hombro": "Press militar mancuernas",
        "Vuelta fluida": "Circuito fluido",
        "Vuelta técnica": "Circuito técnico",
        "Suspensiones regleta 20mm (lastre ligero)": "Suspensiones libres",
        "Suspensiones intermitentes 7''/3''": "Suspensiones intermitentes",
        "Suspensiones lastre progresivo": "Suspensiones con lastre",
        "Suspensiones regleta 18mm": "Suspensiones libres",
        "Campus coordinación (toques cortos)": "Campus coordinación",
        "Campus coordinación (rombo)": "Campus coordinación",
        "Campus dinámico (saltos largos)": "Campus dinámico",
        "Campus doble toque (explosivo)": "Campus dinámico",
        "Campus lanzamientos largos": "Campus dinámico"
    ]

    static let csv: String = """
Nombre,Categoría,Métrica principal,Permite carga?,Notas opcionales
Press banca,Fuerza general,reps,si,"Banco plano. Peso de trabajo. Mantén hombros retraídos y recorrido controlado."
Dominadas escapulares,Acondicionamiento,reps,no,"Colgado en barra. Sin flexionar codos: solo depresión/retracción escapular."
Dominadas libres,Fuerza general,reps,no,"Dominadas estrictas con peso corporal. Mantén escápulas activas, controla el movimiento y evita balanceos."
Plancha TRX,Core,seconds,no,"Pies en TRX, cuerpo en línea. Mantén tensión corporal y evita hundir la lumbar."
Dominadas con peso negativo,Fuerza general,reps,si,"Dominadas con descarga mediante goma, polea o apoyo parcial. Registra la ayuda usada y prioriza técnica estricta."
Remo mancuerna,Fuerza general,reps,si,"Remo unilateral apoyado o inclinado. Escápula atrás y abajo; evita girar el tronco."
Plancha con arrastre de mancuerna,Core,reps,si,"Plancha alta. Arrastra la mancuerna por debajo sin rotar caderas."
Plancha lateral con rotación,Core,reps,no,"Plancha lateral. Pasa el brazo libre por debajo y vuelve arriba sin perder control."
Dominadas asistidas,Acondicionamiento,reps,no,"Con goma, máquina o apoyo parcial. Acumula repeticiones limpias sin perder técnica."
Remo con barra,Fuerza general,reps,si,"Remo inclinado con barra. Espalda neutra y tirón hacia abdomen."
Elevaciones laterales,Fuerza general,reps,si,"Eleva mancuernas lateralmente con control. Evita balanceos y mantén hombros bajos."
Face pull alto volumen,Acondicionamiento,reps,si,"Polea o banda. Tira hacia la cara con codos altos. Controla hombros y postura."
Remo TRX alto volumen,Acondicionamiento,reps,no,"Remo moderado con muchas repeticiones. Mantén escápulas activas y ritmo constante."
Elevaciones de rodillas colgado,Core,reps,no,"Colgado en barra. Eleva rodillas sin balanceo y mantén escápulas activas."
Rotación externa con banda,Acondicionamiento,reps,no,"Codo pegado al cuerpo. Rota hacia fuera con control, sin compensar con el tronco."
Extensión de muñeca excéntrica,Acondicionamiento,reps,si,"Bajada lenta con mancuerna ligera. Trabajo preventivo de antebrazo y codo."
Sentadilla búlgara,Fuerza general,reps,si,"Trabajo unilateral de pierna. Mantén tronco estable, rodilla alineada y controla la bajada."
Sentadilla clásica,Fuerza general,reps,si,"Sentadilla básica con peso corporal, barra o mancuernas."
Sentadilla lateral,Acondicionamiento,reps,si,"Desplazamiento lateral controlado. Trabaja movilidad de cadera, estabilidad y empuje de pierna."
Sentadilla isométrica,Acondicionamiento,seconds,no,"Mantén posición de sentadilla contra pared. Espalda estable, rodillas alineadas y tensión constante."
Toes to bar asistido,Core,reps,no,"Colgado en barra. Eleva piernas con control, sin impulso excesivo ni pérdida escapular."
Pallof press,Core,reps,si,"Polea o goma. Empuja al frente resistiendo la rotación del tronco."
Hollow body hold,Core,seconds,no,"Lumbar pegada al suelo. Mantén tensión global y progresa extendiendo brazos o piernas."
Dominadas isométricas,Fuerza general,seconds,no,"Mantén posición fija sobre la barra o a 90°. Escápulas activas y tensión controlada."
Plancha lateral,Core,seconds,no,"Mantén cadera alta, cuello neutro y línea corporal estable."
Dominadas explosivas,Fuerza general,reps,no,"Tirón rápido buscando altura. Descanso amplio y técnica limpia."
Rollouts rueda,Core,reps,no,"Rueda abdominal. Avanza solo hasta donde puedas controlar la lumbar."
Dead bug,Core,reps,no,"Lumbar pegada al suelo. Movimiento lento y coordinado de brazo y pierna contraria."
Circuito fluido,Acondicionamiento,reps,no,"Movimientos fáciles, enfoque en fluidez y respiración."
Circuito técnico,Acondicionamiento,reps,no,"Precisión de pies y coordinación."
Suspensiones libres,Hangboard,seconds,no,"Suspensiones con peso corporal. Registra tamaño de canto, agarre usado y sensación."
Suspensiones intermitentes,Hangboard,seconds,si,"Protocolos tipo 7s ON/3s OFF. Registra rondas, descanso y carga o descarga."
Campus básico,Campus,reps,no,"Campus board. Subidas controladas."
Campus coordinación,Campus,reps,no,"Patrones con toques, cruces o rombos. Mantén hombros activos y prioriza precisión."
Campus dinámico,Campus,reps,no,"Movimientos explosivos a peldaños altos. Descanso amplio y técnica antes que volumen."
Curl martillo,Fuerza general,reps,si,"Curl con agarre neutro. Controla la bajada y evita balanceos."
Press militar mancuernas,Fuerza general,reps,si,"De pie. Tronco estable, costillas abajo y evita hiperextender la lumbar."
Dominadas con lastre,Fuerza general,reps,si,"Dominadas con carga adicional. Rango completo, escápulas activas y descanso amplio."
Suspensiones peso negativo,Hangboard,seconds,si,"Suspensión con descarga mediante goma, polea o apoyo. Registra ayuda usada y técnica."
Suspensiones con lastre,Hangboard,seconds,si,"Suspensión en regleta con carga adicional. Registra tamaño de canto, tiempo y lastre."
Test de bíceps,Test,reps,si,"Test: curl con mancuernas/barra. Peso máximo para 2–3 reps, sin balanceo."
Test de dominadas con lastre,Test,reps,si,"Test: lastre máximo para 2–3 reps limpias."
Test de dominadas con lastre negativo,Test,reps,si,"Test: lastre máximo controlando la bajada. Registrar lastre y duración de fase excéntrica."
Test de dominadas libres,Test,reps,no,"Test: máximo de reps limpias, sin kipping, rango completo."
Test de hombro,Test,reps,si,"Test: press hombro. Peso máximo para 2–3 reps, tronco estable."
Test de press banca,Test,reps,si,"Test: peso máximo para 2–3 reps con técnica estricta."
Test de hangboard con lastre,Test,seconds,si,"Test: lastre para 45–60s o intento máximo según protocolo. Registrar lastre y tiempo."
Test de suspensiones intermitentes,Test,seconds,si,"Test: 7/3 hasta fallo o nº rondas objetivo."
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
