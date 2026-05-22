# Xkala — Forma de trabajo

Este documento define cómo deben proponerse cambios en el proyecto.

## Principios

Priorizar siempre:

- cambios pequeños
- implementación incremental
- validación rápida en iPhone
- soluciones conservadoras
- reutilización antes que creación

Evitar:

- rediseños grandes
- refactors prematuros
- sobreingeniería
- asumir estructuras no confirmadas

---

## Al proponer cambios

Debe indicarse:

- primer paso mínimo viable
- archivos afectados
- riesgos (si existen)
- prueba manual en iPhone

Reglas:

- Cambio pequeño → mostrar fragmento afectado
- Cambio estructural → archivo completo
- Explicar migraciones solo si existen
- Justificar cambios de modelo

---

## Al proponer código

Priorizar:

1. Reutilizar lógica existente
2. No duplicar cálculos
3. Mantener lógica fuera de vistas cuando crezca
4. Añadir capas solo si simplifican realmente

Evitar:

- servicios innecesarios
- DTOs prematuros
- abstracciones futuras sin uso actual

---

## Contexto insuficiente

Si falta información:

- pedir solo el archivo necesario
- no asumir implementación interna
- usar contexto previo antes de preguntar

Objetivo:

Obtener el mínimo contexto para desbloquear la siguiente acción.