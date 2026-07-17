# Xkala — Arquitectura

La arquitectura principal de Xkala está documentada en:

`.cursor/rules/_shared/01-architecture.md`

Este archivo raíz existe solo como referencia rápida para humanos y para facilitar la navegación del proyecto.

## Principios estables

- SwiftUI + SwiftData local.
- Persistencia real mediante `ModelContainer` manual.
- Sin CloudKit.
- Preservación del histórico como prioridad.
- Métricas, récords y estadísticas siempre derivadas.
- Separación entre persistencia, lógica de cálculo y UI.
- Evolución incremental sin refactors grandes innecesarios.

## Regla práctica

Antes de tocar modelos, persistencia o relaciones SwiftData, revisar:

- `.cursor/rules/_shared/02-domain-rules.md`
- `.cursor/rules/_shared/03-swiftdata-safety.md`