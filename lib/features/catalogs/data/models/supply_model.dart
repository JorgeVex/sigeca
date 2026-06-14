/// Representa un insumo (fila de la tabla supplies).
class SupplyModel {
  final String id;
  final String name;
  final bool isActive;

  const SupplyModel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory SupplyModel.fromJson(Map<String, dynamic> json) {
    return SupplyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}