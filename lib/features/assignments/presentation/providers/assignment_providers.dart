import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/assignment_model.dart';
import '../../data/repositories/assignment_repository.dart';

/// Provee el repositorio de asignaciones.
final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(Supabase.instance.client);
});

/// Representa un periodo (mes y año) seleccionado.
class Period {
  final int year;
  final int month;
  const Period(this.year, this.month);
}

/// Notifier que mantiene el periodo seleccionado y permite cambiarlo.
class SelectedPeriodNotifier extends Notifier<Period> {
  @override
  Period build() {
    final now = DateTime.now();
    return Period(now.year, now.month);
  }

  void setPeriod(int year, int month) {
    state = Period(year, month);
  }
}

/// Periodo actualmente seleccionado.
final selectedPeriodProvider =
    NotifierProvider<SelectedPeriodNotifier, Period>(
        SelectedPeriodNotifier.new);

/// Lista de carpetas del periodo seleccionado.
final assignmentsListProvider =
    FutureProvider<List<AssignmentModel>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchByPeriod(year: period.year, month: period.month);
});

/// Lista de TODOS los auxiliares activos.
final auxiliaresListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAuxiliares();
});

/// IDs de auxiliares que YA tienen carpeta en el periodo.
final assignedAuxiliarIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAssignedAuxiliarIds(
      year: period.year, month: period.month);
});

/// IDs de áreas ya asignadas en el periodo (para filtrar disponibles).
final assignedAreaIdsProvider = FutureProvider<Set<String>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAssignedAreaIds(
      year: period.year, month: period.month);
});

/// IDs de ambulancias ya asignadas en el periodo.
final assignedAmbulanceIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchAssignedAmbulanceIds(
      year: period.year, month: period.month);
});

/// Insumos de una carpeta específica (se carga al abrir el detalle).
final assignmentSuppliesProvider = FutureProvider.family
    .autoDispose<List<dynamic>, String>((ref, assignmentId) async {
  final repository = ref.watch(assignmentRepositoryProvider);
  return repository.fetchSupplies(assignmentId);
});