# Xkala — Seguridad de datos y SwiftData

Este documento define riesgos que deben evitarse antes de implementar cambios.

## Riesgos críticos

### Histórico

Evitar:

- Borrados que rompan relaciones existentes
- Pérdida de entrenamientos históricos
- Cambios de modelo sin necesidad real
- Migraciones evitables

Prioridad:

Preservar siempre datos existentes.

---

### Duplicados

Evitar:

- Crear `Exercise` duplicados
- Importaciones que multipliquen ejercicios equivalentes
- Referencias distintas para el mismo ejercicio lógico

Impacto:

Estadísticas erróneas, progreso fragmentado.

---

### Relaciones

Debe mantenerse:

```text
WorkoutDay
 └── WorkoutEntry
      └── SetRecord
```

Evitar:

- Relaciones huérfanas
- Cascadas no deseadas
- Referencias inconsistentes

---

### Sets inválidos

Evitar:

- mezclar `reps` y `seconds`
- usar `loadKg` cuando `loadAllowed == false`
- guardar datos incompatibles con `Exercise.mode`
- persistir placeholders como datos reales

Impacto: métricas incorrectas y progreso ambiguo.

---

### Estadísticas

Evitar:

- Persistir estadísticas derivadas
- Persistir récords
- Persistir agregados
- Calcular métricas desde datos ambiguos

Regla: las métricas deben derivarse del histórico.

---

### Arquitectura

Evitar:

- lógica compleja en vistas
- duplicación de cálculos
- capas innecesarias
- refactors grandes sin beneficio claro

---

## Regla final

Si una solución evita tocar SwiftData, migrar modelos o modificar persistencia, esa solución tiene prioridad.