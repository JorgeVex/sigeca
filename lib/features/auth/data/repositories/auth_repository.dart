import 'package:supabase_flutter/supabase_flutter.dart';

/// Capa de acceso a datos para autenticación.
/// Encapsula toda la comunicación con Supabase Auth.
/// Si algún día cambias de backend, solo tocas este archivo.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Inicia sesión con email y contraseña.
  /// Devuelve la respuesta de autenticación si tiene éxito.
  /// Lanza una AuthException si las credenciales son inválidas.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cierra la sesión actual.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// El usuario actualmente autenticado, o null si no hay sesión.
  User? get currentUser => _client.auth.currentUser;

  /// Stream que emite cambios en el estado de autenticación
  /// (login, logout, refresh de token). Útil para reaccionar
  /// automáticamente cuando el usuario entra o sale.
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Obtiene el perfil del usuario actualmente autenticado.
  /// Devuelve null si no hay sesión o no se encuentra el perfil.
  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data;
  }

  /// Completa el perfil del usuario: guarda cédula y ruta de firma,
  /// y marca el perfil como completado.
  Future<void> completeProfile({
    required String userId,
    required String documentId,
    required String signatureUrl,
  }) async {
    await _client
        .from('profiles')
        .update({
          'document_id': documentId,
          'signature_url': signatureUrl,
          'profile_completed': true,
        })
        .eq('id', userId);
  }
}