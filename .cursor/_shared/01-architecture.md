# Xkala — Arquitectura

Este documento define principios técnicos estables del proyecto.

## Objetivo

Xkala busca entender la evolución del escalador, no solo registrar entrenamientos.

La arquitectura debe favorecer:

- preservación de histórico
- métricas fiables
- evolución incremental
- simplicidad

---

## Persistencia

Stack actual:

- SwiftData local
- ModelContainer manual
- Persistencia real
- Sin CloudKit

Reglas:

- No cambiar modelos sin justificación clara
- Evitar migraciones innecesarias
- Respetar histórico existente
- Priorizar soluciones que no requieran tocar persistencia

---

## Estadísticas y progreso

Regla principal:

Todo debe calcularse desde datos existentes.

No persistir:

- estadísticas
- récords
- agregados
- métricas derivadas

Ejemplos actuales:

- `ExerciseProgressCalculator`
- `StatsCalculator`
- `InsightsCalculator`

---

## Separación de responsabilidades

Priorizar separación entre:

```text
Persistencia
↓
Lógica cálculo
↓
UI

Evitar:

lógica compleja en vistas
cálculos duplicados
persistencia dentro de UI
UI y datos

Preferencias:

vistas reciben datos derivados cuando tenga sentido
snapshots / DTOs solo si simplifican
evitar capas innecesarias
Estrategia de implementación

Prioridad:

Cambio mínimo viable
Seguridad datos
Test rápido en iPhone
Evolución futura sin complejidad extra

Evitar: refactors grandes, rediseños prematuros, sobreingeniería