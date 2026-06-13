import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/profile_model.dart';

import '../../data/repositories/auth_repository.dart';

/// Provee la instancia del repositorio de autenticación.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Estado del proceso de login.
sealed class LoginState {
  const LoginState();
}

class LoginIdle extends LoginState {
  const LoginIdle();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginError extends LoginState {
  final String message;
  const LoginError(this.message);
}

/// Controlador del login con la API Notifier (Riverpod 3).
/// El estado inicial se define en build().
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginIdle();

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  Future<bool> signIn(String email, String password) async {
    state = const LoginLoading();
    try {
      await _authRepository.signIn(email: email, password: password);
      state = const LoginIdle();
      return true; // login exitoso
    } on AuthException catch (e) {
      state = LoginError(e.message);
      return false;
    } catch (e) {
      state = LoginError('Ocurrió un error inesperado. Intenta de nuevo.');
      return false;
    }
  }
}

/// Provee el controlador de login a la UI.
final loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);
/// Carga el perfil del usuario autenticado de forma asíncrona.
/// FutureProvider es ideal para datos que se obtienen una vez
/// y pueden estar "cargando", "listos" o "con error".
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  final data = await repository.fetchCurrentProfile();
  if (data == null) return null;
  return ProfileModel.fromJson(data);
});