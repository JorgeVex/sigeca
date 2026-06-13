/// Lee las credenciales desde variables de entorno definidas
/// en tiempo de compilación con --dart-define.
/// Nunca se hardcodean las claves en el código fuente.
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Valida que las credenciales estén presentes.
  static bool get isValid =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}