# Mi Agenda — Entrega 1

Proyecto Android Flutter independiente, con calendario mensual desde lunes, Trabajo azul y Personal verde, filtros, hasta dos títulos por día y contador +N, lista del día, CRUD, notas y pendientes ordenables. SQLite local mediante Drift; Riverpod sincroniza las pantallas y go_router gestiona las rutas. No necesita cuentas ni servidor. El manifiesto no solicita INTERNET.

## Estado de la entrega

Código de E1 implementado y pruebas preparadas. **E1 aún no está validada para uso:** este entorno no tiene Flutter/Dart ni Android SDK. No se han ejecutado `flutter analyze`, `flutter test` ni una compilación Android. No hay APK. Tampoco se ha verificado el cierre/reinicio en un dispositivo. El proxy de red del entorno rechaza las conexiones, por lo que no fue posible instalar el SDK.

Las restricciones de dependencias del pubspec son de líneas conocidas compatibles con Dart >=3.6; no se pudo consultar pub.dev ni resolverlas aquí. **No existe pubspec.lock**: se generará con `flutter pub get`, se debe conservar en control de versiones y verificar antes de distribuir. No se inventó un archivo lock sin resolución real.

## Generar el APK en GitHub Actions

La raíz del repositorio debe contener `pubspec.yaml`, `lib`, `android` y `.github`; no subir el ZIP cerrado ni colocar todo dentro de otra carpeta. Usar un repositorio independiente llamado, por ejemplo, `mi-agenda`.

1. Subir el contenido de este proyecto, incluidos los archivos ocultos `.github/workflows/android-apk.yml` y `.gitignore`.
2. Abrir **Actions → Compilar APK Mi Agenda → Run workflow**. El flujo usa Flutter 3.29.3 y JDK 17, prepara Gradle, resuelve dependencias, analiza y prueba antes de compilar.
3. Dejar marcada la comprobación de arranque Android si se desea ejecutar el segundo trabajo en un emulador Android 35.
4. Si el trabajo de compilación termina correctamente, descargar el artefacto **Mi-Agenda-APK-debug**. Contendrá `Mi-Agenda-debug.apk`, su SHA-256, `pubspec.lock`, versión de Flutter y código resuelto. Los artefactos caducan a los 14 días.
5. Revisar también el trabajo de arranque: el APK puede existir aunque la prueba de emulador falle. El artefacto de arranque contiene capturas y registros para revisar. No declarar la app probada en Android si ese trabajo falla o se omite.

El flujo solo se ejecuta manualmente; no publica releases ni crea una firma de distribución. La firma debug del runner es temporal y puede cambiar entre compilaciones; para actualizar una instalación anterior con otra firma será necesaria una estrategia de firma estable antes de distribuir. No desinstalar una app con datos importantes para resolver un conflicto de firma.

La compilación remota **está preparada, pero aún no se ha ejecutado**. Necesita que el proyecto esté en un repositorio de GitHub con Actions habilitado. Las acciones de terceros utilizadas son `subosito/flutter-action` y `reactivecircus/android-emulator-runner`, además de las acciones oficiales de checkout, Java y artefactos.

## Preparar y verificar en un equipo con Flutter

Requisitos: Flutter estable con Dart >=3.6, Android SDK con licencias aceptadas, JDK 17 y conexión para descargar dependencias. Android mínimo 6 (API 23). Primero ejecuta `flutter doctor -v` y resuelve los avisos Android.

Desde la raíz del proyecto:

```bash
bash tool/prepare_android.sh
# Genera solo el wrapper Gradle desde una plantilla oficial temporal,
# sin regenerar ni sobrescribir el código de la aplicación.
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

El script no requiere build_runner: el esquema Drift usa SQL explícito, sin archivos generados. El wrapper usa Gradle 8.10.2, AGP 8.7.3 y Kotlin 2.1.0; verificar esta combinación con el Flutter instalado. `flutter build` genera la configuración local del SDK; no compartir `android/local.properties`. Si la versión instalada requiere una actualización de Gradle/AGP, realizarla y volver a ejecutar todas las verificaciones.

Solo después de una compilación exitosa, el APK estará en `build/app/outputs/flutter-apk/app-debug.apk`. Instalar en un dispositivo de prueba mediante `flutter install --debug` o `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

## Comprobación en Android antes de aceptar E1

1. Crear tres actividades para el mismo día, con categorías distintas; comprobar nombres, colores, +1 y lista completa ordenada por hora.
2. Añadir notas y varios pendientes; marcar solo uno y comprobar que otra actividad no cambia.
3. Cerrar la aplicación desde recientes y volver a abrirla: comprobar notas, pendientes y selección de categoría guardados. La selección del calendario vuelve al día actual deliberadamente.
4. Editar título, fecha, hora y categoría; volver al calendario y comprobar los cambios.
5. Intentar guardar títulos y pendientes vacíos; comprobar errores. Salir de un formulario cambiado debe pedir confirmación.
6. Cancelar un borrado y luego confirmarlo. Comprobar que no quedan tareas de esa actividad.
7. Probar pantalla estrecha, texto ampliado, meses con 28/29/30/31 días y cambio de año.

## Arquitectura y datos

- `lib/app`: router, temas y proveedores.
- `lib/features/calendar`: calendario y lista diaria.
- `lib/features/activities`: modelo, validación, repositorio, formulario y detalle.
- `lib/core/database/app_database.dart`: Drift/SQLite, esquema versión 1, índices y claves foráneas.
- `test`: pruebas de repositorio (incluida reapertura real de archivo SQLite), transacciones y widgets.
- `tool/check_schema.py`: comprobación independiente del SQL real con SQLite de Python; no equivale a probar la app Flutter.

El guardado de actividad más tareas usa transacción; una colisión revierte todo. IDs UUID. El checklist de E1 corresponde a una actividad simple. El orden y los estados se conservan al editar. Los datos viven en el directorio privado de soporte de la app. El backup automático Android está desactivado; desinstalar o borrar datos del sistema elimina la agenda. No hay exportación ni cifrado adicional en esta fase.

Fechas y horas se guardan como valores civiles locales; E1 no programa instantes. La zona IANA y los estados por ocurrencia se incorporarán con una migración versionada en E2, sin reinterpretar silenciosamente los datos existentes. No hay registros de notas personales en logs.

## Pendientes fuera del alcance E1

- **E2:** motor de recurrencia acotado, excepciones, zona IANA, checklist independiente por ocurrencia y migración del estado simple de E1. Las fechas mensuales inexistentes se omitirán según la especificación.
- **E3:** recordatorios múltiples, permisos Android, planificación y cancelación, reinicios, zonas horarias, pruebas reales en Android 13/14/15+ y APK candidata.
- Firma de release e identificador definitivo: `com.miagenda.local` es provisional. No se incluyen firmas ni credenciales. No publicar sin definir identidad definitiva y verificar la app.

No se muestran botones de repetición o alarma porque estas funciones aún no están implementadas.

## Comprobar un APK en un emulador o teléfono de prueba

Con un único dispositivo conectado y depuración USB autorizada:

```bash
bash tool/android_smoke.sh build/app/outputs/flutter-apk/app-debug.apk
```

El script instala sin borrar datos, comprueba que el proceso sigue vivo y en primer plano, detecta errores de arranque, comprueba la existencia de SQLite y reabre la app. Guarda capturas y resultados en `smoke-results/`. No crea actividades ni certifica el CRUD: completar la lista manual anterior. Requiere `adb` y `rg` en PATH. Los registros y capturas pueden contener información de la agenda si se ejecuta sobre un dispositivo con datos; revisarlos antes de compartirlos.
