/// Una foto individual de evidencia.
class ReportPhoto {
  final String id;
  final String photoUrl; // ruta en Storage
  final DateTime capturedAt;

  const ReportPhoto({
    required this.id,
    required this.photoUrl,
    required this.capturedAt,
  });

  factory ReportPhoto.fromJson(Map<String, dynamic> json) {
    return ReportPhoto(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }
}

/// El grupo de fotos de un área dentro de un reporte.
class ReportAreaPhotos {
  final String id;
  final String areaId;
  final String areaName;     // viene del join
  final String category;     // 'sala' | 'obligacion'
  final int photoCount;

  const ReportAreaPhotos({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.category,
    required this.photoCount,
  });

  factory ReportAreaPhotos.fromJson(Map<String, dynamic> json) {
    final area = json['areas'] as Map<String, dynamic>?;
    return ReportAreaPhotos(
      id: json['id'] as String,
      areaId: json['area_id'] as String,
      areaName: area?['name'] as String? ?? 'Sin área',
      category: area?['category'] as String? ?? 'obligacion',
      photoCount: json['photo_count'] as int? ?? 0,
    );
  }
}

/// Un reporte semanal de un auxiliar.
class ReportModel {
  final String id;
  final String assignmentId;
  final int weekNumber;
  final String status;       // 'en_progreso' | 'completado'
  final String? pdfUrl;
  final DateTime? completedAt;

  const ReportModel({
    required this.id,
    required this.assignmentId,
    required this.weekNumber,
    required this.status,
    this.pdfUrl,
    this.completedAt,
  });

  bool get isCompleted => status == 'completado';

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      weekNumber: json['week_number'] as int,
      status: json['status'] as String,
      pdfUrl: json['pdf_url'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}