import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/assignments/presentation/providers/assignment_providers.dart';

import 'core/config/env_config.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!EnvConfig.isValid) {
    throw Exception(
      'Faltan las credenciales de Supabase. '
      'Ejecuta la app pasando SUPABASE_URL y SUPABASE_ANON_KEY '
      'con --dart-define.',
    );
  }

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: SigecaApp(),
    ),
  );
}

/// Acceso rápido al cliente de Supabase desde cualquier parte.
final supabase = Supabase.instance.client;

class SigecaApp extends ConsumerStatefulWidget {
  const SigecaApp({super.key});

  @override
  ConsumerState<SigecaApp> createState() => _SigecaAppState();
}

class _SigecaAppState extends ConsumerState<SigecaApp> {
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Cada vez que cambia el estado de autenticación (login/logout),
    // invalidamos el perfil para que se recargue el del usuario actual.
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      ref.invalidate(currentProfileProvider);
      ref.invalidate(myAssignmentProvider);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SIGECA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}