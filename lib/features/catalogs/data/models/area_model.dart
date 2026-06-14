/// Representa un área de trabajo (fila de la tabla areas).
class AreaModel {
  final String id;
  final String name;
  final String? description;
  final bool isActive;

  const AreaModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  /// Construye un AreaModel desde el JSON de Supabase.
  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  /// Convierte el modelo a JSON para enviarlo a Supabase
  /// (sin id ni created_at: esos los genera la base de datos).
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }
}