# Xkala — Reglas de dominio

Estas reglas definen el significado de los datos y cómo deben interpretarse.

## Exercise

Reglas:

- `mode ∈ { reps, seconds }`
- Si `mode == reps` → usar `SetRecord.reps`
- Si `mode == seconds` → usar `SetRecord.seconds`
- `reps` y `seconds` nunca se mezclan
- `loadKg` solo tiene sentido si `loadAllowed == true`
- `isArchived` oculta ejercicios sin borrar histórico

## SetRecord

Interpretación:

- `reps = nil` → no aplica
- `seconds = nil` → no aplica
- `loadKg = nil` → sin carga
- Tiempo en UI → formato `mm:ss`
- Valores ambiguos → interpretación conservadora

## Relaciones

Debe mantenerse:

```text
WorkoutDay
 └── WorkoutEntry
      └── SetRecord
```

Reglas:

- No romper histórico
- No crear referencias inconsistentes
- No mezclar datos reales con placeholders sin justificar

---

## Ejercicios Bloque / Travesía

Modelo:

- Son ejercicios plantilla
- NO crear un `Exercise` nuevo por bloque/travesía real
- Ejercicios base: `Bloque`, `Travesía`

Semántica:

- 1 `WorkoutEntry` = 1 bloque real
- 1 `WorkoutEntry` = 1 travesía real
- completado → `WorkoutEntry.isDone`
- intentos → `SetRecord.reps`
- usar un único `SetRecord`

Restricciones:

- **Bloque:** `climbIdentifier` → texto libre; `climbGradeColor ∈ { green, yellow, orange, purple }`
- **Travesía:** `climbIdentifier ∈ { A...Z }`

No usar:

- `intensity` como grado
- `entryNotes` como estructura persistente
- múltiples sets innecesarios

---

## Métricas y progreso

Siempre derivadas.

Reglas:

- No persistir estadísticas
- No persistir récords (PRs)
- No persistir agregados
- Ignorar sets inválidos
- Ignorar placeholders
- Priorizar interpretación conservadora ante datos ambiguos

---

## Récords recientes

Definición:

- Nueva mejor marca histórica real
- Cronología ascendente
- Mejora estricta del máximo acumulado
- Empates NO generan nuevo récord

Compatibilidad: `reps`, `seconds`, `loadKg`

Los récords son derivados y no se persisten.