import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/route_visit.dart';
import '../data/services/geolocation_route_service.dart';

class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.visits,
    this.calculation,
    this.currentPosition,
    this.onVisitTap,
  });

  final List<RouteVisit> visits;
  final RouteCalculation? calculation;
  final LatLng? currentPosition;
  final ValueChanged<RouteVisit>? onVisitTap;

  @override
  Widget build(BuildContext context) {
    final points = [
      ?currentPosition,
      for (final visit in visits)
        if (visit.latitude != 0 && visit.longitude != 0)
          LatLng(visit.latitude, visit.longitude),
    ];

    if (points.isEmpty) {
      return const _RouteMapPlaceholder(
        message: 'No hay coordenadas para mostrar en el mapa.',
      );
    }

    final center = _centerOf(points);
    final polyline = calculation?.polyline.isNotEmpty == true
        ? calculation!.polyline
        : points;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 320,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: points.length > 1 ? 12 : 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.financiera_efectiva_ventas',
            ),
            if (polyline.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polyline,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (currentPosition != null)
                  Marker(
                    point: currentPosition!,
                    width: 44,
                    height: 44,
                    child: const Tooltip(
                      message: 'Ubicacion del asesor',
                      child: Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 34,
                      ),
                    ),
                  ),
                for (var index = 0; index < visits.length; index++)
                  if (visits[index].latitude != 0 &&
                      visits[index].longitude != 0)
                    Marker(
                      point: LatLng(
                        visits[index].latitude,
                        visits[index].longitude,
                      ),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => onVisitTap?.call(visits[index]),
                        child: _VisitMarker(
                          visit: visits[index],
                          order: index + 1,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LatLng _centerOf(List<LatLng> points) {
    final lat =
        points.fold<double>(0, (sum, point) => sum + point.latitude) /
        points.length;
    final lng =
        points.fold<double>(0, (sum, point) => sum + point.longitude) /
        points.length;
    return LatLng(lat, lng);
  }
}

class _VisitMarker extends StatelessWidget {
  const _VisitMarker({required this.visit, required this.order});

  final RouteVisit visit;
  final int order;

  @override
  Widget build(BuildContext context) {
    final isVisited =
        visit.objective.toLowerCase().contains('firma') ||
        visit.objective.toLowerCase().contains('realizada');
    final color = isVisited ? Colors.grey : visit.statusColor;
    return Tooltip(
      message: '${visit.client}\n${visit.objective}',
      child: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$order',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RouteMapPlaceholder extends StatelessWidget {
  const _RouteMapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      alignment: Alignment.center,
      child: Text(message),
    );
  }
}
