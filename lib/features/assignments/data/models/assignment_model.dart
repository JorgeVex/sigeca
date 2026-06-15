/// Representa una asignación / responsabilidad.
/// Incluye los datos relacionados (nombres) que traemos
/// con joins de Supabase, no solo los IDs.
class AssignmentModel {
  final String id;
  final String auxiliarId;
  final String auxiliarName;      // viene del join con profiles
  final String areaId;
  final String areaName;          // viene del join con areas
  final String? ambulanceId;
  final String? ambulancePlate;   // viene del join con ambulances (opcional)
  final int periodYear;
  final int periodMonth;
  final String? responsibilities;
  final String? objectives;
  final String? observations;

  const AssignmentModel({
    required this.id,
    required this.auxiliarId,
    required this.auxiliarName,
    required this.areaId,
    required this.areaName,
    this.ambulanceId,
    this.ambulancePlate,
    required this.periodYear,
    required this.periodMonth,
    this.responsibilities,
    this.objectives,
    this.observations,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    // Los datos relacionados llegan como objetos anidados.
    // Ej: json['areas'] = {'name': 'Esterilización'}
    final area = json['areas'] as Map<String, dynamic>?;
    final auxiliar = json['profiles'] as Map<String, dynamic>?;
    final ambulance = json['ambulances'] as Map<String, dynamic>?;

    return AssignmentModel(
      id: json['id'] as String,
      auxiliarId: json['auxiliar_id'] as String,
      auxiliarName: auxiliar?['full_name'] as String? ?? 'Desconocido',
      areaId: json['area_id'] as String,
      areaName: area?['name'] as String? ?? 'Sin área',
      ambulanceId: json['ambulance_id'] as String?,
      ambulancePlate: ambulance?['plate'] as String?,
      periodYear: json['period_year'] as int,
      periodMonth: json['period_month'] as int,
      responsibilities: json['responsibilities'] as String?,
      objectives: json['objectives'] as String?,
      observations: json['observations'] as String?,
    );
  }
}