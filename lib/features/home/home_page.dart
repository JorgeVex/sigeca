import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/catalogs/presentation/pages/areas_page.dart';
import '../../features/catalogs/presentation/pages/ambulances_page.dart';
import '../catalogs/presentation/pages/supplies_page.dart';
import '../users/presentation/pages/user_page.dart';

import '../auth/presentation/providers/auth_providers.dart';

/// Pantalla principal tras el login.
/// Muestra contenido distinto según el rol del usuario.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa el perfil del usuario (carga asíncrona).
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGECA'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      // .when maneja los tres estados del FutureProvider:
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar el perfil:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('No se encontró el perfil del usuario.'),
            );
          }
          return _HomeContent(profile: profile);
        },
      ),
    );
  }
}

/// Contenido del home una vez cargado el perfil.
class _HomeContent extends StatelessWidget {
  final dynamic profile; // ProfileModel
  const _HomeContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido,',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          Text(
            profile.fullName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(_roleLabel(profile.role)),
            backgroundColor: Colors.teal.shade50,
            avatar: Icon(_roleIcon(profile.role), size: 18, color: Colors.teal),
          ),
          const SizedBox(height: 32),
          const Text(
            'Acciones disponibles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Las opciones cambian según el rol.
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: _actionsForRole(profile.role, context),
            ),
          ),
        ],
      ),
    );
  }

  /// Etiqueta legible del rol.
  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'jefe':
        return 'Jefe de Enfermería';
      case 'auxiliar':
        return 'Auxiliar de Enfermería';
      case 'auditor':
        return 'Auditor / Calidad';
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'jefe':
        return Icons.supervisor_account;
      case 'auxiliar':
        return Icons.medical_services;
      case 'auditor':
        return Icons.fact_check;
      default:
        return Icons.person;
    }
  }

  /// Devuelve las tarjetas de acción según el rol.
  List<Widget> _actionsForRole(String role, BuildContext context) {
    switch (role) {
      case 'admin':
              return [
                _ActionCard(
                  icon: Icons.people,
                  label: 'Usuarios',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersPage()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.local_hospital,
                  label: 'Áreas',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AreasPage()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.directions_car,
                  label: 'Ambulancias',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AmbulancesPage()),
                  ),
                ),  
                _ActionCard(
                  icon: Icons.inventory_2,
                  label: 'Insumos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuppliesPage()),
                  ),
                ),
              ];
      case 'jefe':
        return const [
          _ActionCard(icon: Icons.assignment, label: 'Asignaciones'),
          _ActionCard(icon: Icons.fact_check, label: 'Aprobar reportes'),
        ];
      case 'auxiliar':
        return const [
          _ActionCard(icon: Icons.assignment_ind, label: 'Mis asignaciones'),
          _ActionCard(icon: Icons.camera_alt, label: 'Registrar evidencia'),
          _ActionCard(icon: Icons.description, label: 'Mis reportes'),
        ];
      case 'auditor':
        return const [
          _ActionCard(icon: Icons.photo_library, label: 'Evidencias'),
          _ActionCard(icon: Icons.assessment, label: 'Reportes'),
        ];
      default:
        return const [];
    }
  }
}

/// Tarjeta de acción (placeholder por ahora, sin navegación).
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionCard({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.teal),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}