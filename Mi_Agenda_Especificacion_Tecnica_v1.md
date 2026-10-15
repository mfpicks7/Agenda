# Mi Agenda — Especificación técnica v1.0

**Proyecto:** Mi Agenda (independiente de Mi Finanzas IA)
**Estado:** diseño UI/UX aprobado; arquitectura propuesta; desarrollo aún no iniciado.
**Plataforma inicial:** Android; enfoque local-first y sin conexión obligatoria.
**Objetivo:** agenda personal para organizar compromisos laborales y personales, con calendario mensual como portada.

## 1. Decisiones aprobadas por la dirección del proyecto

1. Pantalla principal: calendario mensual con **nombres abreviados de actividades escritos dentro de las celdas**.
2. Actividades de **Trabajo** en azul y **Personal** en verde.
3. Al tocar un día se muestran sus actividades, con acceso a una vista detallada.
4. Cada actividad admite **múltiples recordatorios configurables**.
5. Campo de **notas libres opcionales**.
6. **Lista de pendientes opcional**, con casillas marcables y progreso.
7. Repeticiones configurables: diaria, semanal, mensual, anual y personalizada.
8. Cada ocurrencia de una actividad repetitiva **reinicia sus casillas** y mantiene independiente el historial de las ocurrencias anteriores.
9. Diseño visual de referencia aprobado, con interfaz limpia, tarjetas discretas y calendario como foco principal.

**Alcance técnico derivado de lo anterior:** edición/borrado, persistencia en dispositivo, funcionamiento fuera de línea, permisos de notificación y edición de una ocurrencia o una serie. Son implementaciones necesarias o recomendaciones de ingeniería; cualquier variación visual mayor requiere aprobación.

## 2. Stack propuesto

- **Flutter / Dart:** compilación Android (con posibilidad de migrar a iOS en el futuro).
- **Material 3:** tema personalizado, accesibilidad y diseño adaptable.
- **Riverpod:** estado de pantalla y sincronización reactiva de datos.
- **SQLite + Drift / drift_flutter:** almacenamiento local, consultas, migraciones y pruebas.
- **go_router:** rutas de calendario, formulario y detalle.
- **rrule:** motor de reglas de recurrencia; encapsularlo tras una interfaz propia y usar la técnica de fecha/hora civil, no asumir que la librería maneja zonas horarias.
- **flutter_local_notifications, timezone y flutter_timezone:** avisos locales programados con zona horaria y permisos de Android.
- **intl:** localización de fechas y números al español.

Seleccionar versiones compatibles con el Flutter SDK instalado, fijar resultados en `pubspec.lock` y revisar instrucciones vigentes de cada biblioteca antes de programar.

Documentación:
- https://docs.flutter.dev/
- https://pub.dev/packages/drift
- https://pub.dev/packages/flutter_riverpod
- https://pub.dev/packages/go_router
- https://pub.dev/packages/rrule
- https://pub.dev/packages/flutter_local_notifications
- https://developer.android.com/about/versions/14/changes/schedule-exact-alarms

## 3. Capas y flujo

```text
Flutter: calendario / formulario / detalle
       ↓
Controladores Riverpod + validaciones de caso de uso
       ↓
Repositorios de actividades, tareas y recordatorios
       ↓
SQLite (Drift)                 Android Notificaciones
       ↑                                ↑
Motor de recurrencia ─── planificador de recordatorios
```

- SQLite es la fuente de verdad: la notificación del sistema **no** equivale a un registro guardado.
- Las operaciones compuestas se hacen en transacciones.
- Ninguna pantalla llama directamente a SQL ni a APIs Android.
- No introducir backend, login, API de IA, analytics ni publicidad en esta versión.

## 4. Modelo de datos conceptual

### Activities
`id (UUID)`, `title`, `category (work|personal)`, `startLocalDate`, `startLocalTime nullable`, `endLocalTime nullable`, `isAllDay`, `timeZoneId (IANA)`, `notes nullable`, `recurrenceRule nullable`, `repeatEndDate nullable`, `createdAt`, `updatedAt`.

Las horas se interpretan como **hora civil local** asociada a `timeZoneId`. Guardar además los instantes calculados al programar notificaciones, sin reemplazar la definición civil del evento.

### TaskTemplates
`id`, `activityId`, `description`, `sortOrder`. Es la lista maestra que se muestra inicialmente en cada ocurrencia.

### OccurrenceTaskStates
`activityId`, `originalOccurrenceKey`, `taskTemplateId`, `isDone`, `completedAt nullable`.

Clave compuesta única por actividad + ocurrencia original + tarea. El estado de lunes 19 **jamás** afecta a lunes 26. En ocurrencias sin estados, todas las casillas inician desmarcadas. Mantener datos completados si se edita una serie, salvo autorización expresa para eliminarlos.

### Reminders
`id`, `activityId`, `offsetMinutes`, `enabled`; admite varios avisos por actividad y evita offsets duplicados para una misma actividad. Minutos de antelación relativos al inicio; 0 = al comenzar.

### OccurrenceOverrides
`activityId`, `originalOccurrenceKey`, `isCancelled`, `overriddenData` (campos editables claramente tipados o parche serializado versionado), `updatedAt`.

La `originalOccurrenceKey` es un identificador determinista de la **fecha y hora originales de la regla**; se conserva aunque la ocurrencia se mueva de día. No generar registros infinitos para una recurrencia sin fin. Para listar un mes: expandir el intervalo acotado, aplicar excepciones y considerar ocurrencias movidas hacia dentro o fuera del intervalo.

