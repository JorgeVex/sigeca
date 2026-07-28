/// Una foto de evidencia de un insumo documentado.
class SupplyPhoto {
  final String id;
  final String photoUrl; // ruta en Storage
  final DateTime capturedAt;

  const SupplyPhoto({
    required this.id,
    required this.photoUrl,
    required this.capturedAt,
  });

  factory SupplyPhoto.fromJson(Map<String, dynamic> json) {
    return SupplyPhoto(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }
}