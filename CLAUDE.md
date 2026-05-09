# Xkala — Contexto maestro

## Producto

Xkala es una app iOS (SwiftUI + SwiftData) para escaladores centrada en:
- seguimiento de progreso
- análisis histórico
- estadísticas
- gráficos
- tests
- import/export

Prioridad:
> entender evolución real del escalador, no solo registrar entrenamientos.

# Stack

- SwiftUI
- SwiftData local
- ModelContainer manual
- Sin CloudKit
- Persistencia real local

# Flujo IA

- Cursor → implementación
- Claude → código/refactors/debug
- ChatGPT → arquitectura/producto
- Engram → memoria persistente

Responder siempre:
- incremental
- verificable en iPhone
- sin rediseños grandes innecesarios

# Principios arquitectura

- NO persistir estadísticas ni PRs
- métricas siempre derivadas
- separar:
  - persistencia
  - cálculo
  - UI
- evitar lógica compleja en vistas
- usar DTOs/snapshots para UI
- evitar migraciones salvo valor claro
- respetar histórico existente
- cambios pequeños y testeables

# Modelos

## WorkoutDay
- date
- startedAt
- endedAt
- name
- notes
- entries

## Exercise
- name
- category
- mode: reps | seconds
- loadAllowed
- notes
- isArchived

## WorkoutEntry
- exercise
- intensity
- isDone
- entryNotes
- climbKind
- climbIdentifier
- climbGradeColor
- sets

## SetRecord
- reps
- seconds
- loadKg

# Dominio

## Reglas Exercise
- mode ∈ {reps, seconds}
- reps ↔ mode == reps
- seconds ↔ mode == seconds
- tiempo UI = mm:ss
- loadKg solo si loadAllowed

## Reglas progreso
- criterio conservador
- ignorar placeholders/sets inválidos
- evitar métricas ambiguas

## Relaciones
- no romper:
  WorkoutDay → WorkoutEntry → SetRecord
- evitar duplicados Exercise
- isArchived oculta sin borrar

---

# Bloque / Travesía

Modelo:
- ejercicios plantilla:
  - "Bloque"
  - "Travesía"
- NO Exercise por bloque individual

Semántica:
- 1 WorkoutEntry = 1 bloque/travesía real
- completado → isDone
- intentos → SetRecord.reps (1 solo set)

Bloque:
- identifier libre
- color:
  green/yellow/orange/purple

Travesía:
- identifier = A–Z

NO:
- usar intensity como grado
- usar notes como estructura
- múltiples sets innecesarios

---

# Estadísticas

Siempre derivadas.

Calculadoras actuales:
- ExerciseProgressCalculator
- StatsCalculator
- InsightsCalculator

NO persistir:
- métricas
- récords
- agregados

---

# Métricas globales

- entrenos totales
- últimos 30 días
- semana actual
- tiempo total
- categoría favorita
- récords recientes

---

# Récords recientes

Definición:
- última nueva mejor marca histórica real
- recorrido cronológico ascendente
- mejora estricta del máximo acumulado
- empates NO crean nuevo récord
- no mostrar “igualó mejor marca”

Compatibilidad:
- reps
- seconds
- loadKg

Los récords:
- son derivados
- navegan a WorkoutDetailView
- NO se persisten

---

# Insights / Gráficos

Los gráficos globales viven dentro de `ProfileView`.

NO usar gráficos dentro de `ExerciseDetailView`.

## Rangos
- 7D → diario
- 1M → semanal
- 6M → mensual
- 1A → mensual

## Visualización
- Tiempo → LineMark + PointMark
- Sesiones → LineMark + PointMark
- Tipo → doble línea:
  - rocódromo = turquesa
  - roca = amarillo

## UX
- sin scroll horizontal
- estilo tipo Strava
- poco ruido visual
- mobile-first
- labels compactos:
  ENE FEB MAR...

---

# Pantallas

## ContentView
- calendario
- sesiones
- crear workout
- acceso stats/profile/export

## ProfileView
Incluye:
- avatar
- nombre
- altura
- peso
- fecha de nacimiento
- genero, como escalador o escaladora
- insights/gráficos

## StatsView
- estadísticas globales derivadas
- cards simples

## WorkoutDetailView
- lista entries
- añadir ejercicio

## ExerciseDetailView
- editar sets/intensidad
- progreso básico
- mm:ss
- toolbar OK
- editor específico bloque/travesía

## AddExerciseView
- catálogo
- crear ejercicio
- importar CSV

---

# Riesgos clave

- duplicados Exercise
- borrados que rompan histórico
- inconsistencias mode/set
- sets inválidos
- lógica compleja en vistas
- refactors innecesarios SwiftData
- estadísticas ambiguas

---

# UX

- mm:ss
- step tiempo = 5s
- persistencia automática
- claridad > densidad
- progreso > gamificación
- gráficos limpios y legibles

---

# Respuestas esperadas

- cambios mínimos viables primero
- indicar riesgos
- separar fases
- código completo si afecta estructura
- no inventar capas innecesarias
- reutilizar lógica existente
- priorizar pruebas rápidas en iPhone

---

# Si falta contexto

- pedir archivo concreto
- no asumir estructuras
- reutilizar contexto ya conocido