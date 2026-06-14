import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance_model.dart';

/// Acceso a datos para el catálogo de ambulancias (CRUD).
class AmbulanceRepository {
  final SupabaseClient _client;

  AmbulanceRepository(this._client);

  /// READ: todas las ambulancias, ordenadas por placa.
  Future<List<AmbulanceModel>> fetchAll() async {
    final data = await _client
        .from('ambulances')
        .select()
        .order('plate', ascending: true);

    return (data as List)
        .map((json) => AmbulanceModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// CREATE: inserta una ambulancia nueva.
  Future<AmbulanceModel> create({
    required String plate,
    required String status,
  }) async {
    final data = await _client
        .from('ambulances')
        .insert({'plate': plate, 'status': status})
        .select()
        .single();

    return AmbulanceModel.fromJson(data);
  }

  /// UPDATE: actualiza placa y estado por id.
  Future<AmbulanceModel> update({
    required String id,
    required String plate,
    required String status,
  }) async {
    final data = await _client
        .from('ambulances')
        .update({'plate': plate, 'status': status})
        .eq('id', id)
        .select()
        .single();

    return AmbulanceModel.fromJson(data);
  }

  /// DELETE: elimina una ambulancia por id.
  Future<void> delete(String id) async {
    await _client.from('ambulances').delete().eq('id', id);
  }
}