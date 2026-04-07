# Xkala — Reglas de dominio

## Exercise
- Exercise.mode solo puede ser "reps" o "seconds".
- Si mode == "reps", SetRecord debe usar reps.
- Si mode == "seconds", SetRecord debe usar seconds.
- El tiempo en UI debe mostrarse en formato mm:ss.
- loadKg solo tiene sentido si Exercise.loadAllowed == true.
- isArchived se usa para ocultar ejercicios sin borrarlos.

## Relaciones
- No romper la relación WorkoutDay → WorkoutEntry → SetRecord.
- No mezclar progreso real con placeholders o datos vacíos sin justificarlo.
- Si una métrica depende de datos ambiguos, priorizar interpretación conservadora.

## Bloque y Travesía
- Bloques y Travesías se modelan como ejercicios plantilla, no como Exercise independientes por instancia.
- Los ejercicios base son "Bloque" y "Travesía".
- 1 WorkoutEntry = 1 bloque real o 1 travesía real.
- En Bloque y Travesía, el completado se guarda en WorkoutEntry.isDone.
- En Bloque y Travesía, los intentos se guardan en SetRecord.reps usando un único SetRecord.
- En Bloque, climbIdentifier admite número o texto libre.
- En Travesía, climbIdentifier debe ser una única letra A–Z.
- En Bloque, climbGradeColor solo puede ser "green", "yellow", "orange" o "purple".
- No reutilizar intensity para representar el grado/color de Bloque.
- No usar entryNotes como fuente principal de datos estructurados de Bloques/Travesías.