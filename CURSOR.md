# Xkala — Contexto maestro

Xkala es una app iOS en SwiftUI + SwiftData para escaladores.

El foco del producto es entender la evolución real del escalador, no solo registrar entrenamientos.

## Stack

- SwiftUI
- SwiftData local
- ModelContainer manual
- Sin CloudKit
- Persistencia real local

## Flujo IA

- Cursor → implementación
- Claude → refactors complejos / debugging profundo
- ChatGPT → arquitectura, producto y validación
- Engram → memoria persistente

## Reglas principales

La fuente detallada vive en:

- `_shared/01-architecture.md`
- `_shared/02-domain-rules.md`
- `_shared/03-swiftdata-safety.md`
- `_shared/04-working-style.md`

Este archivo solo resume el contexto maestro.

Usar los archivos `_shared` como referencia bajo demanda. No repetir su contenido en respuestas salvo que sea necesario para justificar una decisión.

## Principios no negociables

- Preservar histórico existente
- Evitar duplicados de Exercise
- No persistir estadísticas, récords ni agregados derivados
- Evitar migraciones salvo justificación clara
- Separar persistencia, cálculo y UI
- Mantener lógica compleja fuera de vistas
- Priorizar cambios pequeños y verificables en iPhone real

## Dominio clave

- Exercise.mode ∈ `reps | seconds`
- `reps` y `seconds` no se mezclan
- `loadKg` solo si `loadAllowed == true`
- Tiempo en UI: `mm:ss`
- `isArchived` oculta sin borrar
- Bloque y Travesía usan ejercicios plantilla, no un Exercise por ruta
- Métricas ambiguas → interpretación conservadora

## Respuesta esperada

- Incremental
- Operativa
- Sin rediseños grandes innecesarios
- Sin inventar capas
- Pidiendo solo contexto imprescindible