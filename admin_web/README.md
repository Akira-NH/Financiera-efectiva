# Web - Financiera Efectiva

Esta seccion web vive aislada en `admin_web/`. No modifica pantallas,
rutas, componentes ni logica de las aplicaciones moviles de Cliente o Fuerza de
Ventas.

## Roles

La web usa Firebase Auth y detecta el rol con datos existentes:

- `sales_users/{uid}.role` o `.rol` con valores como `admin`,
  `administrador`, `supervisor`, `asesor`, `fuerza de ventas`.
- Si el correo contiene `admin`, `administrador` o `supervisor`, entra como
  administrador.
- Si existe `clients/{uid}` y no hay rol operativo, entra como cliente.

El login mantiene un unico ingreso. Luego la web valida el rol con Firestore y
redirige a la vista correspondiente. Las opciones `Crear cuenta` y
`Recuperar contraseña` aplican al flujo de clientes.

Rutas publicas del login:

- `#/auth/login`
- `#/auth/register`
- `#/auth/reset`

Cada rol queda protegido por hash route y paginas internas:

- Administrador:
  - `#/admin/dashboard`
  - `#/admin/solicitudes`
  - `#/admin/clientes`
  - `#/admin/asesores`
  - `#/admin/seguimiento`
- Cliente:
  - `#/client/inicio`
  - `#/client/solicitudes`
  - `#/client/creditos`
  - `#/client/perfil`
- Asesor:
  - `#/advisor/cartera`
  - `#/advisor/ruta`
  - `#/advisor/solicitud`
  - `#/advisor/cliente`

Si el usuario intenta abrir una ruta que no corresponde a su rol, la web lo
redirige automaticamente a su vista permitida.

## Colecciones usadas

- Administrador y asesor:
  - `sales_credit_requests`
  - `sales_clients`
  - `clientes_scoring_demo`
- Cliente:
  - `clients/{uid}`
  - `clients/{uid}/creditRequests`
  - `clients/{uid}/credits/activeLoan`
  - `clients/{uid}/installments`

## Escrituras permitidas desde la web

La web solo escribe siguiendo los contratos ya usados por las apps moviles:

- Cliente registra cuenta en:
  - `Firebase Auth`
  - `clients/{uid}`
- Cliente crea solicitud en:
  - `clients/{uid}/creditRequests/{requestId}`
  - `sales_credit_requests/{requestId}`
  - `sales_clients/{dni}`
- Cliente recupera acceso con `sendPasswordResetEmail` de Firebase Auth.
- Asesor actualiza:
  - `estado_cliente`: `Visitar` o `Visitado`
  - `estado_solicitud`: `Aceptado` o `Negado`

No se crean estados nuevos ni se reemplaza la logica movil.

## Como abrir

Desde esta carpeta:

```powershell
cd admin_web
python -m http.server 8088
```

Luego abre `http://localhost:8088`.

## Archivos

- `index.html`: shell web, login y logo.
- `styles.css`: estilos responsive alineados a la paleta y marca movil.
- `app.js`: punto de entrada de la aplicacion.

## Arquitectura MVC

- `js/config`: constantes de navegacion, Firebase y catalogos.
- `js/models`: normalizacion de solicitudes, estados, roles e historial.
- `js/services`: Firebase Auth, Firestore, listeners y escrituras permitidas.
- `js/views`: plantillas HTML por componente y pagina.
- `js/controllers`: coordinacion de rutas, eventos, filtros y acciones.
- `js/state`: estado central de la SPA y limpieza de listeners.
