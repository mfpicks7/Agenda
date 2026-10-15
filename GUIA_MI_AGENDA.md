# Mi Agenda — Android 1.1.0

Calendario mensual compacto desde lunes, con puntos azules para Trabajo y verdes para Personal, selección con borde azul y actividades completas bajo el mes. Cabecera y calendario dentro de una tarjeta blanca. Permite crear y editar actividades, eliminarlas con confirmación y guardar notas y pendientes marcables y ordenables. Persistencia SQLite local mediante Drift. Sin cuentas, servidor, telemetría de la app ni permiso INTERNET.

## Descargar e instalar

1. Abrir [la descarga verificada](https://github.com/mfpicks7/Agenda/actions/runs/38797587112/artifacts/12002393972), iniciando sesión en GitHub si lo pide.
2. Descargar el ZIP y extraer `Mi-Agenda-debug.apk`.
3. Abrir el APK en el teléfono Android. Si Android lo solicita, permitir la instalación desde el navegador o gestor de archivos empleado.

Es una APK de prueba. Los artefactos tienen una retención limitada. Para regenerarla: **Actions → Compilar APK Mi Agenda → Run workflow**, dejando activada la comprobación de arranque.

## Validación realizada

[Compilación y prueba Android correctas](https://github.com/mfpicks7/Agenda/actions/runs/38797587112): análisis sin incidencias, 31 pruebas Flutter correctas, APK compilada e instalada, primer arranque y reapertura correctos en emulador Android 35. También se comprobaron la recepción de avisos inmediato y programado en segundo plano y los estados de permisos denegados. Ver el alcance exacto en VERIFICACION.md. La prueba en el teléfono físico queda pendiente.

## Comprobar en el teléfono

1. Crear tres actividades para el mismo día, con categorías distintas. Comprobar puntos de ambas categorías y lista completa ordenada por hora.
2. Añadir notas y varios pendientes; marcar uno y comprobar que otra actividad no cambia.
3. Cerrar la aplicación y volver a abrir: comprobar que notas, actividades y casillas conservan su estado. El calendario abre en el día actual deliberadamente.
4. Editar título, fecha, hora y categoría. Comprobar los cambios en el calendario.
5. Probar errores con título o pendiente vacío y confirmación al salir de un formulario modificado.
6. Cancelar un borrado y después confirmarlo.

Los datos están en el almacenamiento privado de la aplicación. Desinstalar o borrar sus datos elimina la agenda. El backup automático Android está desactivado; aún no hay exportación. No guardar información irremplazable sin completar primero estas comprobaciones.

## Compilar desde el código

Requisitos: Flutter 3.29.3, JDK 17 y Android SDK con licencias aceptadas. Android mínimo API 23. Desde la raíz:

```bash
bash tool/prepare_android.sh
python3 tool/check_schema.py
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`. El script obtiene solo el wrapper oficial de Gradle en una carpeta temporal, sin regenerar la aplicación. Mantener `pubspec.lock`; el flujo de fuentes verificadas guarda el lock y el formato de la compilación exitosa.

Con un dispositivo/emulador de prueba conectado y `adb` disponible:

```bash
bash tool/android_smoke.sh build/app/outputs/flutter-apk/app-debug.apk
```

El script guarda capturas y registros en `smoke-results/`. Revisar estos archivos antes de compartirlos si se ejecuta con una agenda que contiene datos personales.

## Arquitectura

- `lib/app`: rutas go_router, tema Material 3 y proveedores Riverpod.
- `lib/features/calendar`: calendario y lista diaria.
- `lib/features/activities`: modelo, validación, repositorio, formulario y detalle.
- `lib/core/database/app_database.dart`: Drift/SQLite, esquema versión 2, índices y claves foráneas.
- `test`: pruebas del repositorio, persistencia y widgets.

Drift usa SQL explícito sin código generado. Guardar actividad, tareas y recordatorios es transaccional; el borrado limpia dependencias. Las fechas y horas de E1 son civiles locales. El identificador `com.miagenda.local` es provisional y debe decidirse antes de distribución definitiva.

## Próximas etapas

- E2: repeticiones, excepciones, zona IANA e historial de tareas independiente por ocurrencia, con migración de los datos existentes.
- Recordatorios implementados en 1.1.0 para actividades individuales. Quedan pendientes las repeticiones y su integración con avisos.

Las actividades no se repiten automáticamente. La firma debug es temporal y puede cambiar entre compilaciones de runners distintos; no desinstalar una agenda con datos importantes para resolver un conflicto de firma. Antes de distribuir actualizaciones se necesita una firma estable gestionada de forma segura.

El icono de la versión 1.0.1 utiliza la imagen MF proporcionada por el usuario. Se incluye en el lanzador y en su variante adaptable para Android 8+.

## Pantalla principal 1.0.2

El mes se muestra completo con puntos por categoría. Los nombres aparecen en la lista inferior al tocar una fecha. Tocar Trabajo o Personal en la leyenda filtra la agenda; tocar otra vez la categoría o Todos quita el filtro. El botón Nueva actividad permanece fuera del calendario. Con texto muy ampliado la pantalla permite desplazarse para conservar la legibilidad.

## Avisos de actividades — 1.1.0

1. Crear o editar una actividad y abrir **Avisos** en el formulario.
2. Elegir uno o varios anticipos: al comenzar, 5, 15 o 30 minutos, 1 hora o 1 día antes. **Otra antelación** permite indicar minutos. Se admiten hasta ocho avisos por actividad.
3. Guardar y permitir las notificaciones cuando Android lo solicite.
4. Abrir la campana **Avisos** del calendario. Comprobar que indique **Notificaciones permitidas** y pulsar **Activar precisión de avisos** para autorizar alarmas exactas. Sin esa autorización se usa horario aproximado y se muestra un aviso.
5. Pulsar **Probar aviso ahora**. Con precisión habilitada, también puede probarse una notificación en diez segundos, saliendo de la app.

Las actividades existentes conservan sus datos y empiezan sin avisos: hay que editarlas y elegirlos. Una actividad sin anticipos seleccionados no genera notificaciones. Para todo el día se puede elegir una hora de aviso; inicialmente es 09:00. Los anticipos ya pasados se omiten.

La actividad guarda la zona horaria del teléfono al configurar su primer aviso. Una hora inexistente durante un cambio de horario se rechaza; si se repite, se usa el primer instante. Editar o eliminar una actividad vuelve a sincronizar sus avisos. Tocar una notificación de actividad abre su detalle.

La campana muestra permisos, zona, cantidad de avisos futuros y errores de programación. Permite abrir los ajustes del teléfono y volver a sincronizar. Android puede retrasar avisos aproximados. El ahorro de batería, un canal silenciado o No molestar pueden impedir el sonido. Forzar la detención bloquea alarmas hasta abrir la app de nuevo. La configuración incluye restauración tras reiniciar Android; la entrega después de un reinicio físico y el comportamiento de fabricantes concretos requieren pruebas en el teléfono.

Si Android rechaza la actualización por una firma diferente, **no desinstalar si hay datos importantes**: la firma debug es temporal y todavía no existe exportación de la agenda.

## Conflicto de firmas y recuperación — 1.1.1

Si la actualización da conflicto con un paquete y hay datos que conservar, no desinstalar la agenda. La APK separada `Mi-Agenda-Recuperacion.apk` usa el identificador `com.miagenda.recuperacion` y puede coexistir con la anterior. Desde la campana → Respaldo y recuperación se puede seleccionar el TXT original de aShellYou, comprobar su integridad y restaurarlo únicamente en una agenda vacía. Ver [procedimiento completo](RECUPERACION.md). También permite guardar copias SQLite consistentes con el selector de documentos del teléfono, sin Shizuku.
