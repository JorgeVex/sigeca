import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/home_page.dart';

/// Configuración central de navegación con go_router.
final appRouter = GoRouter(
  initialLocation: '/login',

  // Reacciona automáticamente a cambios de sesión (login/logout)
  // envolviendo el stream de Supabase Auth.
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),

  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
  ],

  // Regla de redirección: decide a dónde mandar al usuario.
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isOnLogin = state.matchedLocation == '/login';

    // Sin sesión e intentando entrar a una ruta protegida -> al login.
    if (!isLoggedIn && !isOnLogin) return '/login';

    // Con sesión pero parado en el login -> al home.
    if (isLoggedIn && isOnLogin) return '/home';

    // En cualquier otro caso, no redirigir.
    return null;
  },
);

/// Envuelve un Stream para que go_router pueda escucharlo
/// como un Listenable y refrescar las rutas cuando cambie.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}