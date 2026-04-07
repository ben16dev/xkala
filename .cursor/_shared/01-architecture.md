# Xkala — Arquitectura

## Objetivo
Xkala es una app iOS para escaladores orientada al seguimiento del progreso, no solo al registro de entrenamientos.

## Stack actual
- SwiftUI
- SwiftData local
- ModelContainer manual en la app
- Sin CloudKit
- Sin almacenamiento en memoria
- Persistencia real local

## Reglas de arquitectura
- No cambiar el modelo SwiftData sin justificación clara.
- No proponer migraciones si no son necesarias.
- No persistir estadísticas derivadas prematuramente.
- Calcular primero métricas y agregados desde los datos actuales.
- Separar lógica de cálculo, lógica de persistencia y lógica de UI.
- Evitar lógica de negocio compleja dentro de las vistas.
- Crear servicios o DTOs solo si ayudan a desacoplar SwiftData de la UI.
- Si una solución puede hacerse sin tocar persistencia, esa opción tiene prioridad.
- Cualquier cambio debe respetar el historial ya guardado.

## Prioridad de implementación
- Favorecer cambios pequeños, seguros y comprobables en iPhone real.
- Evitar refactors grandes de golpe.
- Proponer primero una fase mínima antes de una fase más ambiciosa.