# PROMPT PARA CODEX — MI AGENDA / ENTREGA 1

Actúa como ingeniero sénior Flutter/Android y arquitecto de software. Tu misión es **implementar la primera entrega funcional** de una app nueva e independiente llamada **Mi Agenda**, no una maqueta.

## CONTEXTO Y AUTORIDAD

El director del proyecto aprobó este diseño: pantalla principal = calendario mensual, con el nombre abreviado de las actividades escrito dentro de cada día; azul para Trabajo (`#2563EB`), verde para Personal (`#16A34A`). Al elegir un día se muestra la lista detallada. Cada actividad incluye título, categoría, fecha/hora, notas opcionales y lista de pendientes opcional con casillas. La dirección también aprobó múltiples recordatorios, recurrencias configurables y reinicio de tareas por ocurrencia, pero **se implementarán en Entregas 2 y 3**. No presentarlas falsamente como funcionales en Entrega 1.

Lee y sigue `AGENTS.md` y `Mi_Agenda_Especificacion_Tecnica_v1.md` si están en el repositorio. Si no están, utiliza la especificación incluida en este prompt e informa cuáles faltan.

## 0. INSPECCIÓN ANTES DE EDITAR

1. Revisa directorio actual y lista de archivos; comprueba si ya existe proyecto Flutter, el estado de Git, las herramientas Flutter/Dart/Android, las versiones y los tests existentes.
2. Si existe código previo, **no lo sobrescribas** ni elimines funcionalidades. Adapta la implementación de forma incremental. Si la carpeta está vacía, crea un nuevo proyecto Flutter Android llamado `mi_agenda`.
3. No accedas ni alteres ningún proyecto llamado Mi Finanzas IA ni reutilices su identificador, firma, datos o recursos.
4. El identificador Android puede ser provisional y distinto al de cualquier otra app del usuario; documenta que debe decidirse el definitivo antes de distribuir APK release.
5. No inventes resultados de compilación/pruebas. Si no hay SDK, deja el código y los comandos de verificación, indicando el bloqueo.

## 1. TECNOLOGÍAS

Utiliza el SDK Flutter/Dart estable y compatible presente en el entorno. Dependencias preferidas: flutter_riverpod, drift, drift_flutter, sqlite3 según recomendación de drift, go_router, intl y las dependencias de generación de código estrictamente necesarias. Elige versiones compatibles desde pub.dev; no fijes números al azar y conserva `pubspec.lock`.

Estilo: Material 3 personalizado. App en español. Solo Android inicialmente. Sin servidor, Firebase, cuentas, IA, credenciales, anuncios, permisos de internet ni telemetría.

## 2. FUNCIONALIDADES REALES DE ESTA ENTREGA

**Calendario mensual**
- Al abrir la app se ve el mes actual del dispositivo. La semana comienza en lunes.
- Navegación mes anterior/siguiente y botón Hoy.
- Cada celda muestra hasta dos títulos cortos de actividades; si hay más, `+N`.
- Diferenciación cromática accesible de Trabajo y Personal, con etiquetas de texto para no depender solo del color.
- Al pulsar un día, bajo el calendario se muestran todas las actividades de esa fecha, ordenadas por hora; al pulsar una actividad abre el detalle.
- Filtros Todos / Trabajo / Personal, sin modificar la información persistida.

**Crear, consultar, editar y eliminar actividades simples (sin repetición en E1)**
- Formulario con título obligatorio, categoría, fecha, hora opcional/todo el día, notas libres opcionales y lista de pendientes opcional.
- Permitir agregar, editar, eliminar y reordenar pendientes si es sencillo hacerlo de manera estable. Casillas marcables desde detalle, sin cambiar el estado de otras actividades.
- Edición completa de actividad y confirmación antes de eliminar.
- Validaciones de título vacío, fechas/horas inválidas y comportamiento claro ante formularios parcialmente llenos.
- Datos en SQLite mediante Drift, con persistencia real después de cerrar y volver a abrir la aplicación.
- Cambios en UI sincronizados con base de datos, sin recargar manualmente.
- Estados vacíos, manejo de errores y confirmaciones accesibles.

