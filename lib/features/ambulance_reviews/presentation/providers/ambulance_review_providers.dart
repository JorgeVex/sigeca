import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/ambulance_reviews.dart';
import '../../data/repositories/ambulance_review_repository.dart';

/// Repositorio de revisiones de ambulancia.
final ambulanceReviewRepositoryProvider =
    Provider<AmbulanceReviewRepository>((ref) {
  return AmbulanceReviewRepository(Supabase.instance.client);
});

/// Revisiones (histórico) de una ambulancia específica.
final ambulanceReviewsProvider = FutureProvider.family
    .autoDispose<List<AmbulanceReview>, String>((ref, ambulanceId) async {
  final repo = ref.watch(ambulanceReviewRepositoryProvider);
  return repo.fetchReviews(ambulanceId);
});

/// Ítems de una revisión específica (con catálogo embebido).
final ambulanceReviewItemsProvider = FutureProvider.family
    .autoDispose<List<AmbulanceReviewItem>, String>((ref, reviewId) async {
  final repo = ref.watch(ambulanceReviewRepositoryProvider);
  return repo.fetchReviewItems(reviewId);
});