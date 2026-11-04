import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/profile/profile_page.dart';
import '../../providers/app_provider.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';

/// AppBar avatar that opens the profile page. Shows a ring while syncing.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final photo = context.select<AuthService, String?>((a) => a.user?.photoURL);
    final initials = context.select<AppProvider, String>((p) => p.profile?.initials ?? '?');
    final syncing = context.select<AppProvider, bool>((p) => p.isSyncing);
    final hasError = context.select<AppProvider, bool>((p) => p.syncError != null);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Profilim',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfilePage())),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(gradient: AppTheme.brandGradient, shape: BoxShape.circle),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  backgroundImage: photo == null ? null : NetworkImage(photo),
                  child: photo == null
                      ? Text(initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))
                      : null,
                ),
              ),
              if (syncing)
                const SizedBox.square(dimension: 46, child: CircularProgressIndicator(strokeWidth: 2)),
              if (hasError && !syncing)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
