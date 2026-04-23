#!/bin/bash
# Script para crear las épicas de Gazu en GitHub
# Uso: ./scripts/create-issues.sh
# Requiere: gh CLI autenticado (gh auth login)
# Instalar gh CLI: https://cli.github.com/

set -e

REPO="HECTORGMHM/gazuproyecto"

create_issue_if_not_exists() {
  local title="$1"
  local body="$2"
  local search="$3"
  [ -z "$search" ] && search="$title"

  echo "Verificando: $title"
  EXISTS=$(gh issue list --repo "$REPO" --state open --search "$search" --json title --jq ".[].title" 2>/dev/null | grep -F "$search" || true)

  if [ -z "$EXISTS" ]; then
    gh issue create --repo "$REPO" --title "$title" --label "enhancement" --body "$body"
    echo "✅ Creado: $title"
  else
    echo "⏭️  Ya existe: $title"
  fi
}

echo "======================================"
echo "Creando épicas del proyecto Gazu..."
echo "======================================"

create_issue_if_not_exists "Épica: Catálogo de servicios" \
"## Contexto
Sistema para que los negocios gestionen su oferta de servicios y los clientes puedan ver, buscar y filtrar los servicios disponibles.

## User Story
Como cliente, quiero poder ver y filtrar el catálogo de servicios de un negocio, para elegir el servicio que mejor se adapta a mis necesidades y presupuesto.

## Criterios de aceptación
**Flujo normal:**
- Given un cliente que accede a un negocio, When navega al catálogo, Then ve la lista de servicios disponibles con nombre, duración, precio e imagen.
- Given un propietario autenticado, When agrega o edita un servicio, Then los cambios se reflejan en tiempo real en el catálogo.
- Given un cliente, When aplica filtros (precio, duración, categoría), Then solo se muestran servicios que coinciden.

**Errores:**
- When un servicio está inactivo, Then no aparece disponible para reserva.
- When la imagen no carga, Then se muestra un placeholder apropiado.

