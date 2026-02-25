import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';

class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    // final user = authState.user;

    return Drawer(
      backgroundColor: const Color(0xFF0C1020),
      child: Column(
        children: [
          _buildHeader(context, authState,ref),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (authState.status == AuthStatus.authenticated) ...[
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: Colors.white70),
                    title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logged out')),
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.login, color: Colors.white70),
                    title: const Text('Login', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/login');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined, color: Colors.white70),
                    title: const Text('Sign Up', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/signup');
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthState authState, WidgetRef ref) {
    final user = authState.user;
    final bool isAuthenticated = authState.status == AuthStatus.authenticated;
    final bool isLoading = authState.status == AuthStatus.loading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
      color: Colors.white.withOpacity(0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            child: isLoading
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isAuthenticated ? Icons.person : Icons.person_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            Text(
              'Checking status...',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            )
          else if (isAuthenticated) ...[
            Text(
              user?.username ?? 'User',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ] else if (authState.status == AuthStatus.error) ...[
            Text(
              'Auth Error',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              authState.errorMessage ?? 'Check connection',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(authProvider.notifier).checkAuthStatus(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                minimumSize: const Size(100, 32),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ] else ...[
            const Text(
              'Guest User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Login to sync your library',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
