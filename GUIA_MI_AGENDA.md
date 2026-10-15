# Mi Agenda — Android 1.0.2

Calendario mensual compacto desde lunes, con puntos azules para Trabajo y verdes para Personal, selección con borde azul y actividades completas bajo el mes. Cabecera y calendario dentro de una tarjeta blanca. Permite crear y editar actividades, eliminarlas con confirmación y guardar notas y pendientes marcables y ordenables. Persistencia SQLite local mediante Drift. Sin cuentas, servidor, telemetría de la app ni permiso INTERNET.

## Descargar e instalar

1. Abrir [la descarga verificada](https://github.com/mfpicks7/Agenda/actions/runs/38751233453/artifacts/11981647476), iniciando sesión en GitHub si lo pide.
2. Descargar el ZIP y extraer `Mi-Agenda-debug.apk`.
3. Abrir el APK en el teléfono Android. Si Android lo solicita, permitir la instalación desde el navegador o gestor de archivos empleado.

Es una APK de prueba. Los artefactos caducan el 29 de octubre de 2026. Para regenerarla: **Actions → Compilar APK Mi Agenda → Run workflow**, dejando activada la comprobación de arranque.

## Validación realizada

[Compilación y prueba Android correctas](https://github.com/mfpicks7/Agenda/actions/runs/38751233453): análisis sin incidencias, 21 pruebas Flutter correctas, APK compilada e instalada, primer arranque y reapertura correctos en emulador Android 35. Ver el alcance exacto en VERIFICACION.md. La prueba en el teléfono físico queda pendiente.

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
- `lib/core/database/app_database.dart`: Drift/SQLite, esquema versión 1, índices y claves foráneas.
- `test`: pruebas del repositorio, persistencia y widgets.

Drift usa SQL explícito sin código generado. Guardar actividad y tareas es transaccional; el borrado limpia dependencias. Las fechas y horas de E1 son civiles locales. El identificador `com.miagenda.local` es provisional y debe decidirse antes de distribución definitiva.

## Próximas etapas

- E2: repeticiones, excepciones, zona IANA e historial de tareas independiente por ocurrencia, con migración de los datos existentes.
- E3: múltiples recordatorios, permisos Android, programación, reinicios y pruebas de entrega de notificaciones.

La primera APK no ofrece alarmas ni repetición. La firma debug es temporal y puede cambiar entre compilaciones de runners distintos; no desinstalar una agenda con datos importantes para resolver un conflicto de firma. Antes de distribuir actualizaciones se necesita una firma estable gestionada de forma segura.

El icono de la versión 1.0.1 utiliza la imagen MF proporcionada por el usuario. Se incluye en el lanzador y en su variante adaptable para Android 8+.

## Pantalla principal 1.0.2

El mes se muestra completo con puntos por categoría. Los nombres aparecen en la lista inferior al tocar una fecha. Tocar Trabajo o Personal en la leyenda filtra la agenda; tocar otra vez la categoría o Todos quita el filtro. El botón Nueva actividad permanece fuera del calendario. Con texto muy ampliado la pantalla permite desplazarse para conservar la legibilidad.
