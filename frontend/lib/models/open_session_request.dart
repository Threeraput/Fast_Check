class OpenSessionRequest {
  final String classId;
  final int durationMinutes; // e.g., 15
  final double radiusMeters; // e.g., 50.0
  final double? anchorLat; // optional
  final double? anchorLon; // optional

  OpenSessionRequest({
    required this.classId,
    required this.durationMinutes,
    required this.radiusMeters,
    this.anchorLat,
    this.anchorLon,
  });

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'duration_minutes': durationMinutes,
    'radius_meters': radiusMeters,
    if (anchorLat != null) 'anchor_lat': anchorLat,
    if (anchorLon != null) 'anchor_lon': anchorLon,
  };
}