## Tareas técnicas
**Flutter:** Pantalla de catálogo con lista/grid, filtros por categoría/precio/duración, detalle de servicio, carga de imágenes con caché.
**Firestore:** Colección \`services\` (nombre, descripción, duración, precio, categoría, estado, imageUrl, businessId). Índices para filtrado.
**Cloud Functions:** Validación de datos al crear/editar servicio, actualización de contadores.
**Firebase (Storage):** Subida y gestión de imágenes de servicios.

## Consideraciones técnicas
- Usar streams de Firestore para actualizaciones en tiempo real.
- Cachear el catálogo localmente para uso offline.

## Edge cases
- Negocio elimina un servicio con citas pendientes.
- Precio de servicio cambia entre selección y confirmación.
- Catálogo vacío (sin servicios activos).

## Prioridad
Alta

## Tipo
Fullstack"

create_issue_if_not_exists "Épica: Sistema de citas" \
"## Contexto
Núcleo funcional de la aplicación. Gestiona todo el ciclo de vida de una cita: creación, confirmación, modificación, cancelación y finalización. Incluye lógica de disponibilidad en tiempo real.

## User Story
Como cliente, quiero reservar una cita con el staff de mi elección para un servicio específico en un horario disponible, para planificar mi visita con anticipación.

## Criterios de aceptación
**Flujo normal:**
- Given un cliente autenticado, When selecciona servicio, staff, fecha y hora disponibles, Then se crea la cita y ambas partes reciben confirmación.
- Given una cita confirmada, When el propietario/staff cambia su estado, Then el cliente es notificado.
- Given una cita pendiente, When el cliente la cancela, Then el slot queda disponible para otros.

**Errores:**
- When dos clientes intentan reservar el mismo slot, Then solo uno tiene éxito y el otro recibe error.
- When el negocio está inactivo (Master Switch off), Then no es posible crear nuevas citas.

## Tareas técnicas
**Flutter:** Pantalla de calendario, selector de staff, confirmación de reserva, historial de citas, pantalla de gestión para propietario/staff.
**Firestore:** Colección \`appointments\` (clientId, staffId, serviceId, businessId, dateTime, status, notes, qrCode). Transacciones para evitar doble reserva.
**Cloud Functions:** Verificación atómica de disponibilidad, trigger al crear/modificar/cancelar cita, limpieza de citas expiradas.
**Firebase:** Reglas de Firestore, integración con FCM para notificaciones.

## Consideraciones técnicas
- Usar transacciones de Firestore para evitar race conditions.
- Manejar zonas horarias correctamente.

## Edge cases
- Staff se enferma y hay que reasignar citas.
- Cliente cancela en el último minuto.
- Cita creada durante interrupción de internet.
- Negocio cambia horarios con citas ya agendadas.

## Prioridad
Alta

## Tipo
Fullstack"

create_issue_if_not_exists "Épica: Gestión de staff" \
"## Contexto
Módulo para administrar el equipo de trabajo: agregar/eliminar empleados, asignar servicios, configurar horarios de disponibilidad y gestionar permisos de acceso.

## User Story
Como propietario de negocio, quiero administrar a mi equipo y sus horarios, para que los clientes puedan reservar citas con el empleado de su preferencia.

## Criterios de aceptación
**Flujo normal:**
- Given un propietario autenticado, When agrega un empleado con su correo, Then el empleado recibe invitación y puede acceder con su rol.
- Given un empleado activo, When el propietario configura su horario, Then ese horario determina los slots disponibles para reservas.
- Given un empleado, When se le asignan servicios, Then solo aparece como opción para esos servicios.

**Errores:**
- When se intenta eliminar staff con citas futuras, Then el sistema advierte y pide confirmación.
- When el correo del staff ya existe, Then se muestra error apropiado.

## Tareas técnicas
**Flutter:** Pantalla de lista y gestión de staff, formulario de alta, configuración de horarios semanales, asignación de servicios, gestión de permisos.
**Firestore:** Colección \`staff\` (userId, businessId, nombre, servicios[], horarios{}, rol, estado, fotoUrl). Subcolección \`schedules\`.
**Cloud Functions:** Envío de invitación por correo, propagación de cambios de horario, validación de conflictos.
**Firebase (Auth):** Custom claims para roles (owner, staff, client).

## Consideraciones técnicas
- Cambios de horario de staff deben propagar al motor de disponibilidad.
- Permisos validados en cliente Y servidor.
- Un usuario puede ser staff de múltiples negocios.

## Edge cases
- Staff con citas activas es dado de baja.
- Conflicto de horarios al asignar turnos superpuestos.
- Staff que no tiene cuenta de Firebase aún.

## Prioridad
Media

## Tipo
Fullstack"

create_issue_if_not_exists "Épica: Experiencia del usuario (flujo de reserva)" \
"## Contexto
Diseño e implementación del flujo completo que experimenta un cliente al buscar un negocio, explorar servicios, seleccionar staff y horario, y confirmar su reserva.

## User Story
Como cliente, quiero un flujo de reserva intuitivo y rápido, para poder agendar mis citas con la menor cantidad de pasos posible.

## Criterios de aceptación
**Flujo normal:**
- Given un cliente en la pantalla principal, When busca un servicio o negocio, Then ve resultados relevantes ordenados por proximidad y calificación.
- Given un cliente que selecciona un negocio, When navega por el flujo de reserva, Then completa la reserva en máximo 4 pasos.
- Given una reserva completada, When accede a Mis citas, Then ve el historial con estado actualizado.

**Errores:**
- When el slot seleccionado ya no está disponible, Then se notifica al cliente y se muestran alternativas.
- When hay error de conexión, Then los datos ingresados se preservan para reintentar.

## Tareas técnicas
**Flutter:** Pantalla de inicio/búsqueda, flujo multi-paso (Stepper), pantalla de confirmación con QR, sección Mis citas, animaciones, deep links.
**Firestore:** Queries optimizados para búsqueda, historial de reservas del cliente.
**Cloud Functions:** Búsqueda full-text de negocios, generación de resúmenes.
**Firebase:** Analytics, Dynamic Links para compartir negocios/servicios.

## Consideraciones técnicas
- Flujo offline-first: guardar borrador de reserva localmente.
- Accessibility: soporte para lectores de pantalla.
- Performance: carga inicial menor a 2 segundos.

## Edge cases
- Cliente en zona sin cobertura intenta hacer reserva.
- Negocio cierra permanentemente con reservas activas.
- Cliente usa la app con VoiceOver/TalkBack.

## Prioridad
Alta

## Tipo
Mobile" "" "Experiencia del usuario"

create_issue_if_not_exists "Épica: Geolocalización y mapa" \
"## Contexto
Integración de capacidades de geolocalización para mostrar negocios cercanos, filtrar por distancia, visualizar en mapa interactivo y calcular tiempos de desplazamiento.

## User Story
Como cliente, quiero ver los negocios disponibles en un mapa cercano a mi ubicación, para elegir el más conveniente según distancia y tiempo de desplazamiento.

## Criterios de aceptación
**Flujo normal:**
- Given un cliente con permisos de ubicación activos, When abre la búsqueda, Then ve un mapa con marcadores de negocios cercanos.
- Given el mapa visible, When el cliente mueve el mapa o cambia el radio, Then los marcadores se actualizan dinámicamente.
- Given un marcador seleccionado, When el cliente toca el negocio, Then ve un resumen con opción de reservar.

**Errores:**
- When el usuario deniega permisos de ubicación, Then la app funciona con búsqueda manual por dirección.
- When no hay negocios en el radio, Then se sugiere ampliar radio.

## Tareas técnicas
**Flutter:** google_maps_flutter, permission_handler, marcadores personalizados, toggle lista/mapa, geocoding, geolocator.
**Firestore:** GeoPoint en documentos de negocios, queries geoespaciales (GeoFlutterFire).
**Cloud Functions:** Búsqueda de negocios por radio geográfico.
**Firebase:** Google Maps API Key por plataforma.

## Consideraciones técnicas
- Manejar consumo de batería por uso de GPS.
- Cachear últimas ubicaciones y negocios consultados.
- Respetar privacidad del usuario.

## Edge cases
- Usuario sin GPS activado.
- Negocio sin coordenadas configuradas.
- Usuario en zona rural sin negocios cercanos.

## Prioridad
Media

## Tipo
Mobile"

create_issue_if_not_exists "Épica: Notificaciones push" \
"## Contexto
Sistema completo de notificaciones push para mantener informados a clientes, staff y propietarios sobre citas, cambios, recordatorios y actualizaciones. Usa Firebase Cloud Messaging (FCM).

## User Story
Como cliente, quiero recibir notificaciones push sobre mis citas (confirmación, recordatorio, cambios), para estar siempre informado sin necesidad de abrir la app.

## Criterios de aceptación
**Flujo normal:**
- Given una cita creada, When se confirma la reserva, Then el cliente recibe notificación push con detalles.
- Given una cita próxima (24h y 1h antes), When llega el tiempo programado, Then el cliente recibe recordatorio automático.
- Given un cambio de estado de cita, When se guarda, Then el cliente afectado recibe notificación inmediata.
- Given un cliente que toca la notificación, When la app abre, Then navega directamente al detalle de la cita.

**Errores:**
- When el token FCM ha expirado, Then el sistema lo actualiza automáticamente.
- When el usuario tiene notificaciones desactivadas, Then la app muestra aviso para habilitarlas.

## Tareas técnicas
**Flutter:** firebase_messaging, permisos iOS/Android, manejo en foreground/background/terminated, deep linking, pantalla de preferencias.
**Firestore:** Tokens FCM por usuario (colección userTokens), preferencias, registro de notificaciones.
**Cloud Functions:** Trigger en cambios de cita, recordatorios programados (Cloud Scheduler), limpieza de tokens inválidos.
**Firebase (FCM):** Configuración Android/iOS, topics para notificaciones grupales.

## Consideraciones técnicas
- Respetar preferencias del usuario.
- Diferencias de permisos iOS vs Android.
- Rate limiting para evitar spam.

## Edge cases
- Usuario con múltiples dispositivos.
- Token FCM cambia al reinstalar la app.

## Prioridad
Media

## Tipo
Backend"

create_issue_if_not_exists "Épica: Check-in con QR" \
"## Contexto
Sistema de confirmación de llegada del cliente al negocio mediante código QR. El cliente presenta un QR único por cita y el staff lo escanea para registrar la asistencia e iniciar el servicio.

## User Story
Como cliente, quiero presentar un código QR al llegar al negocio, para confirmar mi asistencia de forma rápida y sin necesidad de dar datos verbalmente.

## Criterios de aceptación
**Flujo normal:**
- Given una cita confirmada, When el cliente accede al detalle, Then ve un código QR único asociado a esa cita.
- Given el staff con permisos de scanner, When escanea el QR, Then el sistema valida la cita y registra el check-in.
- Given un check-in exitoso, When se registra la llegada, Then el estado cambia a En progreso y ambas partes son notificadas.
- Given el QR escaneado, When la cita es válida, Then el check-in se completa en menos de 2 segundos.

**Errores:**
- When el QR pertenece a una cita cancelada o expirada, Then el scanner muestra error descriptivo.
- When el QR no puede leerse, Then el staff puede ingresar el código manualmente.

## Tareas técnicas
**Flutter:** qr_flutter para generación, mobile_scanner para lectura, pantalla de check-in con feedback visual/sonoro, QR con datos encriptados.
**Firestore:** qrToken único en citas (hash seguro), checkInTime y checkInStaffId, log de check-ins.
**Cloud Functions:** Validación de QR (token, fecha, estado), actualización atómica del estado, generación de tokens seguros.
**Firebase:** Reglas para que solo staff del negocio pueda validar QR.

## Consideraciones técnicas
- Token QR único, no predecible y con expiración.
- Validar QR en servidor, no solo en cliente.
- Soporte para modo offline: cachear QR localmente.

## Edge cases
- Staff intenta escanear el mismo QR dos veces.
- QR de una cita de otro negocio.
- Cliente sin batería (backup: código numérico).

## Prioridad
Media

## Tipo
Mobile"

create_issue_if_not_exists "Épica: Backend con Cloud Functions" \
"## Contexto
Implementación de la lógica de negocio serverless usando Firebase Cloud Functions para operaciones críticas: disponibilidad atómica, notificaciones, cálculo de reputación, validaciones y tareas programadas.

## User Story
Como desarrollador, quiero centralizar la lógica de negocio crítica en Cloud Functions, para garantizar operaciones seguras, atómicas e independientes del cliente móvil.

## Criterios de aceptación
**Flujo normal:**
- Given una operación de reserva, When la Cloud Function se ejecuta, Then verifica disponibilidad y crea la cita de forma atómica en menos de 3 segundos.
- Given un cambio de estado en una cita, When se dispara el trigger, Then la notificación push se envía en menos de 5 segundos.
- Given una función programada, When se ejecuta en el horario configurado, Then completa su tarea y registra resultado en logs.

**Errores:**
- When una función falla por timeout, Then reintenta según la política configurada.
- When recibe datos inválidos, Then retorna error 400 con mensaje descriptivo.

## Tareas técnicas
**Cloud Functions (Node.js/TypeScript):**
- createAppointment: Verifica disponibilidad y crea cita atómicamente.
- onAppointmentStatusChange: Trigger al cambiar estado, envía notificaciones.
- sendReminders: Función programada para recordatorios (Cloud Scheduler).
- validateQRCheckIn: Valida y procesa check-in por QR.
- updateReputationScore: Recalcula puntuación al recibir reseña.
- cleanupExpiredAppointments: Limpieza de citas expiradas.
- onUserDeleted: Limpieza de datos al eliminar usuario (GDPR).
- generateQRToken: Genera token seguro para QR.
- sendPushNotification: Función central de envío de push.

**Firestore:** Estructura optimizada, colección de logs/audit.
**Firebase:** Configuración de entornos (dev/staging/prod), variables de entorno, presupuesto y alertas.

## Consideraciones técnicas
- Usar TypeScript (type safety).
- Retry logic con exponential backoff.
- Optimizar cold starts.
- Tests unitarios para todas las funciones.

## Edge cases
- Múltiples triggers simultáneos para la misma función.
- Timeout en operaciones de Firestore con carga alta.
- Función de limpieza elimina datos que aún se necesitan.

## Prioridad
Alta

## Tipo
Backend"

create_issue_if_not_exists "Épica: Seguridad (Firestore Rules)" \
"## Contexto
Implementación y validación de reglas de seguridad en Firestore para garantizar que cada usuario solo pueda acceder y modificar los datos que le corresponden según su rol. Incluye validaciones de datos y control de acceso granular.

## User Story
Como propietario del sistema, quiero que las reglas de Firestore protejan los datos de cada usuario y negocio, para que ningún actor malicioso pueda acceder o modificar información que no le pertenece.

## Criterios de aceptación
**Flujo normal:**
- Given un cliente autenticado, When intenta leer sus propias citas, Then tiene acceso. When intenta leer citas de otro cliente, Then se deniega el acceso.
- Given un propietario autenticado, When gestiona su negocio, Then puede leer/escribir sus datos. When intenta acceder a datos de otro negocio, Then se deniega.
- Given datos inválidos, When se intenta guardar en Firestore, Then las reglas los rechazan.

**Errores:**
- When un token expirado hace una petición, Then Firestore deniega el acceso.
- When se intenta inyectar campos no permitidos, Then las reglas los rechazan.

## Tareas técnicas
**Firestore Rules:**
- users: solo el propio usuario puede leer/editar su perfil.
- businesses: propietario gestiona, público lectura básica.
- appointments: cliente ve sus citas, staff/owner ve citas de su negocio.
- services: propietario gestiona, clientes solo lectura.
- staff: propietario gestiona, staff ve su propio perfil.
- reviews: cliente crea su reseña, todos pueden leer.
- Validaciones de tipos de datos y campos obligatorios.

**Cloud Functions:** Función para asignar/revocar roles con custom claims.
**Firebase:** Firebase App Check, tests de Firestore Rules con Firebase Emulator.

## Consideraciones técnicas
- Las reglas son la última línea de defensa.
- Nunca confiar solo en validación del cliente.
- Usar custom claims de Firebase Auth para roles.
- Documentar cada regla con su justificación.

## Edge cases
- Usuario con token válido pero negocio eliminado.
- Staff revocado intenta acceder con token aún válido.
- Ataque de enumeración de IDs de documentos.
- Petición con payload extremadamente grande (DoS).

## Prioridad
Alta

## Tipo
Security" "" "Seguridad"

create_issue_if_not_exists "Épica: Manejo offline y sincronización" \
"## Contexto
Implementación de funcionalidad offline-first para que los usuarios utilicen las funciones principales sin internet, sincronizando automáticamente cuando se restaura la conectividad.

## User Story
Como cliente, quiero poder ver mis citas y el catálogo de servicios aunque no tenga internet, para no depender de la conectividad para acceder a información ya cargada.

## Criterios de aceptación
**Flujo normal:**
- Given un cliente que usó la app con internet, When pierde conectividad, Then puede ver sus citas próximas, historial y catálogo de negocios visitados.
- Given la app sin internet, When el usuario realiza una acción que requiere conexión, Then se le informa y se guarda como borrador.
- Given conectividad restaurada, When hay datos pendientes, Then la app sincroniza automáticamente en background.
- Given un conflicto de datos, When se sincroniza, Then se aplica una estrategia de resolución clara (last-write-wins o merge).

**Errores:**
- When la sincronización falla parcialmente, Then se reintenta solo la parte fallida.
- When los datos locales están corruptos, Then se recupera desde el servidor.

## Tareas técnicas
**Flutter:** Persistencia offline de Firestore SDK, almacenamiento con Hive o Isar, indicador visual de conexión (banner/snackbar), cola de operaciones pendientes, gestión de conflictos.
**Firestore:** Habilitar persistencia offline, queries con Source.cache/Source.server, límites de caché local.
**Cloud Functions:** Endpoint de sincronización incremental (delta sync), resolución de conflictos en servidor.
**Firebase:** Configuración de caché máximo, Background sync con WorkManager/BGTaskScheduler.

## Consideraciones técnicas
- Diseñar el modelo de datos con offline-first en mente desde el principio.
- Priorizar datos críticos (citas próximas) sobre datos secundarios.
- Informar siempre al usuario del estado de sus datos.
- Probar en condiciones de red degradada.

## Edge cases
- Usuario elimina la app offline con datos sin sincronizar.
- Dos dispositivos del mismo usuario hacen cambios offline.
- Cita reservada offline que ya no está disponible al sincronizar.
- Actualización de la app mientras hay datos offline pendientes.

## Prioridad
Media

## Tipo
Mobile"

echo ""
echo "======================================"
echo "✅ Proceso completado"
echo "======================================"
