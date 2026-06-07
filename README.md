# Xkala

App iOS para escaladores centrada en registrar entrenamientos y entender la evolución del rendimiento.

Desarrollada con **SwiftUI** y **SwiftData**, Xkala permite registrar sesiones de entrenamiento, ejercicios y métricas de forma rápida durante el entrenamiento.

El objetivo del proyecto es evolucionar desde un simple registro de entrenamientos hacia una herramienta que ayude al escalador a visualizar su progreso, detectar mejoras y tomar mejores decisiones de entrenamiento.

<p align="center">
  <img src="screenshots/home.png" width="250">
  <img src="screenshots/sessions.png" width="250">
  <img src="screenshots/progress.png" width="250">
</p>

## Funcionalidades actuales

- creación de entrenamientos
- catálogo de ejercicios
- ejercicios por repeticiones o tiempo
- soporte opcional para carga (kg)
- registro de series, intensidad y notas
- estadísticas básicas de progreso
- persistencia local con SwiftData

## Roadmap

Próximas líneas de trabajo:

- métricas avanzadas de progreso
- evolución histórica
- tests de rendimiento
- exportación e importación de datos
- planificación de entrenamiento
- análisis específico para escalada

## Modelo de datos

La app se basa en cuatro entidades principales:

- WorkoutDay — sesión de entrenamiento
- Exercise — definición del ejercicio
- WorkoutEntry — ejercicio dentro de un entrenamiento
- SetRecord — datos de cada serie

Relación simplificada:

WorkoutDay
└── WorkoutEntry
└── SetRecord

Exercise
└── WorkoutEntry

## Tecnologías

- SwiftUI
- SwiftData
- iOS

## Estado del proyecto

Proyecto personal en desarrollo activo.

Xkala se encuentra actualmente en fase de beta privada mediante TestFlight.

La app ya se utiliza y valida en dispositivo real, con soporte de exportación/importación de datos para preservar el histórico durante la evolución del proyecto.

## Testing en iPhone

Xkala se distribuye actualmente de forma privada mediante TestFlight a un grupo reducido de testers.

Para probarla es necesario recibir una invitación del desarrollador e instalar la app TestFlight en el iPhone.

También puede ejecutarse localmente desde Xcode clonando el repositorio, aunque esta vía está pensada solo para revisión técnica o desarrollo.

## Feedback

Estoy buscando escaladores que quieran probar la app y aportar feedback sobre:

- experiencia de uso
- métricas útiles
- mejoras de producto
- funcionalidades que echan de menos

Las sugerencias e issues son bienvenidos.

## License

Xkala es software source-available.

El código fuente se publica para evaluación, pruebas y feedback.

No se permite redistribución, uso comercial ni creación de trabajos derivados sin autorización expresa del autor.

Copyright © 2026 Alejandro Laso Gómez. All rights reserved.

## Autor

Alejandro Laso Gómez

GitHub: @ben16dev

## Feedback

Estoy buscando escaladores que quieran probar la app y aportar feedback sobre:

- experiencia de uso
- métricas útiles
- mejoras de producto
- funcionalidades que echan de menos

Las sugerencias e issues son bienvenidos.