import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/ambulance_model.dart';
import '../../data/repositories/ambulance_repository.dart';

final ambulanceRepositoryProvider = Provider<AmbulanceRepository>((ref) {
  return AmbulanceRepository(Supabase.instance.client);
});

final ambulancesListProvider =
    FutureProvider<List<AmbulanceModel>>((ref) async {
  final repository = ref.watch(ambulanceRepositoryProvider);
  return repository.fetchAll();
});