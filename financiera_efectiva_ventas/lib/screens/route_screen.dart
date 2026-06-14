import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/theme.dart';
import '../data/models/route_visit.dart';
import '../data/repositories/sales_repository.dart';
import '../data/services/geolocation_route_service.dart';
import '../widgets/app_shell_widgets.dart';
import '../widgets/route_map.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.repository});

  final SalesRepository repository;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final routeService = GeolocationRouteService();
  late List<RouteVisit> visits;
  Future<RouteCalculation>? routeCalculation;
  StreamSubscription<Position>? positionSubscription;
  LatLng? currentPosition;
  String locationStatus = 'GPS sin iniciar';
  bool optimized = false;

  @override
  void initState() {
    super.initState();
    visits = List.of(widget.repository.routeVisits);
    routeCalculation = _calculateRoute();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  Future<RouteCalculation> _calculateRoute() {
    return routeService.calculateRoute(visits, origin: currentPosition);
  }

  void _refreshRoute() {
    setState(() => routeCalculation = _calculateRoute());
  }

  Future<void> _startGps() async {
    final messenger = ScaffoldMessenger.of(context);
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => locationStatus = 'Activa la ubicacion del dispositivo.');
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'GPS desactivado. Puedes ver el mapa sin optimizacion exacta.',
          ),
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => locationStatus = 'Permiso de ubicacion denegado.');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sin permiso de ubicacion. El mapa sigue disponible.'),
        ),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _updatePosition(position);
    } catch (_) {
      setState(() => locationStatus = 'No se pudo obtener GPS en 15s.');
    }

    await positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen(_updatePosition, onError: _handlePositionError);
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    setState(() {
      currentPosition = LatLng(position.latitude, position.longitude);
      locationStatus = 'GPS activo';
      routeCalculation = _calculateRoute();
    });
  }

  void _handlePositionError(Object error) {
    if (!mounted) return;
    setState(() => locationStatus = 'GPS interrumpido');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Se interrumpio la lectura GPS. Reintenta iniciar GPS.',
          ),
        ),
      );
  }

  void _optimizeRoute() {
    final origin = currentPosition ?? const LatLng(-12.0464, -77.0428);
    final pending = List<RouteVisit>.of(visits);
    final optimizedVisits = <RouteVisit>[];
    var lat = origin.latitude;
    var lng = origin.longitude;

    while (pending.isNotEmpty) {
      pending.sort((a, b) {
        final distanceA = _distance(lat, lng, a.latitude, a.longitude);
        final distanceB = _distance(lat, lng, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });
      final next = pending.removeAt(0);
      optimizedVisits.add(next);
      lat = next.latitude;
      lng = next.longitude;
    }

    setState(() {
      optimized = true;
      visits = optimizedVisits;
      routeCalculation = _calculateRoute();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          currentPosition == null
              ? 'Ruta optimizada con ubicacion estimada por falta de GPS.'
              : 'Ruta optimizada desde tu ubicacion GPS.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        const SectionTitle(
          title: 'Ruta del dia',
          subtitle:
              'OpenStreetMap sin API key, GPS en vivo y ruteo OSRM publico.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<RouteCalculation>(
              future: routeCalculation,
              builder: (context, snapshot) {
                final calculation = snapshot.data;
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RouteMap(
                      visits: visits,
                      calculation: calculation,
                      currentPosition: currentPosition,
                      onVisitTap: (visit) => _showVisitSummary(context, visit),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: optimized
                              ? 'Ruta optimizada'
                              : 'Orden original',
                          color: optimized ? Colors.green : AppTheme.brandBlue,
                        ),
                        StatusPill(
                          label: loading
                              ? 'Calculando OSRM...'
                              : '${calculation?.distanceKm.toStringAsFixed(1) ?? '--'} km',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        StatusPill(
                          label: loading
                              ? 'Tiempo pendiente'
                              : '${calculation?.durationMinutes.round() ?? '--'} min',
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        StatusPill(
                          label: calculation?.sourceLabel ?? 'OSRM listo',
                          color: AppTheme.brandGold,
                        ),
                        StatusPill(
                          label: locationStatus,
                          color: Colors.blueGrey,
                        ),
                        FilledButton.icon(
                          onPressed: _optimizeRoute,
                          icon: const Icon(Icons.alt_route),
                          label: const Text('Optimizar ruta'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _startGps,
                          icon: const Icon(Icons.my_location_outlined),
                          label: const Text('Iniciar GPS'),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Recalcular OSRM',
                          onPressed: loading ? null : _refreshRoute,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < visits.length; i++)
          _RouteVisitTile(
            order: i + 1,
            visit: visits[i],
            onOpen: () => _showVisitSummary(context, visits[i]),
          ),
      ],
    );
  }

  void _showVisitSummary(BuildContext context, RouteVisit visit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(visit.client, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Gestion: ${visit.objective}'),
              Text('Direccion: ${visit.address}'),
              Text(
                'Monto relacionado: S/ ${(visit.latitude.abs() * 1000).toStringAsFixed(0)}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Ver ficha completa'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navegar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  double _distance(double lat1, double lng1, double lat2, double lng2) {
    final dx = lat1 - lat2;
    final dy = lng1 - lng2;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _RouteVisitTile extends StatelessWidget {
  const _RouteVisitTile({
    required this.order,
    required this.visit,
    required this.onOpen,
  });

  final int order;
  final RouteVisit visit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: visit.statusColor.withValues(alpha: .16),
          child: Text('$order'),
        ),
        title: Text(visit.client),
        subtitle: Text('${visit.objective}\n${visit.address}'),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Resumen',
          onPressed: onOpen,
          icon: const Icon(Icons.more_horiz),
        ),
      ),
    );
  }
}
