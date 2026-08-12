class Court {
  const Court({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.hoopCount,
    required this.isOutdoor,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int hoopCount;
  final bool isOutdoor;
  final DateTime createdAt;

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
        other.createdAt == createdAt;
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
  );
}
