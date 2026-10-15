# Verificación de Mi Agenda E1

Compilación verificada el 15 de octubre de 2026 en GitHub Actions:
https://github.com/mfpicks7/Agenda/actions/runs/38686848942

Commit de la aplicación: `aa87db74c0c5adde7b8f86b778bdcaf06ba7e7ae`.

## Resultados comprobados

- Flutter 3.29.3, Dart 3.7 y JDK 17 en runner Ubuntu.
- Resolución de dependencias: correcta. Se conserva el `pubspec.lock` generado con el artefacto y en el repositorio mediante el flujo de fuentes verificadas.
- `dart format lib test`: ejecutado.
- `flutter analyze`: **No issues found**.
- `flutter test --reporter expanded`: **11 pruebas pasaron**. Incluyen validación, CRUD, transacción fallida con rollback, estados independientes por actividad, reapertura de archivo SQLite con notas y tareas, calendario bisiesto, semana desde lunes, +N, filtros y texto ampliado en 320 px.
- `flutter build apk --debug`: correcto.
- Emulador Android 35 x86_64: instalación correcta, proceso vivo y actividad en primer plano, ausencia de los errores de arranque revisados, archivo SQLite creado, cierre forzado y reapertura correctos. Se guardaron capturas y registros de ambas aperturas.
- Verificación Python sobre el SQL real: persistencia, restricciones, rollback y cascada correctos. Sintaxis Bash y XML comprobadas localmente.

## Descarga

[APK debug, lock, checksum y código verificado](https://github.com/mfpicks7/Agenda/actions/runs/38686848942/artifacts/11950068074)

Dentro del ZIP: `Mi-Agenda-debug.apk`. Artefactos de GitHub disponibles hasta el 29 de octubre de 2026. Se puede generar una nueva compilación desde Actions.

## Límites de la evidencia

La prueba de Android automatiza instalación, arranque y reapertura con SQLite. El CRUD se probó mediante widgets y repositorio; no se automatizó el flujo completo de crear y modificar actividades mediante toques en el emulador. No se ha probado en el teléfono físico del usuario, ni en otras versiones de Android. Conviene realizar la lista manual de aceptación de GUIA_MI_AGENDA.md en el teléfono antes de guardar información importante.

La APK es debug y usa el identificador provisional `com.miagenda.local`. No hay firma de distribución ni publicación de release. E2 (recurrencia) y E3 (recordatorios) siguen fuera de esta primera entrega.

## Historial de correcciones

El entorno local carece de Flutter/Android SDK y su proxy no conecta. Se resolvió compilando en GitHub. El primer análisis encontró errores Dart que fueron corregidos. La primera comprobación Android se detuvo porque no había `rg` en el runner; el script usa ahora `grep` y la ejecución indicada arriba terminó correctamente.
