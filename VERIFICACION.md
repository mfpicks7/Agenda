# Verificación realizada

## Ejecutado con éxito en este entorno

- `python3 tool/check_schema.py`: comprobó el SQL extraído de `app_database.dart`, creación del esquema, persistencia tras reapertura de SQLite, rollback transaccional, restricciones de título/categoría/hora y eliminación en cascada sin huérfanos.
- `bash -n tool/prepare_android.sh`: sintaxis válida del script de preparación.
- Lectura de los XML Android con el analizador XML de Python: válida.
- Revisión del manifiesto: sin permisos de Internet, notificaciones ni alarmas.

## Bloqueado, sin resultados atribuidos

Los comandos `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` y `flutter build apk --debug` se intentaron y no pudieron iniciarse: no están instalados Flutter/Dart. Tampoco se detectó Android SDK. El intento de descarga de Flutter falló por conexión al proxy y el intento posterior fue interrumpido. Una consulta posterior a pub.dev confirmó que el proxy seguía inaccesible.

Las pruebas Dart/Flutter están escritas, pero **no ejecutadas**. Las restricciones de paquetes y la configuración Gradle requieren resolución y verificación en un equipo preparado. No existe `pubspec.lock`, APK, prueba en emulador ni evidencia de instalación. La validación SQLite con Python no verifica la integración Drift, el renderizado ni el ciclo de vida Android.

## Estado de aceptación

La implementación de E1 está preparada en código. La aceptación funcional de E1 permanece pendiente hasta completar los comandos y la prueba en Android detallada en README.md. E2 y E3 no están implementadas, conforme al alcance del kit inicial. No se ha publicado ni desplegado el proyecto.

## Continuación: ruta de compilación preparada

- Añadido `.github/workflows/android-apk.yml`: ejecución manual, Flutter 3.29.3/JDK 17, análisis, tests, compilación debug, artefacto APK+lock+checksum y prueba opcional de arranque Android 35.
- Añadido `tool/android_smoke.sh`: instalación, primer arranque, existencia de SQLite, reapertura y capturas. No sustituye la aceptación manual del CRUD.
- Corregido cierre de los streams del repositorio al cerrar el controlador de cambios.
- Reejecutados con éxito: comprobación SQL y sintaxis Bash de ambos scripts. El workflow fue leído como YAML para comprobar su estructura.
- La red volvió a fallar al conectar con `proxy:8080`. No hay SDK instalado ni un repositorio de Mi Agenda accesible mediante la conexión GitHub actual. El workflow y el script de Android no se han ejecutado. Sigue sin existir APK.
