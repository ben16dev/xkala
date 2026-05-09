# Xkala — Contexto maestro del proyecto

Xkala es una app iOS desarrollada en SwiftUI + SwiftData para escaladores.

La app ya no se define solo como una herramienta para registrar entrenamientos: está evolucionando hacia una app orientada al seguimiento del progreso, con estadísticas, gráficas, métricas por ejercicio, tests, e importación/exportación de datos.

## Tu función

- Proponer cambios coherentes con la arquitectura actual.
- No reinventar la estructura si no es necesario.
- Respetar el modelo de datos existente mientras no haya una razón clara para modificarlo.
- Detectar riesgos típicos de SwiftData (duplicados, relaciones, borrados, referencias).
- Mantener consistencia con decisiones ya tomadas.
- Priorizar soluciones incrementales, seguras y fáciles de validar en dispositivo real.
- Pensar en evolución de producto, no solo en generación de código.
- Proponer fases pequeñas y comprobables antes de meterse en refactors grandes.

## Método de trabajo actual

El desarrollo de Xkala se hace con este flujo:

- Cursor: implementación y edición del proyecto.
- Claude: análisis, propuesta técnica, refactors y generación de código.
- Engram: memoria persistente del proyecto y de las decisiones tomadas.
- ChatGPT: apoyo de arquitectura, roadmap, revisión crítica y validación de decisiones.

Por tanto, cuando respondas:

- Da instrucciones claras para trabajo iterativo.
- Favorece cambios pequeños, verificables y fáciles de probar en iPhone.
- Evita proponer grandes rediseños de golpe.
- Si una tarea conviene dividirla en fases, hazlo.
- Piensa en cómo encajará la propuesta en Cursor, Claude y Engram.
- Da prioridad a código que pueda probarse rápido en un clon antes de consolidarlo en el proyecto principal.

## Arquitectura actual

### Persistencia
- SwiftData local
- ModelContainer manual en XkalaApp
- No CloudKit
- No almacenamiento en memoria
- Modelo persistente real

## Modelos

### WorkoutDay
- date: Date
- notes: String
- entries: [WorkoutEntry]

### Exercise
- name: String
- category: String
- mode: "reps" o "seconds"
- loadAllowed: Bool
- notes: String
- isArchived: Bool

### WorkoutEntry
- exercise: Exercise
- intensity: Int
- isDone: Bool
- entryNotes: String
- climbKind: String?        // "block" | "traverse"
- climbIdentifier: String?  // bloque: número o texto libre; travesía: A–Z
- climbGradeColor: String?  // solo bloque: "green" | "yellow" | "orange" | "purple"
- sets: [SetRecord]

### SetRecord
- reps: Int?
- seconds: Int?
- loadKg: Double?

## Visión de producto

Xkala es una app para escaladores orientada al seguimiento del progreso.

Debe permitir:
- Registrar entrenamientos
- Gestionar ejercicios
- Analizar evolución por ejercicio
- Mostrar estadísticas y gráficas
- Guardar y consultar resultados de tests
- Importar y exportar datos
- Mantener histórico fiable y útil para análisis

La prioridad del producto es entender la evolución del escalador, no solo verificar si ha cumplido un plan de entrenamiento.

## Reglas obligatorias de dominio

- Exercise.mode solo puede ser "reps" o "seconds".
- Si mode == "reps", usar reps en SetRecord.
- Si mode == "seconds", usar seconds en SetRecord.
- El tiempo en UI debe mostrarse en formato mm:ss.
- loadKg solo tiene sentido si loadAllowed == true.
- No romper relaciones WorkoutDay → WorkoutEntry → SetRecord.
- Evitar duplicados de Exercise, especialmente en reimportación o creación manual.
- isArchived se usa para ocultar ejercicios sin borrarlos.
- No mezclar progreso real con datos vacíos o placeholders sin justificarlo.
- Si una métrica depende de datos ambiguos, priorizar interpretación conservadora.

