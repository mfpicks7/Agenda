# Agenda

Mi Agenda: aplicación Android local para actividades de Trabajo y Personal.

[Descargar APK de prueba 1.1.0](https://github.com/mfpicks7/Agenda/actions/runs/38797587112/artifacts/12002393972) · [Guía de instalación y uso](GUIA_MI_AGENDA.md) · [Resultados de verificación](VERIFICACION.md)

Análisis sin incidencias, 31 pruebas Flutter correctas y arranque/reapertura y recepción de avisos inmediato y programado comprobados en emulador Android 35. Dentro del ZIP de descarga está `Mi-Agenda-debug.apk`.

La versión 1.1.0 incluye calendario, actividades, notas y checklist persistentes, además de recordatorios múltiples con permisos Android. Las repeticiones quedan pendientes.

Versión **1.0.1 (2)**: icono MF proporcionado por el usuario, con recursos por densidad e icono adaptable Android.

Versión **1.0.2 (3)**: calendario compacto según la referencia del usuario, mes completo visible, puntos por categoría y lista detallada debajo. El botón de crear queda fuera del calendario.

Versión **1.1.0 (4)**: avisos configurables por actividad, notificaciones locales, pantalla de permisos y pruebas de aviso inmediato o en diez segundos. Abrir la campana **Avisos** y permitir las notificaciones. Las actividades anteriores necesitan editarse para elegir sus avisos.

[Descargar Mi Agenda Recuperación 1.1.1](https://github.com/mfpicks7/Agenda/actions/runs/38814688023/artifacts/12011080142).

Versión **1.1.1 (5)**: respaldo SQLite consistente, lectura del TXT original de aShellYou, vista previa y restauración transaccional solo en agendas vacías. Incluye una APK separada **Mi Agenda Recuperación** para conservar instalada la agenda anterior ante un conflicto de firmas. Ver [recuperación sin desinstalar](RECUPERACION.md).
