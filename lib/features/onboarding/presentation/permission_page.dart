import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../gallery/application/gallery_controller.dart';

/// Affiché tant que l'accès aux photos est refusé (§3.3).
class PermissionPage extends ConsumerWidget {
  const PermissionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.no_photography_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.permissionTitle,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.permissionBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tidy.inkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () =>
                        ref.read(gallerySourceProvider).openAppSettings(),
                    child: Text(l10n.permissionOpenSettings),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    // Android repropose la popup une fois après un refus.
                    // Ensuite, le système répond « refusé » directement.
                    onPressed: () =>
                        ref.read(galleryAccessProvider.notifier).request(),
                    child: Text(l10n.permissionRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
