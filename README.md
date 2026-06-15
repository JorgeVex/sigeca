# SIGECA — Sistema Integral de Gestión de Evidencias y Cumplimiento Asistencial

Aplicación móvil multiplataforma para gestionar, controlar y auditar el cumplimiento de las responsabilidades operativas del personal auxiliar de enfermería en una institución de salud (IPS). SIGECA reemplaza el envío informal de evidencias por WhatsApp con un sistema estructurado de asignaciones, evidencias fotográficas verificables y reportes automatizados.

## Descripción

En muchas instituciones de salud, las evidencias de aseo, esterilización y control de insumos se gestionan por grupos de WhatsApp, lo que genera saturación de mensajes, falta de trazabilidad, dificultad para auditar y riesgo de reutilización de fotografías antiguas.

SIGECA aborda este problema permitiendo que la jefatura de enfermería asigne áreas, responsabilidades e insumos al personal auxiliar, y que este registre evidencias fotográficas organizadas por periodo, con control de cumplimiento y generación de reportes consolidados en PDF.

## Roles del sistema

- **Administrador**: gestiona usuarios, áreas, ambulancias e insumos del sistema.
- **Jefe de Enfermería**: arma las asignaciones de cada auxiliar (áreas, ambulancias, insumos) por periodo y aprueba reportes.
- **Auxiliar de Enfermería**: consulta y acepta sus asignaciones, registra evidencias y genera reportes semanales y mensuales.
- **Auditor / Calidad**: consulta evidencias y reportes en modo de solo lectura.

## Tecnologías

- **Frontend**: Flutter (Dart), arquitectura Feature First.
- **Gestión de estado**: Riverpod (API moderna `Notifier`).
- **Navegación**: go_router, con protección de rutas según sesión.
- **Backend**: Supabase (PostgreSQL, Auth, Storage).
- **Seguridad**: Row Level Security (RLS) granular por rol a nivel de base de datos.

## Arquitectura

El proyecto sigue una organización **Feature First** con una separación de dos capas (datos / presentación) dentro de cada funcionalidad:

```
lib/
├── core/
│   ├── config/        # Configuración (credenciales por variables de entorno)
│   ├── router/        # Configuración de navegación con go_router
│   └── ...
├── features/
│   ├── auth/          # Autenticación y perfiles
│   ├── home/          # Pantalla principal según rol
│   ├── users/         # Gestión de usuarios (admin)
│   ├── catalogs/      # Áreas, ambulancias e insumos (admin)
│   └── assignments/   # Asignaciones y reportes
│       ├── data/
│       │   ├── models/
│       │   └── repositories/
│       └── presentation/
│           ├── pages/
│           └── providers/
└── main.dart
```

Cada feature aísla su lógica de datos (modelos y repositorios que hablan con Supabase) de su presentación (pantallas y providers de estado). El flujo general es: pantalla → provider → repositorio → Supabase, y de vuelta.

## Modelo de datos

El sistema se apoya en un modelo relacional en PostgreSQL con seguridad por filas (RLS). Las entidades principales son:

- **profiles**: extiende a los usuarios de autenticación con su rol y estado.
- **areas**: catálogo de áreas, clasificadas en *salas* y *obligaciones*.
- **ambulances**: catálogo de ambulancias con su estado operativo.
- **supplies**: catálogo de insumos.
- **assignments**: la "carpeta" de un auxiliar para un periodo (mes/año). Una por auxiliar y periodo.
- **assignment_areas / assignment_ambulances / assignment_supplies**: las áreas, ambulancias e insumos que componen cada carpeta.
- **reports**: reportes semanales (1 a 4) de cada carpeta.
- **report_area_photos / report_photos**: evidencias fotográficas agrupadas por área dentro de cada reporte.

Reglas de negocio destacadas, garantizadas a nivel de base de datos:
- Cada área y cada ambulancia se asignan a un solo auxiliar por periodo (exclusividad).
- Un auxiliar tiene una sola carpeta de asignación por periodo.
- Los reportes semanales siguen una lógica secuencial estricta.

## Requisitos previos

- Flutter SDK (canal estable).
- Un dispositivo Android físico o emulador.
- Una cuenta de Supabase con un proyecto configurado.

## Instalación

1. Clona el repositorio:

   ```bash
   git clone https://github.com/[TU_USUARIO]/sigeca.git
   cd sigeca
   ```

2. Instala las dependencias:

   ```bash
   flutter pub get
   ```

3. Configura las credenciales de Supabase. La aplicación lee la URL y la clave pública del proyecto mediante variables de entorno en tiempo de compilación, por lo que **no se incluyen credenciales en el código fuente**.

   Crea el archivo `.vscode/launch.json` (ignorado por Git) con tus credenciales:

   ```json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "name": "SIGECA (debug)",
         "request": "launch",
         "type": "dart",
         "program": "lib/main.dart",
         "args": [
           "--dart-define=SUPABASE_URL=TU_URL",
           "--dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA"
         ]
       }
     ]
   }
   ```

   O bien, ejecuta directamente por línea de comandos:

   ```bash
   flutter run --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
   ```

4. Configura la base de datos en Supabase ejecutando los scripts SQL de creación de tablas y políticas RLS.

## Estado del proyecto

El proyecto está en desarrollo activo. Funcionalidades implementadas hasta el momento:

- Autenticación por correo y contraseña, con control de acceso por rol y bloqueo de cuentas inhabilitadas.
- Navegación protegida según el estado de sesión.
- Módulo de administrador completo: gestión de usuarios (con protección del rol administrador), áreas, ambulancias e insumos (CRUD).
- Módulo del jefe de enfermería: creación de asignaciones por auxiliar agrupando áreas, ambulancias e insumos, con exclusividad por periodo.
- Módulo del auxiliar: consulta y aceptación de asignaciones.
- Modelo de datos completo para reportes y evidencias fotográficas.

## Roadmap

- [ ] Captura de evidencias fotográficas (cámara, compresión y subida a Supabase Storage).
- [ ] Reportes semanales con mínimo de fotos por área y lógica secuencial.
- [ ] Reporte mensual consolidado en PDF.
- [ ] Flujo de aprobación/rechazo de reportes por la jefatura.
- [ ] Definición del manejo de ambulancias en mantenimiento (pendiente de validación con el personal).
- [ ] Notificaciones (recordatorios, vencimientos, incumplimientos).
- [ ] Dashboard de cumplimiento.

## Autor

[TU_NOMBRE]

## Licencia

[Define la licencia que prefieras, por ejemplo MIT]