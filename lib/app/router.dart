import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/sources/gallery_source.dart';
import '../features/cart/presentation/checkpoint_page.dart';
import '../features/gallery/application/gallery_controller.dart';
import '../features/home/presentation/home_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/permission_page.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/swipe/presentation/swipe_page.dart';
import '../features/trash/presentation/trash_page.dart';

/// Chemins des routes, pour ne jamais écrire une URL en dur.
abstract final class AppRoutes {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const permission = '/permission';
  static const swipe = '/swipe';
  static const trash = '/trash';
  static const settings = '/settings';
  static const _checkpoint = '/checkpoint';

  static String checkpoint(CheckpointOrigin origin) =>
      '$_checkpoint?from=${origin.name}';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Prévient le routeur quand l'onboarding ou l'accès aux photos change.
  final refresh = _RouterRefresh();
  ref
    ..listen(
      settingsProvider.select((s) => s.onboardingDone),
      (_, _) => refresh.ping(),
    )
    ..listen(galleryAccessProvider, (_, _) => refresh.ping());

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      String? goTo(String target) => location == target ? null : target;

      if (!ref.read(settingsProvider).onboardingDone) {
        return goTo(AppRoutes.onboarding);
      }
      final access = ref.read(galleryAccessProvider).value;
      if (access == null) return null; // Encore en lecture.
      if (access == GalleryAccess.denied ||
          access == GalleryAccess.notDetermined) {
        return goTo(AppRoutes.permission);
      }
      if (location == AppRoutes.onboarding ||
          location == AppRoutes.permission) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.permission,
        builder: (context, state) => const PermissionPage(),
      ),
      GoRoute(
        path: AppRoutes.swipe,
        builder: (context, state) => const SwipePage(),
      ),
      GoRoute(
        path: AppRoutes._checkpoint,
        builder: (context, state) {
          final from = state.uri.queryParameters['from'];
          final origin = CheckpointOrigin.values
              .where((o) => o.name == from)
              .firstOrNull;
          return CheckpointPage(origin: origin ?? CheckpointOrigin.home);
        },
      ),
      GoRoute(
        path: AppRoutes.trash,
        builder: (context, state) => const TrashPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
