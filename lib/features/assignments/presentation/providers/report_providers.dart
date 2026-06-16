import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/storage_service.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';

/// Provee el servicio de Storage.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(Supabase.instance.client);
});

/// Provee el repositorio de reportes.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(
    Supabase.instance.client,
    ref.watch(storageServiceProvider),
  );
});

/// Lista de reportes (semanas) de una carpeta.
final reportsListProvider = FutureProvider.family
    .autoDispose<List<ReportModel>, String>((ref, assignmentId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchReports(assignmentId);
});

/// Grupos de área de un reporte específico.
final areaGroupsProvider = FutureProvider.family
    .autoDispose<List<ReportAreaPhotos>, String>((ref, reportId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchAreaGroups(reportId);
});

/// Fotos de un grupo de área específico.
final photosProvider = FutureProvider.family
    .autoDispose<List<ReportPhoto>, String>((ref, areaGroupId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchPhotos(areaGroupId);
});