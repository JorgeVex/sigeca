import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/assignment_model.dart';
import '../models/assignment_supply_model.dart';

/// Acceso a datos para asignaciones (responsabilidades).
class AssignmentRepository {
  final SupabaseClient _client;

  AssignmentRepository(this._client);

  /// READ: trae las asignaciones de un periodo, con joins
  /// para incluir nombre de auxiliar, área y placa de ambulancia.
  Future<List<AssignmentModel>> fetchByPeriod({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('''
          *,
          profiles:auxiliar_id (full_name),
          areas:area_id (name),
          ambulances:ambulance_id (plate)
        ''')
        .eq('period_year', year)
        .eq('period_month', month)
        .order('created_at', ascending: false);

    return (data as List)
        .map((json) => AssignmentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Cuenta cuántas responsabilidades tiene un auxiliar en un periodo.
  Future<int> countForAuxiliar({
    required String auxiliarId,
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('id')
        .eq('auxiliar_id', auxiliarId)
        .eq('period_year', year)
        .eq('period_month', month);

    return (data as List).length;
  }

  /// READ: trae los insumos asignados a una responsabilidad.
  Future<List<AssignmentSupplyModel>> fetchSupplies(
      String assignmentId) async {
    final data = await _client
        .from('assignment_supplies')
        .select('*, supplies:supply_id (name)')
        .eq('assignment_id', assignmentId);

    return (data as List)
        .map((json) =>
            AssignmentSupplyModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// CREATE: crea una asignación y le agrega sus insumos.
  /// Recibe el mapa de insumos {supply_id: cantidad}.
  Future<void> create({
    required String auxiliarId,
    required String areaId,
    String? ambulanceId,
    required int year,
    required int month,
    String? responsibilities,
    String? objectives,
    String? observations,
    required Map<String, int> supplies,
    required String assignedBy,
  }) async {
    // 1. Crear la asignación y obtener su id.
    final assignment = await _client
        .from('assignments')
        .insert({
          'auxiliar_id': auxiliarId,
          'area_id': areaId,
          'ambulance_id': ambulanceId,
          'period_year': year,
          'period_month': month,
          'responsibilities': responsibilities,
          'objectives': objectives,
          'observations': observations,
          'assigned_by': assignedBy,
        })
        .select()
        .single();

    final assignmentId = assignment['id'] as String;

    // 2. Insertar los insumos asociados (si hay).
    if (supplies.isNotEmpty) {
      final rows = supplies.entries
          .map((e) => {
                'assignment_id': assignmentId,
                'supply_id': e.key,
                'quantity': e.value,
              })
          .toList();

      await _client.from('assignment_supplies').insert(rows);
    }
  }

  /// DELETE: elimina una asignación (sus insumos se borran en cascada).
  Future<void> delete(String id) async {
    await _client.from('assignments').delete().eq('id', id);
  }

  /// Trae los perfiles con rol 'auxiliar' que estén activos.
  /// Para poblar el dropdown de auxiliares en el formulario.
  Future<List<Map<String, dynamic>>> fetchAuxiliares() async {
    final data = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'auxiliar')
        .eq('is_active', true)
        .order('full_name', ascending: true);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Devuelve los IDs de áreas YA asignadas en un periodo.
  /// Sirve para filtrar las disponibles en el formulario.
  Future<Set<String>> fetchAssignedAreaIds({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('area_id')
        .eq('period_year', year)
        .eq('period_month', month);

    return (data as List)
        .map((row) => row['area_id'] as String)
        .toSet();
  }

  /// Devuelve los IDs de ambulancias YA asignadas en un periodo.
  Future<Set<String>> fetchAssignedAmbulanceIds({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('ambulance_id')
        .eq('period_year', year)
        .eq('period_month', month)
        .not('ambulance_id', 'is', null);

    return (data as List)
        .map((row) => row['ambulance_id'] as String)
        .toSet();
  }
}