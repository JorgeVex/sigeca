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
    List<String> ambulanceIds = const [], // NUEVO
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

    // 3. Crear un grupo de fotos vacío por cada ambulancia de la carpeta.
    if (ambulanceIds.isNotEmpty) {
      final ambGroups = ambulanceIds
          .map((ambId) => {
                'report_id': report.id,
                'ambulance_id': ambId,
                'photo_count': 0,
              })
          .toList();
      await _client.from('report_ambulance_photos').insert(ambGroups);
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

  /// Sube VARIAS fotos de área en paralelo y recalcula el contador
  /// una sola vez al final (evita condición de carrera).
  Future<void> addPhotosBatch({
    required List<XFile> photos,
    required String reportId,
    required String areaGroupId,
    required String areaId,
  }) async {
    final futures = photos.map((photo) async {
      final path = await _storageService.uploadPhoto(
        photo: photo,
        reportId: reportId,
        areaId: areaId,
      );
      await _client.from('report_photos').insert({
        'report_area_photo_id': areaGroupId,
        'photo_url': path,
        'captured_at': DateTime.now().toIso8601String(),
      });
    }).toList();

    await Future.wait(futures);

    // Recalcular el contador contando las filas reales (seguro).
    await _recountAreaPhotos(areaGroupId);
  }

  /// Cuenta las fotos reales del grupo y actualiza photo_count.
  Future<void> _recountAreaPhotos(String areaGroupId) async {
    final rows = await _client
        .from('report_photos')
        .select('id')
        .eq('report_area_photo_id', areaGroupId);
    final realCount = (rows as List).length;
    await _client
        .from('report_area_photos')
        .update({'photo_count': realCount})
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

    // 3. Recalcular el contador real.
    await _recountAreaPhotos(areaGroupId);
  }

  /// Cierra una semana: marca el reporte como completado.
  /// Valida que todas las áreas tengan el mínimo de fotos.
  /// Cierra una semana: valida que áreas Y ambulancias tengan el mínimo.
  Future<void> completeWeek(String reportId) async {
    // Áreas con el mínimo.
    final groups = await fetchAreaGroups(reportId);
    final incompleteAreas =
        groups.where((g) => g.photoCount < minPhotosPerArea).toList();
    if (incompleteAreas.isNotEmpty) {
      throw Exception(
          'Faltan fotos: cada área necesita al menos $minPhotosPerArea fotos.');
    }

    // Ambulancias con el mínimo.
    final ambGroups = await fetchAmbulanceGroups(reportId);
    final incompleteAmb = ambGroups
        .where((g) => g.photoCount < minPhotosPerAmbulance)
        .toList();
    if (incompleteAmb.isNotEmpty) {
      throw Exception(
          'Faltan fotos: cada ambulancia necesita al menos '
          '$minPhotosPerAmbulance fotos.');
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

  /// Sube VARIAS fotos de insumo en paralelo.
  Future<void> addSupplyPhotosBatch({
    required List<XFile> photos,
    required String assignmentSupplyId,
    required String supplyId,
  }) async {
    final futures = photos.map((photo) async {
      final path = await _storageService.uploadSupplyPhoto(
        photo: photo,
        assignmentSupplyId: assignmentSupplyId,
      );
      await _client.from('supply_photos').insert({
        'assignment_supply_id': assignmentSupplyId,
        'photo_url': path,
        'captured_at': DateTime.now().toIso8601String(),
      });
    }).toList();

    await Future.wait(futures);
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

  /// Prepara los datos de un reporte para generar el PDF.
  /// Incluye áreas Y ambulancias. Descarga las fotos EN PARALELO.
  Future<List<PdfAreaData>> buildPdfData(String reportId) async {
    // --- Áreas ---
    final groups = await fetchAreaGroups(reportId);
    final areasFutures = groups.map((group) async {
      final photos = await fetchPhotos(group.id);
      final photoFutures = photos.map((photo) async {
        try {
          return await _storageService.downloadPhoto(photo.photoUrl);
        } catch (_) {
          return null;
        }
      }).toList();
      final results = await Future.wait(photoFutures);
      final photoBytes = results.whereType<Uint8List>().toList();
      return PdfAreaData(
        areaName: group.areaName,
        photos: photoBytes,
      );
    }).toList();

    // --- Ambulancias ---
    final ambGroups = await fetchAmbulanceGroups(reportId);
    final ambFutures = ambGroups.map((amb) async {
      final photos = await fetchAmbulancePhotos(amb.id);
      final photoFutures = photos.map((photo) async {
        try {
          return await _storageService.downloadPhoto(photo.photoUrl);
        } catch (_) {
          return null;
        }
      }).toList();
      final results = await Future.wait(photoFutures);
      final photoBytes = results.whereType<Uint8List>().toList();
      return PdfAreaData(
        areaName: 'Ambulancia ${amb.plate}',
        photos: photoBytes,
      );
    }).toList();

    // Esperar áreas y ambulancias, y combinarlas (áreas primero).
    final areas = await Future.wait(areasFutures);
    final ambulances = await Future.wait(ambFutures);
    return [...areas, ...ambulances];
  }

    // ============================================
  // AMBULANCIAS — fotos de aseo (obligatorias, semanal)
  // ============================================

  static const int minPhotosPerAmbulance = 4;
  static const int maxPhotosPerAmbulance = 10;

  /// Trae los grupos de ambulancia de un reporte (con placa vía join).
  Future<List<ReportAmbulancePhotos>> fetchAmbulanceGroups(
      String reportId) async {
    final data = await _client
        .from('report_ambulance_photos')
        .select('*, ambulances:ambulance_id (plate)')
        .eq('report_id', reportId);

    return (data as List)
        .map((json) =>
            ReportAmbulancePhotos.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Trae las fotos de un grupo de ambulancia.
  Future<List<ReportPhoto>> fetchAmbulancePhotos(String ambGroupId) async {
    final data = await _client
        .from('report_photos')
        .select()
        .eq('report_ambulance_photo_id', ambGroupId)
        .order('captured_at', ascending: true);

    return (data as List)
        .map((json) => ReportPhoto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Sube varias fotos de ambulancia en paralelo + recuenta al final.
  Future<void> addAmbulancePhotosBatch({
    required List<XFile> photos,
    required String reportId,
    required String ambGroupId,
    required String ambulanceId,
  }) async {
    final futures = photos.map((photo) async {
      // Reutiliza el storage pero en carpeta de ambulancias.
      final path = await _storageService.uploadAmbulancePhoto(
        photo: photo,
        reportId: reportId,
        ambulanceId: ambulanceId,
      );
      await _client.from('report_photos').insert({
        'report_ambulance_photo_id': ambGroupId,
        'photo_url': path,
        'captured_at': DateTime.now().toIso8601String(),
      });
    }).toList();

    await Future.wait(futures);
    await _recountAmbulancePhotos(ambGroupId);
  }

  Future<void> _recountAmbulancePhotos(String ambGroupId) async {
    final rows = await _client
        .from('report_photos')
        .select('id')
        .eq('report_ambulance_photo_id', ambGroupId);
    final realCount = (rows as List).length;
    await _client
        .from('report_ambulance_photos')
        .update({'photo_count': realCount})
        .eq('id', ambGroupId);
  }

  Future<void> removeAmbulancePhoto({
    required String photoId,
    required String photoPath,
    required String ambGroupId,
  }) async {
    await _storageService.deletePhoto(photoPath);
    await _client.from('report_photos').delete().eq('id', photoId);
    await _recountAmbulancePhotos(ambGroupId);
  }

    // ============================================
  // APROBACIÓN (perfil jefe)
  // ============================================

  /// Trae los reportes pendientes de aprobación (status = completado),
  /// con nombre del auxiliar y periodo, para la jefe.
  Future<List<PendingReport>> fetchPendingApproval() async {
    final data = await _client
        .from('reports')
        .select('''
          *,
          assignments:assignment_id (
            period_year, period_month,
            profiles:auxiliar_id (full_name)
          )
        ''')
        .eq('status', 'completado')
        .order('completed_at', ascending: true);

    return (data as List).map((j) {
      final json = j as Map<String, dynamic>;
      final assignment = json['assignments'] as Map<String, dynamic>?;
      final profile = assignment?['profiles'] as Map<String, dynamic>?;
      return PendingReport(
        report: ReportModel.fromJson(json),
        auxiliarName: profile?['full_name'] as String? ?? 'Auxiliar',
        periodYear: assignment?['period_year'] as int? ?? 0,
        periodMonth: assignment?['period_month'] as int? ?? 0,
      );
    }).toList();
  }

  /// La jefe aprueba un reporte.
  Future<void> approveReport({
    required String reportId,
    required String jefeId,
  }) async {
    await _client.from('reports').update({
      'status': 'aprobado',
      'approved_by': jefeId,
      'approved_at': DateTime.now().toIso8601String(),
      'reviewed_at': DateTime.now().toIso8601String(),
      'rejection_reason': null, // limpia cualquier rechazo previo
    }).eq('id', reportId);
  }

  /// La jefe rechaza un reporte con un motivo.
  Future<void> rejectReport({
    required String reportId,
    required String reason,
  }) async {
    await _client.from('reports').update({
      'status': 'rechazado',
      'rejection_reason': reason,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
  }

  /// Trae los datos del auxiliar dueño de un reporte (vía su asignación).
  /// Sirve para el PDF, sin depender de quién lo esté generando.
  Future<Map<String, dynamic>?> fetchReportAuxiliar(String reportId) async {
    final data = await _client
        .from('reports')
        .select('''
          assignments:assignment_id (
            profiles:auxiliar_id (full_name, document_id, signature_url)
          )
        ''')
        .eq('id', reportId)
        .maybeSingle();

    final assignment = data?['assignments'] as Map<String, dynamic>?;
    return assignment?['profiles'] as Map<String, dynamic>?;
  }
  /// Trae datos de firma de un perfil (para la firma de la jefe en el PDF).
  Future<Map<String, dynamic>?> fetchProfileSignature(String profileId) async {
    final data = await _client
        .from('profiles')
        .select('full_name, document_id, signature_url')
        .eq('id', profileId)
        .maybeSingle();
    return data;
  }
  /// Trae un reporte por su id, con su estado actual (fresco de la BD).
  Future<ReportModel> fetchReportById(String reportId) async {
    final data = await _client
        .from('reports')
        .select()
        .eq('id', reportId)
        .single();
    return ReportModel.fromJson(data);
  }

  /// Para la jefe: trae todos los auxiliares que tienen alguna asignación,
  /// con el conteo de reportes pendientes de aprobar (status=completado).
  /// Para la jefe: trae todos los auxiliares con asignación EN EL MES ACTUAL,
  /// con su progreso (X de 4), pendientes y aprobados, para el semáforo.
  Future<List<TeamAuxiliar>> fetchTeamAuxiliares() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // 1. Asignaciones del mes actual (una por auxiliar).
    final assignmentsData = await _client
        .from('assignments')
        .select('id, auxiliar_id, profiles:auxiliar_id (full_name)')
        .eq('period_year', year)
        .eq('period_month', month);

    // Mapa auxiliar -> {assignmentId, nombre}
    final List<Map<String, dynamic>> auxList = [];
    for (final row in (assignmentsData as List)) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      auxList.add({
        'assignmentId': row['id'] as String,
        'auxiliarId': row['auxiliar_id'] as String,
        'name': profile?['full_name'] as String? ?? 'Auxiliar',
      });
    }

    // 2. Para cada auxiliar, contar sus reportes por estado en el mes.
    final result = <TeamAuxiliar>[];
    for (final aux in auxList) {
      final reports = await _client
          .from('reports')
          .select('status')
          .eq('assignment_id', aux['assignmentId']);

      int pending = 0; // completado = pendiente de aprobar
      int approved = 0;
      int closed = 0; // cerrados (completado+aprobado+rechazado)

      for (final r in (reports as List)) {
        final status = r['status'] as String;
        if (status == 'completado') {
          pending++;
          closed++;
        } else if (status == 'aprobado') {
          approved++;
          closed++;
        } else if (status == 'rechazado') {
          closed++;
        }
      }

      result.add(TeamAuxiliar(
        auxiliarId: aux['auxiliarId'] as String,
        auxiliarName: aux['name'] as String,
        pendingCount: pending,
        approvedCount: approved,
        closedCount: closed,
      ));
    }

    // Ordenar: pendientes primero, luego los que menos han avanzado,
    // luego alfabético.
    result.sort((a, b) {
      if (a.pendingCount != b.pendingCount) {
        return b.pendingCount.compareTo(a.pendingCount);
      }
      if (a.closedCount != b.closedCount) {
        return a.closedCount.compareTo(b.closedCount);
      }
      return a.auxiliarName.compareTo(b.auxiliarName);
    });

    return result;
  }
  /// Para la jefe: trae TODAS las asignaciones (carpetas/meses) de un
  /// auxiliar, con el conteo de pendientes de cada una.
  /// Para la jefe: trae TODAS las asignaciones (carpetas/meses) de un
  /// auxiliar, con el conteo de pendientes de cada una.
  Future<List<TeamFolder>> fetchAuxiliarFolders(String auxiliarId) async {
    final data = await _client
        .from('assignments')
        .select('id, period_year, period_month')
        .eq('auxiliar_id', auxiliarId)
        .order('period_year', ascending: false)
        .order('period_month', ascending: false);

    final folders = <TeamFolder>[];
    for (final row in (data as List)) {
      final assignmentId = row['id'] as String;
      final reports = await _client
          .from('reports')
          .select('id')
          .eq('assignment_id', assignmentId)
          .eq('status', 'completado');
      folders.add(TeamFolder(
        assignmentId: assignmentId,
        periodYear: row['period_year'] as int,
        periodMonth: row['period_month'] as int,
        pendingCount: (reports as List).length,
      ));
    }
    return folders;
  }

}

/// Un reporte pendiente de aprobación, con datos del auxiliar para mostrar.
class PendingReport {
  final ReportModel report;
  final String auxiliarName;
  final int periodYear;
  final int periodMonth;

  PendingReport({
    required this.report,
    required this.auxiliarName,
    required this.periodYear,
    required this.periodMonth,
  });
}

/// Un auxiliar del equipo, con su conteo de reportes pendientes.
/// Un auxiliar del equipo, con su progreso del mes para el semáforo.
class TeamAuxiliar {
  final String auxiliarId;
  final String auxiliarName;
  final int pendingCount;   // reportes esperando aprobación
  final int approvedCount;  // reportes aprobados
  final int closedCount;    // reportes cerrados (de 4)

  TeamAuxiliar({
    required this.auxiliarId,
    required this.auxiliarName,
    required this.pendingCount,
    this.approvedCount = 0,
    this.closedCount = 0,
  });

  /// Total de reportes esperados por mes.
  static const int expectedPerMonth = 4;

  /// Estado del semáforo según el progreso.
  TeamStatus get status {
    if (pendingCount > 0) return TeamStatus.pending;        // naranja
    if (closedCount == 0) return TeamStatus.notStarted;     // gris
    if (approvedCount >= expectedPerMonth) return TeamStatus.done; // verde
    return TeamStatus.inProgress;                            // azul
  }
}

/// Estado del semáforo de un auxiliar.
enum TeamStatus { pending, inProgress, done, notStarted }

/// Una carpeta (mes) de un auxiliar, con su conteo de pendientes.
class TeamFolder {
  final String assignmentId;
  final int periodYear;
  final int periodMonth;
  final int pendingCount;

  TeamFolder({
    required this.assignmentId,
    required this.periodYear,
    required this.periodMonth,
    required this.pendingCount,
  });
}