/// Representa un área de trabajo (fila de la tabla areas).
class AreaModel {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final String category; // 'sala' | 'obligacion'

  const AreaModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.category,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      category: json['category'] as String? ?? 'obligacion',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'is_active': isActive,
      'category': category,
    };
  }
}