/// Un área dentro de una carpeta de asignación.
class AssignmentAreaItem {
  final String id;       // id de la fila en assignment_areas
  final String areaId;
  final String areaName;
  final String category; // 'sala' | 'obligacion'

  const AssignmentAreaItem({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.category,
  });

  factory AssignmentAreaItem.fromJson(Map<String, dynamic> json) {
    final area = json['areas'] as Map<String, dynamic>?;
    return AssignmentAreaItem(
      id: json['id'] as String,
      areaId: json['area_id'] as String,
      areaName: area?['name'] as String? ?? 'Sin área',
      category: area?['category'] as String? ?? 'obligacion',
    );
  }
}

/// Una ambulancia dentro de una carpeta de asignación.
class AssignmentAmbulanceItem {
  final String id;       // id de la fila en assignment_ambulances
  final String ambulanceId;
  final String plate;

  const AssignmentAmbulanceItem({
    required this.id,
    required this.ambulanceId,
    required this.plate,
  });

  factory AssignmentAmbulanceItem.fromJson(Map<String, dynamic> json) {
    final amb = json['ambulances'] as Map<String, dynamic>?;
    return AssignmentAmbulanceItem(
      id: json['id'] as String,
      ambulanceId: json['ambulance_id'] as String,
      plate: amb?['plate'] as String? ?? 'Sin placa',
    );
  }
}

/// Una carpeta de asignación: todo lo que un auxiliar tiene
/// asignado en un periodo (áreas, ambulancias, insumos, notas).
class AssignmentModel {
  final String id;
  final String auxiliarId;
  final String auxiliarName;
  final int periodYear;
  final int periodMonth;
  final String? responsibilities;
  final String? objectives;
  final String? observations;
  final bool accepted; // si el auxiliar ya aceptó la carpeta
  final List<AssignmentAreaItem> areas;
  final List<AssignmentAmbulanceItem> ambulances;

  const AssignmentModel({
    required this.id,
    required this.auxiliarId,
    required this.auxiliarName,
    required this.periodYear,
    required this.periodMonth,
    this.responsibilities,
    this.objectives,
    this.observations,
    this.accepted = false,
    this.areas = const [],
    this.ambulances = const [],
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    final auxiliar = json['profiles'] as Map<String, dynamic>?;

    // Las áreas y ambulancias llegan como listas anidadas (de los joins).
    final areasJson = json['assignment_areas'] as List? ?? [];
    final ambulancesJson = json['assignment_ambulances'] as List? ?? [];

    return AssignmentModel(
      id: json['id'] as String,
      auxiliarId: json['auxiliar_id'] as String,
      auxiliarName: auxiliar?['full_name'] as String? ?? 'Desconocido',
      periodYear: json['period_year'] as int,
      periodMonth: json['period_month'] as int,
      responsibilities: json['responsibilities'] as String?,
      objectives: json['objectives'] as String?,
      observations: json['observations'] as String?,
      accepted: json['accepted'] as bool? ?? false,
      areas: areasJson
          .map((a) => AssignmentAreaItem.fromJson(a as Map<String, dynamic>))
          .toList(),
      ambulances: ambulancesJson
          .map((a) =>
              AssignmentAmbulanceItem.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}