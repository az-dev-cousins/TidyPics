import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/photo_groups.dart';
import '../data/sources/gallery_source.dart';
import '../features/cart/presentation/checkpoint_page.dart';
import '../features/duplicates/presentation/duplicates_page.dart';
import '../features/gallery/application/gallery_controller.dart';
import '../features/home/presentation/home_page.dart';
import '../features/months/presentation/months_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/permission_page.dart';
import '../features/raw_pairs/presentation/raw_pairs_page.dart';
import '../features/raw_pairs/presentation/raw_sort_page.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/stats/presentation/stats_page.dart';
import '../features/swipe/application/swipe_session.dart';
import '../features/swipe/presentation/burst_page.dart';
import '../features/swipe/presentation/swipe_page.dart';
import '../features/trash/presentation/trash_page.dart';

/// Chemins des routes, pour ne jamais écrire une URL en dur.
abstract final class AppRoutes {
  static const swipe = '/';
  static const home = '/menu';
  static const onboarding = '/onboarding';
  static const permission = '/permission';
  static const trash = '/trash';
  static const settings = '/settings';
  static const burst = '/burst';
  static const months = '/months';
  static const stats = '/stats';
  static const rawPairs = '/raw-pairs';
  static const rawSort = '/raw-sort';
  static const duplicates = '/duplicates';
  static const _checkpoint = '/checkpoint';
  static const _month = '/month';

  /// Tri d'un seul mois.
  static String month(int year, int month) => '$_month/$year/$month';

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
    initialLocation: AppRoutes.swipe,
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
        return AppRoutes.swipe;
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
        path: AppRoutes.burst,
        builder: (context, state) => BurstPage(item: state.extra! as PhotoItem),
      ),
      GoRoute(
        path: AppRoutes.months,
        builder: (context, state) => const MonthsPage(),
      ),
      GoRoute(
        path: '${AppRoutes._month}/:year/:month',
        builder: (context, state) => SwipePage(
          scope: SwipeScope.month(
            int.parse(state.pathParameters['year']!),
            int.parse(state.pathParameters['month']!),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.stats,
        builder: (context, state) => const StatsPage(),
      ),
      GoRoute(
        path: AppRoutes.rawPairs,
        builder: (context, state) => const RawPairsPage(),
      ),
      GoRoute(
        path: AppRoutes.rawSort,
        builder: (context, state) => const RawSortPage(),
      ),
      GoRoute(
        path: AppRoutes.duplicates,
        builder: (context, state) => const DuplicatesPage(),
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
