import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supply_model.dart';

/// Acceso a datos para el catálogo de insumos (CRUD).
class SupplyRepository {
  final SupabaseClient _client;

  SupplyRepository(this._client);

  Future<List<SupplyModel>> fetchAll() async {
    final data = await _client
        .from('supplies')
        .select()
        .order('name', ascending: true);

    return (data as List)
        .map((json) => SupplyModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<SupplyModel> create({required String name}) async {
    final data = await _client
        .from('supplies')
        .insert({'name': name})
        .select()
        .single();

    return SupplyModel.fromJson(data);
  }

  Future<SupplyModel> update({
    required String id,
    required String name,
    required bool isActive,
  }) async {
    final data = await _client
        .from('supplies')
        .update({'name': name, 'is_active': isActive})
        .eq('id', id)
        .select()
        .single();

    return SupplyModel.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('supplies').delete().eq('id', id);
  }
}