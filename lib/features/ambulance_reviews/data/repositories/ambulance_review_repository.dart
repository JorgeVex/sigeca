import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance_reviews.dart';

/// Acceso a datos para las revisiones de ambulancia.
class AmbulanceReviewRepository {
  final SupabaseClient _client;

  AmbulanceReviewRepository(this._client);

  /// Trae el catálogo general de ítems (ordenado por categoría y número).
  Future<List<AmbulanceCatalogItem>> fetchCatalog() async {
    final data = await _client
        .from('ambulance_item_catalog')
        .select()
        .eq('active', true)
        .order('category', ascending: true)
        .order('item_number', ascending: true);

    return (data as List)
        .map((j) => AmbulanceCatalogItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Trae las revisiones de una ambulancia (histórico, más reciente primero).
  Future<List<AmbulanceReview>> fetchReviews(String ambulanceId) async {
    final data = await _client
        .from('ambulance_reviews')
        .select()
        .eq('ambulance_id', ambulanceId)
        .order('review_date', ascending: false);

    return (data as List)
        .map((j) => AmbulanceReview.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Crea una nueva revisión para una ambulancia y genera sus ítems
  /// a partir del catálogo general. Devuelve la revisión creada.
  Future<AmbulanceReview> createReview({
    required String ambulanceId,
    required int periodYear,
    required int periodMonth,
  }) async {
    final userId = _client.auth.currentUser!.id;

    // 1. Crear la cabecera de la revisión.
    final reviewData = await _client
        .from('ambulance_reviews')
        .insert({
          'ambulance_id': ambulanceId,
          'reviewed_by': userId,
          'period_year': periodYear,
          'period_month': periodMonth,
        })
        .select()
        .single();

    final review = AmbulanceReview.fromJson(reviewData);

    // 2. Traer el catálogo y crear un ítem de revisión por cada uno,
    //    precargando la cantidad por defecto.
    final catalog = await fetchCatalog();
    if (catalog.isNotEmpty) {
      final rows = catalog
          .map((c) => {
                'review_id': review.id,
                'catalog_item_id': c.id,
                'quantity': c.defaultQuantity,
              })
          .toList();
      await _client.from('ambulance_review_items').insert(rows);
    }

    return review;
  }

  /// Trae los ítems de una revisión con el catálogo embebido (join).
  Future<List<AmbulanceReviewItem>> fetchReviewItems(String reviewId) async {
    final data = await _client
        .from('ambulance_review_items')
        .select('''
          *,
          ambulance_item_catalog:catalog_item_id (
            name, category, default_quantity, item_number
          )
        ''')
        .eq('review_id', reviewId);

    final items = (data as List)
        .map((j) => AmbulanceReviewItem.fromJson(j as Map<String, dynamic>))
        .toList();

    // Ordenar por categoría y número de ítem (el join no ordena solo).
    items.sort((a, b) {
      final c = a.category.compareTo(b.category);
      return c;
    });
    return items;
  }

  /// Actualiza un ítem de revisión (cantidad, lote, vencimiento, N/A, notas).
  Future<void> updateReviewItem({
    required String itemId,
    int? quantity,
    String? lote,
    DateTime? expiryDate,
    String? notes,
    required bool naFlag,
  }) async {
    await _client.from('ambulance_review_items').update({
      'quantity': quantity,
      'lote': lote,
      'expiry_date': expiryDate?.toIso8601String().substring(0, 10), // solo fecha
      'notes': notes,
      'na_flag': naFlag,
    }).eq('id', itemId);
  }

  /// Marca una revisión como completada.
  Future<void> completeReview(String reviewId) async {
    await _client.from('ambulance_reviews').update({
      'status': 'completada',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', reviewId);
  }
}