### Reglas obligatorias para Bloque y Travesía
- Bloques y Travesías se modelan como ejercicios plantilla, no como Exercise independientes por instancia.
- Los ejercicios base son "Bloque" y "Travesía".
- 1 WorkoutEntry = 1 bloque real o 1 travesía real.
- En Bloque y Travesía, el completado se guarda en WorkoutEntry.isDone.
- En Bloque y Travesía, los intentos se guardan en SetRecord.reps usando un único SetRecord.
- En Bloque, climbIdentifier admite número o texto libre.
- En Travesía, climbIdentifier debe ser una única letra A–Z.
- En Bloque, climbGradeColor solo puede ser: "green", "yellow", "orange", "purple".
- No reutilizar intensity para representar el grado/color de Bloque.
- No usar entryNotes como fuente principal de datos estructurados de Bloques/Travesías.

## Reglas obligatorias de arquitectura

- No cambiar el modelo SwiftData sin justificación clara.
- No proponer migraciones si no son necesarias.
- No persistir agregados o estadísticas prematuramente.
- Primero calcular estadísticas derivadas desde los datos actuales.
- Separar lógica de cálculo, lógica de persistencia y lógica de UI.
- Evitar meter lógica de negocio compleja directamente en las vistas.
- Crear servicios o DTOs cuando ayuden a desacoplar SwiftData de la UI.
- Si una solución puede hacerse sin tocar persistencia, esa opción tiene prioridad en fases tempranas.
- Cualquier cambio debe respetar el historial ya guardado.
- Priorizar DTOs derivados para la UI de estadísticas.
- Las estadísticas globales (`StatsView`) van separadas del análisis por ejercicio en `ExerciseDetailView`.
- Mantener compatibilidad SwiftData sin migraciones cuando se añadan métricas.
- Evitar métricas ambiguas; si hay duda, criterio conservador y copy claro.

## Estadísticas

- Existe `StatsView` (acceso desde `ContentView`); muestra agregados globales.
- Las estadísticas son **siempre derivadas** en tiempo de ejecución a partir de `WorkoutDay` / entradas / sets.
- **No persistir** métricas agregadas ni récords (PRs) en SwiftData.
- Usar calculadoras puras: `StatsCalculator` (globales), `ExerciseProgressCalculator` (progreso y récords por ejercicio).
- Evitar lógica compleja en vistas: la UI recibe snapshots / DTOs ya calculados.

## Métricas actuales (globales en `StatsView`)

- Entrenos totales (histórico).
- Entrenos últimos 30 días.
- Entrenos en la semana actual (calendario del dispositivo).
- Tiempo total entrenado (solo sesiones con `startedAt` y `endedAt` válidos y coherentes).
- Categoría favorita (derivada de entradas completadas; criterio conservador ante empates).
- Récords recientes (ver definición siguiente).
- En la misma pantalla suele mostrarse también el conteo de **ejercicios completados** (entradas con `isDone`), siempre derivado.

## Récords recientes

Definición correcta del hito mostrado por ejercicio:

- Representan la **última** vez que hubo una **nueva mejor marca histórica real** (mejora estricta respecto al máximo acumulado hasta entonces).
- Recorrer el histórico en **orden cronológico** (antiguo → reciente).
- La **primera** vez que se alcanza un nivel en un grupo comparable cuenta como referencia inicial; los **empates posteriores** con ese máximo **no** crean un nuevo récord.
- No mostrar estados neutros tipo «igualó mejor marca» en esta sección.
- Reutilizar la misma semántica que `ExerciseProgressCalculator` para **reps**, **seconds** y **loadKg** (incl. intermitentes en regleta cuando aplique).
- **No persistir** PRs; todo sale de `latestStrictPersonalRecord` / lógica derivada.

## Riesgos clave a vigilar

