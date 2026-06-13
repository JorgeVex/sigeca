/// Representa un perfil de usuario (fila de la tabla profiles).
class ProfileModel {
  final String id;
  final String fullName;
  final String role;
  final bool isActive;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  /// Construye un ProfileModel a partir del JSON que devuelve Supabase.
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}