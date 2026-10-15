#!/usr/bin/env bash
# Dispositivo/emulador de prueba: instala una APK, sin borrar datos existentes.
set -euo pipefail
cd "$(dirname "$0")/.."
agenda_apk="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
agenda_package=com.miagenda.local
agenda_component="$agenda_package/.MainActivity"
mkdir -p smoke-results
command -v adb >/dev/null || { echo 'Falta adb (Android platform-tools).' >&2; exit 1; }
[ -f "$agenda_apk" ] || { echo "No existe la APK: $agenda_apk" >&2; exit 1; }
adb wait-for-device
adb install -r "$agenda_apk"
# --pid limita el log al proceso de la app, sin recoger datos de otras apps.
adb shell am force-stop "$agenda_package"
adb shell am start -W -n "$agenda_component" > smoke-results/primer-arranque.txt
sleep 8
agenda_pid="$(adb shell pidof -s "$agenda_package" | tr -d '\r')"
[ -n "$agenda_pid" ] || { echo 'La app se cerró tras el arranque.' >&2; exit 1; }
adb logcat --pid="$agenda_pid" -d -s AndroidRuntime:E flutter:E > smoke-results/errores-arranque.txt
if rg -q 'FATAL EXCEPTION|Unhandled Exception|Error while opening database' smoke-results/errores-arranque.txt; then
  echo 'El arranque registró un error. Revisar smoke-results/errores-arranque.txt.' >&2
  exit 1
fi
adb shell dumpsys activity activities > smoke-results/actividad.txt
rg 'mResumedActivity.*com\.miagenda\.local|topResumedActivity.*com\.miagenda\.local' smoke-results/actividad.txt
adb exec-out screencap -p > smoke-results/primer-arranque.png
# Comprueba que el archivo SQLite se creó y sobrevive a cerrar/reabrir.
# run-as funciona para la build debug; solo lista el archivo, sin leer datos personales.
adb shell run-as "$agenda_package" ls -l files/mi_agenda.sqlite > smoke-results/base-de-datos.txt
adb shell am force-stop "$agenda_package"
adb shell am start -W -n "$agenda_component" > smoke-results/segundo-arranque.txt
sleep 5
agenda_pid="$(adb shell pidof -s "$agenda_package" | tr -d '\r')"
[ -n "$agenda_pid" ] || { echo 'La app se cerró tras reabrir.' >&2; exit 1; }
adb logcat --pid="$agenda_pid" -d -s AndroidRuntime:E flutter:E > smoke-results/errores-reapertura.txt
if rg -q 'FATAL EXCEPTION|Unhandled Exception|Error while opening database' smoke-results/errores-reapertura.txt; then
  echo 'La reapertura registró un error.' >&2
  exit 1
fi
adb exec-out screencap -p > smoke-results/reapertura.png
printf '%s\n' 'Arranque y reapertura comprobados. Esto no sustituye la prueba manual de CRUD y persistencia con actividades.' | tee smoke-results/RESULTADO.txt
