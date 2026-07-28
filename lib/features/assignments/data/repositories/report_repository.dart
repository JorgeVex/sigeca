import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/storage_service.dart';
import '../models/report_model.dart';
import '../models/assignment_supply_model.dart';
import '../models/supply_photo_model.dart';
import 'dart:typed_data';
import '../../../../core/services/pdf_service.dart';

/// Acceso a datos para reportes semanales y sus evidencias.
class ReportRepository {
  final SupabaseClient _client;
  final StorageService _storageService;

  ReportRepository(this._client, this._storageService);

  // Mínimo y máximo de fotos por área.
  static const int minPhotosPerArea = 8;
  static const int maxPhotosPerArea = 15;

  // Límites de fotos por insumo.
  static const int minSupplyPhotos = 1;
  static const int maxSupplyPhotos = 5;

  /// Trae los reportes de una carpeta (las semanas existentes).
  Future<List<ReportModel>> fetchReports(String assignmentId) async {
    final data = await _client
        .from('reports')
        .select()
        .eq('assignment_id', assignmentId)
        .order('week_number', ascending: true);

    return (data as List)
        .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Crea el reporte de una semana (si no existe) y devuelve su id.
  /// Crea también los grupos de área vacíos para las áreas de la carpeta.
  Future<ReportModel> createWeekReport({
    required String assignmentId,
    required int weekNumber,
    required List<String> areaIds,
  }) async {
    // 1. Crear el reporte.
    final reportData = await _client
        .from('reports')
        .insert({
          'assignment_id': assignmentId,
          'week_number': weekNumber,
        })
        .select()
        .single();

    final report = ReportModel.fromJson(reportData);

    // 2. Crear un grupo de fotos vacío por cada área de la carpeta.
    if (areaIds.isNotEmpty) {
      final groups = areaIds
          .map((areaId) => {
                'report_id': report.id,
                'area_id': areaId,
                'photo_count': 0,
              })
          .toList();
      await _client.from('report_area_photos').insert(groups);
    }

    return report;
  }

  /// Trae los grupos de área de un reporte (con nombres vía join).
  Future<List<ReportAreaPhotos>> fetchAreaGroups(String reportId) async {
    final data = await _client
        .from('report_area_photos')
        .select('*, areas:area_id (name, category)')
        .eq('report_id', reportId);

    return (data as List)
        .map((json) =>
            ReportAreaPhotos.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Trae las fotos de un grupo de área.
  Future<List<ReportPhoto>> fetchPhotos(String areaGroupId) async {
    final data = await _client
        .from('report_photos')
        .select()
        .eq('report_area_photo_id', areaGroupId)
        .order('captured_at', ascending: true);

    return (data as List)
        .map((json) => ReportPhoto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Sube una foto: la guarda en Storage, la registra en la BD,
  /// y actualiza el contador del grupo de área.
  Future<void> addPhoto({
    required XFile photo,
    required String reportId,
    required String areaGroupId,
    required String areaId,
    required int currentCount,
  }) async {
    // 1. Subir la foto a Storage y obtener su ruta.
    final path = await _storageService.uploadPhoto(
      photo: photo,
      reportId: reportId,
      areaId: areaId,
    );

    // 2. Registrar la foto en la base de datos.
    await _client.from('report_photos').insert({
      'report_area_photo_id': areaGroupId,
      'photo_url': path,
      'captured_at': DateTime.now().toIso8601String(),
    });

    // 3. Actualizar el contador del grupo de área.
    await _client
        .from('report_area_photos')
        .update({'photo_count': currentCount + 1})
        .eq('id', areaGroupId);
  }

  /// Elimina una foto: del Storage, de la BD, y baja el contador.
  Future<void> removePhoto({
    required String photoId,
    required String photoPath,
    required String areaGroupId,
    required int currentCount,
  }) async {
    // 1. Borrar de Storage.
    await _storageService.deletePhoto(photoPath);

    // 2. Borrar de la base de datos.
    await _client.from('report_photos').delete().eq('id', photoId);

    // 3. Bajar el contador.
    await _client
        .from('report_area_photos')
        .update({'photo_count': currentCount - 1})
        .eq('id', areaGroupId);
  }

  /// Cierra una semana: marca el reporte como completado.
  /// Valida que todas las áreas tengan el mínimo de fotos.
  Future<void> completeWeek(String reportId) async {
    // Verificar que todos los grupos de área tengan el mínimo.
    final groups = await fetchAreaGroups(reportId);
    final incomplete =
        groups.where((g) => g.photoCount < minPhotosPerArea).toList();

    if (incomplete.isNotEmpty) {
      throw Exception(
          'Faltan fotos: cada área necesita al menos $minPhotosPerArea fotos.');
    }

    await _client
        .from('reports')
        .update({
          'status': 'completado',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reportId);
  }

  // ============================================
  // INSUMOS — documentación opcional (nivel mensual)
  // ============================================

  /// Trae los insumos de una carpeta con su estado de documentación.
  Future<List<AssignmentSupplyModel>> fetchSuppliesForReport(
      String assignmentId) async {
    final data = await _client
        .from('assignment_supplies')
        .select('*, supplies:supply_id (name)')
        .eq('assignment_id', assignmentId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((json) =>
            AssignmentSupplyModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Trae las fotos de un insumo documentado.
  Future<List<SupplyPhoto>> fetchSupplyPhotos(
      String assignmentSupplyId) async {
    final data = await _client
        .from('supply_photos')
        .select()
        .eq('assignment_supply_id', assignmentSupplyId)
        .order('captured_at', ascending: true);

    return (data as List)
        .map((json) => SupplyPhoto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Sube una foto de un insumo (1-5 permitidas).
  Future<void> addSupplyPhoto({
    required XFile photo,
    required String assignmentSupplyId,
    required String supplyId,
  }) async {
    // Subir a Storage, en una carpeta propia para insumos.
    final path = await _storageService.uploadSupplyPhoto(
      photo: photo,
      assignmentSupplyId: assignmentSupplyId,
    );

    // Registrar en la base de datos.
    await _client.from('supply_photos').insert({
      'assignment_supply_id': assignmentSupplyId,
      'photo_url': path,
      'captured_at': DateTime.now().toIso8601String(),
    });
  }

  /// Elimina una foto de insumo.
  Future<void> removeSupplyPhoto({
    required String photoId,
    required String photoPath,
  }) async {
    await _storageService.deletePhoto(photoPath);
    await _client.from('supply_photos').delete().eq('id', photoId);
  }

  /// Marca un insumo como documentado en una semana dada.
  Future<void> markSupplyDocumented({
    required String assignmentSupplyId,
    required int weekNumber,
  }) async {
    await _client
        .from('assignment_supplies')
        .update({
          'documented': true,
          'documented_week': weekNumber,
          'documented_at': DateTime.now().toIso8601String(),
        })
        .eq('id', assignmentSupplyId);
  }

  /// Prepara los datos de un reporte para generar el PDF:
  /// descarga las fotos de cada área desde Storage.
  Future<List<PdfAreaData>> buildPdfData(String reportId) async {
    final groups = await fetchAreaGroups(reportId);
    final result = <PdfAreaData>[];

    for (final group in groups) {
      final photos = await fetchPhotos(group.id);
      final photoBytes = <Uint8List>[];

      for (final photo in photos) {
        try {
          final bytes = await _storageService.downloadPhoto(photo.photoUrl);
          photoBytes.add(bytes);
        } catch (_) {
          // Si una foto falla al descargar, se omite (no rompe el PDF).
        }
      }

      result.add(PdfAreaData(
        areaName: group.areaName,
        photos: photoBytes,
      ));
    }

    return result;
  }

}