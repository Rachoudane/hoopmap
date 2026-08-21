class Court {
  const Court({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.hoopCount,
    required this.isOutdoor,
    required this.createdAt,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int hoopCount;
  final bool isOutdoor;
  final DateTime createdAt;

  /// A direct, already-resolved image URL, present only when the source
  /// data points to a Wikimedia Commons file (see
  /// data/commons_attribution.dart) — the only source this app can pair
  /// with a reliably fetchable author/license, which is a legal
  /// requirement for displaying it. Never a bare OpenStreetMap `image=*`
  /// URL pointing somewhere else.
  final String? imageUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Court &&
        other.id == id &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.hoopCount == hoopCount &&
        other.isOutdoor == isOutdoor &&
        other.createdAt == createdAt &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    hoopCount,
    isOutdoor,
    createdAt,
    imageUrl,
  );
}
