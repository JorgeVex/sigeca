/// Un ítem del catálogo general de dispositivos de ambulancia.
class AmbulanceCatalogItem {
  final String id;
  final int? itemNumber;
  final String category;
  final String name;
  final String? pharmaceuticalForm;
  final int? defaultQuantity;
  final String? manufacturer;
  final String? invimaRegistry;

  const AmbulanceCatalogItem({
    required this.id,
    this.itemNumber,
    required this.category,
    required this.name,
    this.pharmaceuticalForm,
    this.defaultQuantity,
    this.manufacturer,
    this.invimaRegistry,
  });

  factory AmbulanceCatalogItem.fromJson(Map<String, dynamic> json) {
    return AmbulanceCatalogItem(
      id: json['id'] as String,
      itemNumber: json['item_number'] as int?,
      category: json['category'] as String,
      name: json['name'] as String,
      pharmaceuticalForm: json['pharmaceutical_form'] as String?,
      defaultQuantity: json['default_quantity'] as int?,
      manufacturer: json['manufacturer'] as String?,
      invimaRegistry: json['invima_registry'] as String?,
    );
  }
}

/// Una revisión de ambulancia (foto en el tiempo).
class AmbulanceReview {
  final String id;
  final String ambulanceId;
  final String reviewedBy;
  final DateTime reviewDate;
  final int periodYear;
  final int periodMonth;
  final String status; // 'en_progreso' | 'completada'
  final DateTime? completedAt;

  const AmbulanceReview({
    required this.id,
    required this.ambulanceId,
    required this.reviewedBy,
    required this.reviewDate,
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    this.completedAt,
  });

  bool get isCompleted => status == 'completada';

  factory AmbulanceReview.fromJson(Map<String, dynamic> json) {
    return AmbulanceReview(
      id: json['id'] as String,
      ambulanceId: json['ambulance_id'] as String,
      reviewedBy: json['reviewed_by'] as String,
      reviewDate: DateTime.parse(json['review_date'] as String),
      periodYear: json['period_year'] as int,
      periodMonth: json['period_month'] as int,
      status: json['status'] as String,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

/// El estado de un ítem dentro de una revisión (lo que llena el auxiliar).
/// Trae el catálogo embebido vía join para mostrar nombre/categoría.
class AmbulanceReviewItem {
  final String id;
  final String reviewId;
  final String catalogItemId;
  final int? quantity;
  final String? lote;
  final DateTime? expiryDate;
  final String? notes;
  final bool naFlag;
  // Datos del catálogo (join):
  final String name;
  final String category;
  final int? defaultQuantity;

  const AmbulanceReviewItem({
    required this.id,
    required this.reviewId,
    required this.catalogItemId,
    this.quantity,
    this.lote,
    this.expiryDate,
    this.notes,
    this.naFlag = false,
    required this.name,
    required this.category,
    this.defaultQuantity,
  });

  /// Semáforo según la fecha de vencimiento.
  /// Verde: >60 días | Amarillo: 60-15 días | Rojo: <15 días o vencido.
  /// Gris: sin fecha o marcado N/A.
  AmbulanceSemaphore get semaphore {
    if (naFlag || expiryDate == null) return AmbulanceSemaphore.none;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    if (days < 15) return AmbulanceSemaphore.red;
    if (days <= 60) return AmbulanceSemaphore.yellow;
    return AmbulanceSemaphore.green;
  }

  factory AmbulanceReviewItem.fromJson(Map<String, dynamic> json) {
    final catalog = json['ambulance_item_catalog'] as Map<String, dynamic>?;
    return AmbulanceReviewItem(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      catalogItemId: json['catalog_item_id'] as String,
      quantity: json['quantity'] as int?,
      lote: json['lote'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      notes: json['notes'] as String?,
      naFlag: json['na_flag'] as bool? ?? false,
      name: catalog?['name'] as String? ?? 'Ítem',
      category: catalog?['category'] as String? ?? 'OTROS',
      defaultQuantity: catalog?['default_quantity'] as int?,
    );
  }
}

/// Estado del semáforo de vencimiento.
enum AmbulanceSemaphore { green, yellow, red, none }