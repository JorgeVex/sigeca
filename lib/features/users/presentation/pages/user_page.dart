import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/models/profile_model.dart';
import '../providers/user_providers.dart';

/// Pantalla de gestión de usuarios (solo admin).
/// Lista perfiles y permite cambiar rol y estado activo.
/// La creación de credenciales se hace fuera de la app (seguridad).
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  static const _roles = ['admin', 'jefe', 'auxiliar', 'auditor'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar los usuarios:\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      user.isActive ? Colors.teal : Colors.grey.shade400,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user.fullName),
                subtitle: Text(_roleLabel(user.role)),
                trailing: user.isActive
                    ? null
                    : const Text('Inactivo',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () => _showUserSheet(context, ref, user),
              );
            },
          );
        },
      ),
    );
  }

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

  /// Panel para editar rol y estado de un usuario.
/// Panel para editar rol y estado de un usuario.
  /// Los usuarios admin están protegidos: no se pueden
  /// inhabilitar ni cambiar de rol.
    void _showUserSheet(
        BuildContext context, WidgetRef ref, ProfileModel user) {
      final isAdmin = user.role == 'admin';
      String role = user.role;
      bool isActive = user.isActive;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 
                  MediaQuery.of(context).viewPadding.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Aviso si es un administrador protegido.
                    if (isAdmin)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Cuenta de administrador protegida. '
                                'No se puede cambiar su rol ni inhabilitar.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(r)),
                        );
                      }).toList(),
                      // Si es admin, el dropdown queda deshabilitado.
                      onChanged: isAdmin
                          ? null
                          : (value) {
                              if (value != null) {
                                setModalState(() => role = value);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Usuario activo'),
                      value: isActive,
                      activeColor: Colors.teal,
                      contentPadding: EdgeInsets.zero,
                      // Si es admin, el switch queda deshabilitado.
                      onChanged: isAdmin
                          ? null
                          : (v) => setModalState(() => isActive = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        // Si es admin, el botón guardar se desactiva.
                        onPressed: isAdmin
                            ? null
                            : () async {
                                final repo = ref.read(userRepositoryProvider);
                                try {
                                  if (role != user.role) {
                                    await repo.updateRole(
                                        id: user.id, role: role);
                                  }
                                  if (isActive != user.isActive) {
                                    await repo.updateActiveStatus(
                                        id: user.id, isActive: isActive);
                                  }
                                  ref.invalidate(usersListProvider);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                        child: const Text('Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
}