- Duplicados de Exercise por importación o creación manual.
- Borrados que rompan histórico o relaciones.
- Inconsistencias entre mode y SetRecord.
- Sets con datos inválidos o mezclados.
- Estadísticas incorrectas por usar ejercicios duplicados o sets vacíos.
- Refactors que compliquen innecesariamente SwiftData.
- Cálculos de progreso hechos dentro de vistas de forma poco reutilizable.
- Mezclar edición de entreno con análisis histórico sin estructura clara.
- Crear múltiples Exercise para bloques o travesías concretos en lugar de usar ejercicios plantilla.
- Mezclar la semántica de intensity con el grado/color de Bloque.
- Exponer editor genérico de sets en Bloques/Travesías y terminar persistiendo múltiples sets innecesarios.

## Estado actual de pantallas

### ContentView
- Calendario + sesiones del día seleccionado; navegación a detalle de sesión
- Acceso a `ProfileView`, `StatsView` y exportación JSON desde la barra superior
- Crea nuevas sesiones en la fecha seleccionada (FAB «Nuevo»)

### StatsView
- Estadísticas globales derivadas (cards simples, sin gráficos en el MVP actual)
- Sin lógica de cálculo pesada en la vista; consume `GlobalStatsSnapshot` vía `StatsCalculator`

### WorkoutDetailView
- Lista WorkoutEntry
- Añadir ejercicio

### AddExerciseView
- Filtra catálogo
- Permite crear ejercicio manual
- Reimporta CSV

### ExerciseDetailView
- Edita intensidad
- Edita sets
- Tiempo en formato mm:ss
- Step +/- tiempo = 5s
- Botón OK global en toolbar teclado
- Actualmente ya puede mostrar progreso básico del ejercicio
- Para "Bloque" y "Travesía" usa editor específico:
  - sin intensidad
  - sin editor de sets
  - Bloque: identificador, color, intentos, completado
  - Travesía: identificador A–Z, intentos, completado

## Decisiones UX importantes

- Tiempo visible como mm:ss
- Step de tiempo en incrementos de 5 segundos
- Un único botón OK en keyboard toolbar
- Persistencia automática SwiftData
- Catálogo importado desde CSV
- La app debe sentirse útil para escaladores, no solo correcta técnicamente
- La UX debe priorizar comprensión de progreso y claridad de métricas
- Pantalla de estadísticas: **simple y legible**, pocas métricas por vista, **poco ruido visual** (cards claras, sin sobrecarga)

## Forma de responder

Cuando propongas cambios:

- Si el cambio afecta estructura, entrega archivos completos.
- Si el cambio es pequeño, indica solo la parte modificada.
- Explica riesgos de datos si los hay.
- Explica riesgos de arquitectura si los hay.
- No cambies el modelo sin justificarlo.
- Si propones migraciones, explícitalas claramente.
- Si una propuesta tiene varias fases, ordénalas.
- Indica cuál sería el primer paso mínimo y seguro.
- Prioriza propuestas que puedan probarse rápido en iPhone antes de consolidarlas.

## Cuando propongas código

- El código debe encajar con la arquitectura actual.
- No generes capas innecesarias.
- No inventes modelos nuevos si no son realmente necesarios.
- No dupliques lógica que ya exista en el proyecto.
- Si usas servicios, que tengan responsabilidades claras.
- Si usas DTOs o structs auxiliares, que ayuden a desacoplar la UI del modelo persistente.
- Si una vista necesita métricas, intenta que reciba datos ya calculados en vez de calcular todo dentro.
- Piensa siempre en mantenibilidad, simplicidad y evolución gradual.

## Contexto de trabajo con IA

- Claude y Cursor se usan para implementar.
- Engram se usa para recordar decisiones y contexto del proyecto.
- ChatGPT se usa como apoyo estratégico y de revisión.

Por eso, al responder:
- Sé preciso.
- Sé conservador con cambios delicados.
- Favorece pasos pequeños.
- Ayuda a tomar decisiones, no solo a escribir código.
- Si una propuesta es buena pero no es oportuna todavía, dilo.
- Si algo debería hacerse más adelante, indícalo claramente.

## Si falta contexto

- Pide el archivo concreto antes de asumir detalles internos.
- Si basta con ver una vista o servicio concreto, pide solo eso.
- No supongas estructuras no confirmadas.
- Si el contexto ya existe en estas reglas o en la conversación, úsalo y no vuelvas a pedirlo.