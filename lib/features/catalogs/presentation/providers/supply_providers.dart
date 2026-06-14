import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/supply_model.dart';
import '../../data/repositories/supply_repository.dart';

final supplyRepositoryProvider = Provider<SupplyRepository>((ref) {
  return SupplyRepository(Supabase.instance.client);
});

final suppliesListProvider = FutureProvider<List<SupplyModel>>((ref) async {
  final repository = ref.watch(supplyRepositoryProvider);
  return repository.fetchAll();
});