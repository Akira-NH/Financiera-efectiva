import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/route_visit.dart';

class GeolocationRouteService {
  GeolocationRouteService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _lastOsrmRequestAt;

  static const osrmThrottle = Duration(seconds: 10);

  Future<RouteCalculation> calculateRoute(
    List<RouteVisit> visits, {
    LatLng? origin,
  }) async {
    final routePoints = _routePoints(visits, origin: origin);
    if (routePoints.length < 2) return const RouteCalculation.empty();

    final osrmResult = await _calculateWithOsrm(routePoints);
    if (osrmResult != null) return osrmResult;

    return _calculateOffline(routePoints);
  }

  List<LatLng> _routePoints(List<RouteVisit> visits, {LatLng? origin}) {
    final points = [
      ?origin,
      for (final visit in visits)
        if (visit.latitude != 0 && visit.longitude != 0)
          LatLng(visit.latitude, visit.longitude),
    ];
    return points;
  }

  Future<RouteCalculation?> _calculateWithOsrm(List<LatLng> points) async {
    final now = _clock();
    final lastRequest = _lastOsrmRequestAt;
    if (lastRequest != null && now.difference(lastRequest) < osrmThrottle) {
      return null;
    }
    _lastOsrmRequestAt = now;

    try {
      final uri = _buildOsrmUri(points);
      final client = HttpClient();
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'financiera-efectiva-ventas/1.0',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode != HttpStatus.ok) return null;

      final json = jsonDecode(body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>? ?? [];
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>? ?? [];
      final polyline = coordinates.map((point) {
        final values = point as List<dynamic>;
        return LatLng(
          (values[1] as num).toDouble(),
          (values[0] as num).toDouble(),
        );
      }).toList();

      return RouteCalculation(
        distanceKm: ((route['distance'] as num?)?.toDouble() ?? 0) / 1000,
        durationMinutes: ((route['duration'] as num?)?.toDouble() ?? 0) / 60,
        source: RouteCalculationSource.osrm,
        polyline: polyline.isEmpty ? points : polyline,
      );
    } catch (_) {
      return null;
    }
  }

  Uri _buildOsrmUri(List<LatLng> points) {
    final coordinates = points
        .map(
          (point) =>
              '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    return Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson&steps=false',
    );
  }

  RouteCalculation _calculateOffline(List<LatLng> points) {
    var distance = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      distance += _haversineKm(points[index], points[index + 1]);
    }

    const cityTrafficFactor = 1.35;
    const averageSpeedKmH = 24.0;
    final adjustedDistance = distance * cityTrafficFactor;
    final minutes = adjustedDistance / averageSpeedKmH * 60;

    return RouteCalculation(
      distanceKm: adjustedDistance,
      durationMinutes: minutes,
      source: RouteCalculationSource.offlineEstimate,
      polyline: points,
    );
  }

  double _haversineKm(LatLng from, LatLng to) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(to.latitude - from.latitude);
    final dLon = _degreesToRadians(to.longitude - from.longitude);
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final a =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;
}

class RouteCalculation {
  const RouteCalculation({
    required this.distanceKm,
    required this.durationMinutes,
    required this.source,
    required this.polyline,
  });

  const RouteCalculation.empty()
    : distanceKm = 0,
      durationMinutes = 0,
      source = RouteCalculationSource.offlineEstimate,
      polyline = const [];

  final double distanceKm;
  final double durationMinutes;
  final RouteCalculationSource source;
  final List<LatLng> polyline;

  String get sourceLabel {
    return switch (source) {
      RouteCalculationSource.osrm => 'OSRM publico',
      RouteCalculationSource.offlineEstimate => 'Ruta estimada',
    };
  }
}

enum RouteCalculationSource { osrm, offlineEstimate }
