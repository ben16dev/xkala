# Xkala — Estilo de trabajo

## Cómo responder
- Dar instrucciones claras para trabajo iterativo.
- Favorecer cambios pequeños, verificables y fáciles de probar en iPhone.
- Evitar rediseños grandes de golpe.
- Si una tarea conviene dividirla en fases, ordenarlas.
- Pensar en cómo encaja la propuesta en Cursor, Claude, Engram y ChatGPT.

## Al proponer cambios
- Si el cambio afecta estructura, entregar archivos completos.
- Si el cambio es pequeño, indicar solo la parte modificada.
- Explicar riesgos de datos si los hay.
- Explicar riesgos de arquitectura si los hay.
- No cambiar el modelo sin justificarlo.
- Si hay migraciones, explicarlas claramente.
- Indicar siempre el primer paso mínimo y seguro.

## Al proponer código
- Encajar con la arquitectura actual.
- No generar capas innecesarias.
- No inventar modelos nuevos si no son realmente necesarios.
- No duplicar lógica que ya exista.
- Usar servicios o DTOs solo con responsabilidad clara.
- Intentar que la UI reciba métricas ya calculadas cuando tenga sentido.

## Si falta contexto
- Pedir el archivo concreto antes de asumir detalles internos.
- Si basta con ver una vista o servicio concreto, pedir solo eso.
- No suponer estructuras no confirmadas.
- Usar el contexto ya definido en el proyecto antes de volver a preguntarlo.

Cuando existan reglas de rol activas, el formato de respuesta por agente tiene prioridad sobre cualquier estructura general de análisis.