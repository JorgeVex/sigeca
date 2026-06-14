/// Representa una ambulancia (fila de la tabla ambulances).
class AmbulanceModel {
  final String id;
  final String plate;
  final String status; // 'activa' | 'mantenimiento' | 'inactiva'

  const AmbulanceModel({
    required this.id,
    required this.plate,
    required this.status,
  });

  factory AmbulanceModel.fromJson(Map<String, dynamic> json) {
    return AmbulanceModel(
      id: json['id'] as String,
      plate: json['plate'] as String,
      status: json['status'] as String,
    );
  }
}