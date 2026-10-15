# Recuperar una agenda sin desinstalar la anterior

La APK **Mi-Agenda-Recuperacion.apk** instala **Mi Agenda Recuperación**, con paquete `com.miagenda.recuperacion`. Es distinta de la agenda anterior `com.miagenda.local` y puede coexistir con ella. No intenta eludir las firmas Android ni modificar los datos de otra aplicación.

[Descargar APK de recuperación](https://github.com/mfpicks7/Agenda/actions/runs/38814688023/artifacts/12011080142). Descargar el ZIP, extraer e instalar `Mi-Agenda-Recuperacion.apk`.

1. Conservar la agenda anterior y el TXT original de aShellYou. La extracción con `run-as` requiere una compilación debug y permisos ADB; no sustituye una exportación normal.
2. Descargar la APK del artefacto **Mi-Agenda-Recuperacion** de una ejecución verificada e instalarla.
3. Abrir **Mi Agenda Recuperación**, tocar la campana y entrar en **Respaldo y recuperación**.
4. Pulsar **Seleccionar respaldo** y elegir el TXT de aShellYou desde Descargas. También admite SQLite o Base64 limpio (máximo 16 MB).
5. Revisar el número de actividades y tareas. La comprobación de integridad, migración y validación se realiza en una copia temporal; el documento elegido se mantiene intacto.
6. Pulsar **Restaurar en esta agenda vacía** y confirmar. Si la agenda ya tiene actividades, tareas o avisos, la operación se rechaza sin reemplazarlos. Todas las inserciones pertenecen a una única transacción.
7. Comprobar fechas, horas, notas y estados de pendientes en el calendario; cerrar y abrir la app. La agenda anterior debe seguir instalada durante la comprobación.
8. Usar **Guardar copia de esta agenda** para generar un SQLite consistente mediante el selector de documentos Android.
9. Configurar avisos y permisos desde la campana. Los recordatorios de un respaldo v2 se vuelven a programar; los registros de notificaciones del otro paquete no se copian. Un respaldo v1 no tiene avisos.

La firma de estas candidatas debug sigue siendo temporal; no se garantiza una actualización sobre otra compilación. El respaldo/importación permite conservar datos independientemente de la firma, pero antes de distribución definitiva hace falta una clave estable guardada de forma segura. No se han publicado claves en el repositorio ni se ha preparado un release.

Al terminar las pruebas con Shizuku se puede revocar la autorización de aShellYou, detener Shizuku, desactivar depuración inalámbrica y volver a dejar apagado **Deshabilitar monitoreo de permisos** en ColorOS si se activó durante la extracción.

Los datos personales del usuario no se incluyen en el código, los artefactos de CI ni los ejemplos. La prueba Android utiliza una base sintética con notas y tareas ficticias.
