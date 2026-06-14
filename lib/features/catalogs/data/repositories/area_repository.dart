import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/area_model.dart';

/// Acceso a datos para el catálogo de áreas.
/// Encapsula todas las operaciones CRUD contra la tabla 'areas'.
class AreaRepository {
  final SupabaseClient _client;

  AreaRepository(this._client);

  /// READ: trae todas las áreas, ordenadas por nombre.
  Future<List<AreaModel>> fetchAll() async {
    final data = await _client
        .from('areas')
        .select()
        .order('name', ascending: true);

    return (data as List)
        .map((json) => AreaModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// CREATE: inserta un área nueva y devuelve la creada.
  Future<AreaModel> create({
    required String name,
    String? description,
  }) async {
    final data = await _client
        .from('areas')
        .insert({
          'name': name,
          'description': description,
        })
        .select()
        .single();

    return AreaModel.fromJson(data);
  }

  /// UPDATE: actualiza un área existente por su id.
  Future<AreaModel> update({
    required String id,
    required String name,
    String? description,
    required bool isActive,
  }) async {
    final data = await _client
        .from('areas')
        .update({
          'name': name,
          'description': description,
          'is_active': isActive,
        })
        .eq('id', id)
        .select()
        .single();

    return AreaModel.fromJson(data);
  }

  /// DELETE: elimina un área por su id.
  Future<void> delete(String id) async {
    await _client.from('areas').delete().eq('id', id);
  }
}