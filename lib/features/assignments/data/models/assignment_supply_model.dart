/// Representa un insumo asignado a una carpeta,
/// con su cantidad y estado de documentación.
class AssignmentSupplyModel {
  final String id;
  final String supplyId;
  final String supplyName;   // viene del join
  final int quantity;
  final bool documented;
  final int? documentedWeek;

  const AssignmentSupplyModel({
    required this.id,
    required this.supplyId,
    required this.supplyName,
    required this.quantity,
    this.documented = false,
    this.documentedWeek,
  });

  factory AssignmentSupplyModel.fromJson(Map<String, dynamic> json) {
    final supply = json['supplies'] as Map<String, dynamic>?;

    return AssignmentSupplyModel(
      id: json['id'] as String,
      supplyId: json['supply_id'] as String,
      supplyName: supply?['name'] as String? ?? 'Insumo',
      quantity: json['quantity'] as int,
      documented: json['documented'] as bool? ?? false,
      documentedWeek: json['documented_week'] as int?,
    );
  }
}