### ScheduledNotificationRegistry (cuando corresponda)
`notificationId int único`, `activityId`, `originalOccurrenceKey`, `reminderId`, `scheduledInstantUTC`, `status`.

Permite cancelar/reprogramar un aviso concreto y controlar colisiones de identificadores.

## 5. Reglas funcionales importantes

- Crear/editar/eliminar una actividad refleja el cambio en calendario y detalle sin reiniciar la app.
- Nombres largos se abrevian visualmente, pero el nombre completo nunca se pierde en datos.
- Si hay más de dos actividades por día, mostrar dos y una leyenda `+N`; debajo del calendario se muestran todas.
- Una actividad puede no tener nota ni tareas ni recordatorios.
- Una tarea de una fecha ya completada mantiene su estado cuando se abre otra fecha.
- La edición de una sola ocurrencia no modifica toda la serie; las cancelaciones individuales quedan en excepciones.
- Para un evento mensual fijado el día 31, los meses sin día 31 se **omiten**, sin mover silenciosamente la actividad al 30, salvo política futura aprobada.
- Fechas inexistentes y horas no válidas deben mostrar errores claros; no guardar datos corruptos.
- Preferir zona horaria IANA y tratar cambios de horario de verano con pruebas. `rrule` requiere una capa de adaptación explícita; no convertir ingenuamente todas las reglas a UTC real.
- Al borrar una actividad, pedir confirmación; limpiar datos dependientes y notificaciones pendientes según el alcance elegido.

## 6. Notificaciones Android

- Solicitar `POST_NOTIFICATIONS` en Android 13+ cuando sea necesario, con contexto y sin bloquear el resto de la agenda.
- Programar localmente usando `zonedSchedule` y la zona horaria del evento/dispositivo según la regla definida.
- Para alarmas exactas, comprobar permiso real antes de usarlas. Emplear `SCHEDULE_EXACT_ALARM` con solicitud explícita si es apropiado; **no** declarar `USE_EXACT_ALARM` sin confirmar elegibilidad de política de distribución.
- Si falta el permiso, ofrecer configuración y alternativa inexacta con aviso visible de que la entrega puede retrasarse. Nunca afirmar garantía de precisión.
- Reprogramar cuando se edita, cancela o elimina una actividad, cambia la zona horaria o se reinicia el teléfono; atender receptores/permisos siguiendo documentación oficial.
- Para recurrencias sin fecha de fin, usar planificación acotada y un mecanismo confiable de reposición. El trabajo periódico de Android puede demorarse; documentar límites reales y pruebas de horizonte largo antes de dar la función por comprobada.
- Los cuerpos de notificación no deben incluir notas sensibles completas de forma predeterminada.

## 7. Diseño y accesibilidad

- Azul trabajo: `#2563EB`; verde personal: `#16A34A`. Fondos y texto con contraste accesible.
- Encabezado con mes/año, navegación anterior/siguiente y botón Hoy.
- Celdas de 7 columnas, empezando lunes, con 2 títulos cortos como máximo y `+N`.
- Resumen del día seleccionado bajo el calendario; botón destacado `+ Nueva actividad`.
- Pantallas: Calendario, Crear/Editar actividad, Detalle de actividad, Ajustes mínimos de avisos/permisos cuando corresponda.
- Soportar tamaños estrechos, texto escalado, modo claro y `Semantics` para lector de pantalla.
- Sin botones decorativos que aparenten funciones inexistentes.

## 8. Plan de trabajo y criterios de cierre

### Entrega 1 — Base funcional local
- Proyecto Flutter Android, diseño de calendario, creación/edición/eliminación de actividades simples, detalle, notas, checklist y persistencia SQLite.
- Pruebas de UI, reinicio de app, categoría, fechas, validaciones y checklist.
- Avisos y repeticiones quedan documentados como **pendientes**, no simulados como funcionalidades completas.

### Entrega 2 — Recurrencia real
- Diaria/semanal/mensual/anual/personalizada, fechas límite, excepciones individuales, tareas reiniciadas por ocurrencia e historial preservado.
- Pruebas de fechas límite, saltos de mes/año, diferentes zonas horarias y edición de una ocurrencia versus serie.

### Entrega 3 — Notificaciones y APK candidata
- Múltiples avisos por actividad, programación/reprogramación local, permisos, reboots, denegaciones, notificaciones de repetición, pruebas de instalación y actualización.
- APK debug para pruebas; APK release únicamente con firma/credenciales gestionadas correctamente y sin exponer secretos.

## 9. Pruebas obligatorias

- `flutter analyze` y `flutter test` deben ejecutarse donde exista SDK.
- Unitarias: modelos, validación, motor de recurrencia, listas independientes por ocurrencia, migraciones.
- Widgets: navegación de meses, selección de días, etiquetas por color, overflow `+N`, formulario y detalle.
- Integración: persistencia tras cerrar y reabrir, transacciones y ediciones.
- Android real/emuladores: 13/14/15+ según entorno disponible; notificaciones con permisos concedidos/denegados y app cerrada.
- Probar cambios de hora, cambio de fecha del dispositivo, reinicio, batería restrictiva y registros largos.
- No declarar ninguna prueba como pasada sin evidencia de ejecución.

## 10. Estado actual

- Requisitos y UI de referencia: **aprobados**.
- Arquitectura: **propuesta técnica lista para implementar**, sujeta a comprobación del entorno real.
- Código de Mi Agenda: **no implementado en esta conversación**.
- Pruebas/compilaciones/APK: **no realizadas**.
