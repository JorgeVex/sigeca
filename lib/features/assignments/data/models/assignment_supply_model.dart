/// Representa un insumo asignado a una responsabilidad,
/// con su cantidad. El nombre del insumo viene del join.
class AssignmentSupplyModel {
  final String id;
  final String supplyId;
  final String supplyName;   // viene del join con supplies
  final int quantity;

  const AssignmentSupplyModel({
    required this.id,
    required this.supplyId,
    required this.supplyName,
    required this.quantity,
  });

  factory AssignmentSupplyModel.fromJson(Map<String, dynamic> json) {
    final supply = json['supplies'] as Map<String, dynamic>?;

    return AssignmentSupplyModel(
      id: json['id'] as String,
      supplyId: json['supply_id'] as String,
      supplyName: supply?['name'] as String? ?? 'Insumo',
      quantity: json['quantity'] as int,
    );
  }
}