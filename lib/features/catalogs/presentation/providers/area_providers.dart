import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/area_model.dart';
import '../../data/repositories/area_repository.dart';

/// Provee el repositorio de áreas.
final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepository(Supabase.instance.client);
});

/// Provee la lista de áreas (carga asíncrona desde Supabase).
/// Al invalidarlo, se vuelve a consultar la tabla.
final areasListProvider = FutureProvider<List<AreaModel>>((ref) async {
  final repository = ref.watch(areaRepositoryProvider);
  return repository.fetchAll();
});