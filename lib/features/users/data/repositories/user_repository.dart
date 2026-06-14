import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/data/models/profile_model.dart';

/// Acceso a datos para la gestión de usuarios (perfiles).
/// Opera sobre la tabla 'profiles'. La creación de credenciales
/// (auth.users) se hace fuera de la app por seguridad.
class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  /// READ: trae todos los perfiles, ordenados por nombre.
  Future<List<ProfileModel>> fetchAll() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('full_name', ascending: true);

    return (data as List)
        .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// UPDATE: cambia el rol de un usuario.
  Future<void> updateRole({
    required String id,
    required String role,
  }) async {
    await _client
        .from('profiles')
        .update({'role': role})
        .eq('id', id);
  }

  /// UPDATE: activa o desactiva un usuario.
  Future<void> updateActiveStatus({
    required String id,
    required bool isActive,
  }) async {
    await _client
        .from('profiles')
        .update({'is_active': isActive})
        .eq('id', id);
  }
}