# Mapa de ruta con OpenStreetMap

La pantalla `Ruta del dia` usa:

- `flutter_map` para mostrar tiles de OpenStreetMap sin API key.
- OSRM publico (`https://router.project-osrm.org`) para calcular distancia, duracion y polyline.
- Throttle de 10 segundos en `GeolocationRouteService` para evitar rate limiting de OSRM.
- `geolocator` para GPS:
  - `getCurrentPosition` con timeout de 15 segundos.
  - `getPositionStream` con `distanceFilter: 50`.

Permisos Android requeridos:

- `android.permission.INTERNET`
- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.ACCESS_FINE_LOCATION`

Si OSRM falla o se llama antes de cumplir el throttle, el sistema usa una estimacion offline por Haversine para no bloquear el modulo.