**Diseño UI**
- Respetar pantalla principal aprobada y la combinación azul/verde.
- Encabezado con título Mi Agenda, mes/año, navegación y filtros.
- Calendario legible en teléfonos angostos; truncar nombres visualmente sin alterar su valor guardado.
- Lista de actividades del día bajo el mes, detalle con notas y checklist y botón + visible.
- Tamaños táctiles adecuados, escalado de texto razonable, buena legibilidad y soporte de modo claro. Preparar estilos para modo oscuro sin alteraciones mayores.

## 3. BASE DE DATOS: PREPARAR EVOLUCIÓN SIN PROMETERLA

Crea esquema migrable con tabla Activities y TaskTemplates para esta etapa. Puedes preparar campos de recurrencia, recordatorios y tablas de excepciones como parte de una migración versionada **si no complican ni comprometen E1**; de lo contrario, planifica migración de E2/E3. Usa IDs estables, índices por fecha/categoría, reglas de eliminación claras y transacciones para guardar actividad + tareas. No hagas migraciones destructivas de futuros datos.

La recurrencia posterior será generada por regla y rango acotado, con clave estable de ocurrencia y estados de checklist independientes por fecha. **No implementes una repetición parcialmente funcional como si estuviera terminada.**

## 4. ESTRUCTURA SUGERIDA

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    database/
      app_database.dart
      tables.dart
    utils/
      date_utils.dart
  features/
    calendar/
      presentation/calendar_screen.dart
      presentation/widgets/month_grid.dart
      presentation/widgets/day_activity_list.dart
    activities/
      domain/activity_repository.dart
      data/drift_activity_repository.dart
      presentation/activity_form_screen.dart
      presentation/activity_detail_screen.dart
      presentation/widgets/task_checklist.dart
  shared/
    widgets/
test/
  ...
```

Adapta nombres y carpetas si hay razón técnica. Prefiere organización simple, mantenible y sin archivos innecesarios.

## 5. PRUEBAS QUE DEBES IMPLEMENTAR Y EJECUTAR

- Crear actividad Trabajo y Personal, verificar texto y color en calendario.
- Navegación correcta de meses, lunes como primer día y febrero en año bisiesto.
- Tres actividades en una fecha deben mostrar `+1` más lista de las tres al seleccionar el día.
- Una nota vacía es válida; una nota escrita persiste tras reinicio.
- Agregar varias tareas, marcar una como completada, guardar y recargar: conserva su estado.
- Cambiar fecha, título, hora y categoría debe reflejarse al instante.
- Eliminar con confirmación no debe dejar tareas huérfanas.
- Formularios inválidos deben impedir guardado y explicar el error.
- Widget tests con tamaños de pantalla reducidos y textos largos sin overflow.

Ejecuta donde sea posible: `flutter pub get`, generación Drift apropiada, `dart format .`, `flutter analyze`, `flutter test`, y `flutter build apk --debug`. No declares éxito si alguno no se ejecutó. No modifiques contraseñas ni firmas.

## 6. ENTREGA Y REPORTE FINAL

Entrega código fuente completo y funcional para E1 en el proyecto/repo real. Muestra resumen de archivos creados o cambiados, arquitectura implementada, pruebas corridas y sus resultados, ruta exacta de APK debug **solo si existe**, limitaciones verificadas y pendientes de E2/E3. No publiques ni despliegues nada. Si no hay Android SDK/Flutter, no prometas APK; informa los pasos exactos para compilar.

**Criterio de aceptación:** poder crear una actividad, verla por nombre/color en el calendario, abrir su detalle, editar notas, marcar pendientes, cerrar y reabrir la app y comprobar que todo permanece guardado. Si esto no pasa pruebas, E1 no está terminada.
