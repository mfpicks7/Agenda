#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Instala Flutter estable y añádelo al PATH.' >&2; exit 1; }
# Usa la plantilla oficial solo en un directorio temporal. No regenera la app.
agenda_temp="$(mktemp -d)"
trap 'rm -rf "$agenda_temp"' EXIT
flutter create --platforms=android --org com.miagenda --project-name agenda_wrapper "$agenda_temp/agenda_wrapper"
mkdir -p android/gradle/wrapper
for agenda_file in gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar; do
  if [ ! -e "android/$agenda_file" ]; then
    cp "$agenda_temp/agenda_wrapper/android/$agenda_file" "android/$agenda_file"
  fi
done
chmod +x android/gradlew
if [ ! -e android/gradle/wrapper/gradle-wrapper.properties ]; then
  cat > android/gradle/wrapper/gradle-wrapper.properties <<'PROPERTIES'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.10.2-all.zip
PROPERTIES
fi
flutter pub get
printf '%s\n' 'Android preparado. Ejecuta flutter analyze, flutter test y flutter build apk --debug.'
