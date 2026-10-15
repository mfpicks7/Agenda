# AGENTS.md — Proyecto Mi Agenda

## Misión
Construir **Mi Agenda**, app Android Flutter local-first para organizar actividades de Trabajo (azul) y Personal (verde). Mantener el calendario mensual con nombres de actividades como pantalla principal. La fuente de requisitos es `Mi_Agenda_Especificacion_Tecnica_v1.md`.

## Principios innegociables
- Funciones reales antes que prototipos visuales. No simular persistencia, alarmas ni repeticiones como si fueran reales.
- No borrar ni sobrescribir proyectos, cambios de usuario, funciones existentes o credenciales sin autorización.
- **Mi Agenda es un proyecto independiente de Mi Finanzas IA**: no utilizar su nombre, firma, `applicationId`, datos ni repositorio.
- En cada fase implementa solo su alcance; deja el resto documentado, sin botones activos engañosos.
- No agregar Firebase, cuentas, servicios de pago, publicidad, telemetría ni permiso INTERNET sin una necesidad aprobada.
- Proteger los datos locales y no registrar notas o contenidos personales en logs.
- Usar paquetes compatibles con el SDK disponible y respetar el `pubspec.lock`.
- Mantener `flutter analyze`, `flutter test` y pruebas en Android; reportar únicamente ejecución comprobada.

## Arquitectura
- Flutter + Material 3; Riverpod para estado; Drift/SQLite para datos; go_router para navegación.
- Separar UI, controladores/casos de uso, repositorios y plataforma.
- Usar transacciones al modificar actividad más tareas y recordatorios.
- No generar ocurrencias repetitivas ilimitadas en base de datos: expandir rangos acotados y conservar excepciones y estados por ocurrencia.
- Clave estable de ocurrencia original para checklist independiente; no copiar estados completados hacia futuras repeticiones.
- Zona horaria IANA, horas civiles locales y notificaciones programadas por instante calculado; cubrir horario de verano.
- Comprobar permisos Android antes de avisos exactos, con alternativa clara cuando estén denegados.

## Diseño aprobado
- Inicio: calendario mensual comenzando lunes, 7 columnas, texto abreviado en cada día, hasta 2 actividades + `+N`.
- Trabajo `#2563EB`, Personal `#16A34A`.
- Seleccionar día -> lista de actividades; tocar actividad -> detalle con notas, pendientes, recordatorios y repetición cuando estén implementados.
- Botón + -> formulario con título, fecha, hora, categoría y notas/pendientes opcionales; añadir funciones extra por etapas.
- UI en español, adaptable, accesible, con estados vacíos y errores informativos.

## Flujo de trabajo Codex
1. Inspeccionar archivos, dependencias, rama, estado Git y pruebas existentes antes de editar.
2. Explicar el objetivo y alcance de la etapa sin modificar decisiones aprobadas.
3. Implementar componentes reutilizables, validaciones y migraciones versionadas cuando corresponda.
4. Añadir pruebas del comportamiento nuevo y ejecutar los comandos disponibles.
5. Informar archivos modificados, pruebas realmente ejecutadas, errores, permisos faltantes y siguientes pasos.
6. No afirmar APK instalada, firmada o probada si no existe evidencia.

## Entregas
- E1: calendario + CRUD + notas + checklist + persistencia.
- E2: motor de recurrencia + excepciones + estados independientes.
- E3: recordatorios múltiples + Android permisos + pruebas + APK candidata.

## Convenciones sugeridas
- Código Dart en inglés, UI y documentación de usuario en español.
- Identificadores estables (UUID), nombres claros, evitar duplicación.
- Tests junto a responsabilidades, especialmente fechas, checklist y persistencia.
- `applicationId` provisional exclusivo de Mi Agenda; definir ID definitivo antes del release.
