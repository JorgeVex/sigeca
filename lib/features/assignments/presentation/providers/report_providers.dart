import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/storage_service.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/models/assignment_supply_model.dart';
import '../../data/models/supply_photo_model.dart';
import '../../../../core/services/pdf_service.dart';

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

/// Insumos de una carpeta con su estado de documentación.
final reportSuppliesProvider = FutureProvider.family
    .autoDispose<List<AssignmentSupplyModel>, String>(
        (ref, assignmentId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchSuppliesForReport(assignmentId);
});

/// Fotos de un insumo específico.
final supplyPhotosProvider = FutureProvider.family
    .autoDispose<List<SupplyPhoto>, String>((ref, assignmentSupplyId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchSupplyPhotos(assignmentSupplyId);
});

/// Provee el servicio de generación de PDF.
final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});

/// Grupos de ambulancia de un reporte específico.
final ambulanceGroupsProvider = FutureProvider.family
    .autoDispose<List<ReportAmbulancePhotos>, String>((ref, reportId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchAmbulanceGroups(reportId);
});

/// Fotos de un grupo de ambulancia específico.
final ambulancePhotosProvider = FutureProvider.family
    .autoDispose<List<ReportPhoto>, String>((ref, ambGroupId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchAmbulancePhotos(ambGroupId);
});

/// Reportes pendientes de aprobación (para la jefe).
final pendingApprovalProvider =
    FutureProvider.autoDispose<List<PendingReport>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.fetchPendingApproval();
});