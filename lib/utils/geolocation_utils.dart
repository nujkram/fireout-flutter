import 'package:geolocator/geolocator.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double calculateDistanceKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000.0;
}

List<Map<String, dynamic>> filterIncidentsByProximity(
  List<Map<String, dynamic>> incidents,
  double stationLat,
  double stationLng,
  double radiusKm,
) {
  final annotated = <Map<String, dynamic>>[];
  for (final incident in incidents) {
    final loc = incident['incidentLocation'];
    if (loc is! Map) continue;
    final lat = _toDouble(loc['latitude']);
    final lng = _toDouble(loc['longitude']);
    if (lat == null || lng == null) continue;

    final distance = calculateDistanceKm(stationLat, stationLng, lat, lng);
    if (distance <= radiusKm) {
      annotated.add({...incident, 'distanceFromStation': distance});
    }
  }
  annotated.sort((a, b) {
    final da = (a['distanceFromStation'] as num).toDouble();
    final db = (b['distanceFromStation'] as num).toDouble();
    return da.compareTo(db);
  });
  return annotated;
}
