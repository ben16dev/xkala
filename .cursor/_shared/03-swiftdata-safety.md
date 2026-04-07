# Xkala — Seguridad SwiftData

## Riesgos a vigilar
- Duplicados de Exercise por importación o creación manual.
- Borrados que rompan histórico o relaciones.
- Inconsistencias entre Exercise.mode y SetRecord.
- Sets con datos inválidos o mezclados.
- Estadísticas incorrectas por usar ejercicios duplicados o sets vacíos.
- Refactors que compliquen innecesariamente SwiftData.
- Cálculos de progreso hechos dentro de vistas de forma poco reutilizable.
- Crear múltiples Exercise para bloques o travesías concretos en lugar de usar ejercicios plantilla.
- Mezclar la semántica de intensity con el grado/color de Bloque.
- Exponer editor genérico de sets en Bloques/Travesías y terminar persistiendo múltiples sets innecesarios.

## Reglas de seguridad
- Antes de proponer borrados, revisar impacto en histórico.
- Antes de proponer cambios de modelo, justificar por qué no basta una solución derivada.
- Antes de usar métricas agregadas, validar que no dependen de datos ambiguos o inconsistentes.
- Evitar soluciones que multipliquen referencias o creen duplicados silenciosos.