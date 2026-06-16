import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/assignment_model.dart';
import '../models/assignment_supply_model.dart';

/// Acceso a datos para asignaciones (carpetas).
class AssignmentRepository {
  final SupabaseClient _client;

  AssignmentRepository(this._client);

  /// READ: trae las carpetas de un periodo, con sus áreas,
  /// ambulancias y el nombre del auxiliar (joins anidados).
  Future<List<AssignmentModel>> fetchByPeriod({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('''
          *,
          profiles:auxiliar_id (full_name),
          assignment_areas (
            id, area_id,
            areas:area_id (name, category)
          ),
          assignment_ambulances (
            id, ambulance_id,
            ambulances:ambulance_id (plate)
          )
        ''')
        .eq('period_year', year)
        .eq('period_month', month)
        .order('created_at', ascending: false);

    return (data as List)
        .map((json) => AssignmentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// READ: trae los insumos de una carpeta.
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

  /// CREATE: crea una carpeta completa para un auxiliar:
  /// la carpeta + sus áreas + sus ambulancias + sus insumos.
  Future<void> createPackage({
    required String auxiliarId,
    required int year,
    required int month,
    required List<String> areaIds,
    required List<String> ambulanceIds,
    required Map<String, int> supplies,
    String? responsibilities,
    String? objectives,
    String? observations,
    required String assignedBy,
  }) async {
    // 1. Crear la carpeta y obtener su id.
    final assignment = await _client
        .from('assignments')
        .insert({
          'auxiliar_id': auxiliarId,
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

    // 2. Insertar las áreas.
    if (areaIds.isNotEmpty) {
      final areaRows = areaIds
          .map((areaId) => {
                'assignment_id': assignmentId,
                'area_id': areaId,
                'period_year': year,
                'period_month': month,
              })
          .toList();
      await _client.from('assignment_areas').insert(areaRows);
    }

    // 3. Insertar las ambulancias.
    if (ambulanceIds.isNotEmpty) {
      final ambRows = ambulanceIds
          .map((ambId) => {
                'assignment_id': assignmentId,
                'ambulance_id': ambId,
                'period_year': year,
                'period_month': month,
              })
          .toList();
      await _client.from('assignment_ambulances').insert(ambRows);
    }

    // 4. Insertar los insumos.
    if (supplies.isNotEmpty) {
      final supplyRows = supplies.entries
          .map((e) => {
                'assignment_id': assignmentId,
                'supply_id': e.key,
                'quantity': e.value,
              })
          .toList();
      await _client.from('assignment_supplies').insert(supplyRows);
    }
  }

  /// DELETE: elimina una carpeta (todo lo suyo cae en cascada).
  Future<void> delete(String id) async {
    await _client.from('assignments').delete().eq('id', id);
  }

  /// Trae los auxiliares activos (para el formulario).
  Future<List<Map<String, dynamic>>> fetchAuxiliares() async {
    final data = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'auxiliar')
        .eq('is_active', true)
        .order('full_name', ascending: true);

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// IDs de auxiliares que YA tienen carpeta en el periodo.
  /// Para no asignarles otra (regla: una carpeta por auxiliar/mes).
  Future<Set<String>> fetchAssignedAuxiliarIds({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('auxiliar_id')
        .eq('period_year', year)
        .eq('period_month', month);

    return (data as List)
        .map((row) => row['auxiliar_id'] as String)
        .toSet();
  }

  /// IDs de áreas ya asignadas en el periodo (exclusividad).
  Future<Set<String>> fetchAssignedAreaIds({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignment_areas')
        .select('area_id')
        .eq('period_year', year)
        .eq('period_month', month);

    return (data as List)
        .map((row) => row['area_id'] as String)
        .toSet();
  }

  /// IDs de ambulancias ya asignadas en el periodo (exclusividad).
  Future<Set<String>> fetchAssignedAmbulanceIds({
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignment_ambulances')
        .select('ambulance_id')
        .eq('period_year', year)
        .eq('period_month', month);

    return (data as List)
        .map((row) => row['ambulance_id'] as String)
        .toSet();
  }
/// Trae la carpeta del auxiliar actual para un periodo (o null si no tiene).
  /// Incluye sus áreas y ambulancias vía joins.
  Future<AssignmentModel?> fetchMyAssignment({
    required String auxiliarId,
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('assignments')
        .select('''
          *,
          profiles:auxiliar_id (full_name),
          assignment_areas (
            id, area_id,
            areas:area_id (name, category)
          ),
          assignment_ambulances (
            id, ambulance_id,
            ambulances:ambulance_id (plate)
          )
        ''')
        .eq('auxiliar_id', auxiliarId)
        .eq('period_year', year)
        .eq('period_month', month)
        .maybeSingle();

    if (data == null) return null;
    return AssignmentModel.fromJson(data);
  }

  /// Marca una carpeta como aceptada (registra fecha/hora).
  Future<void> acceptAssignment(String assignmentId) async {
    await _client
        .from('assignments')
        .update({
          'accepted': true,
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', assignmentId);
  }

}