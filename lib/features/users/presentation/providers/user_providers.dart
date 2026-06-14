import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/data/models/profile_model.dart';
import '../../data/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(Supabase.instance.client);
});

final usersListProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.fetchAll();
});