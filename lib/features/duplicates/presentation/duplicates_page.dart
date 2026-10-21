import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/duplicates.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/providers.dart';
import '../../../data/sources/local_db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';
import 'duplicate_viewer.dart';

/// Doublons (F11) : la même photo enregistrée plusieurs fois. Dans chaque
/// groupe, la meilleure est gardée et les autres sont cochées pour partir ;
/// un tap change d'avis. Tout part à la corbeille en un seul lot.
class DuplicatesPage extends ConsumerStatefulWidget {
  const DuplicatesPage({super.key});

  @override
  ConsumerState<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends ConsumerState<DuplicatesPage> {
  /// Photos dont l'utilisateur a changé le choix proposé.
  final _flipped = <String>{};
  bool _working = false;

  bool _kept(DuplicateGroup group, GalleryPhoto photo) =>
      (photo.id == group.best.id) != _flipped.contains(photo.id);

  List<GalleryPhoto> _discarded(List<DuplicateGroup> groups) => [
    for (final group in groups)
      for (final photo in group.photos)
        if (!_kept(group, photo)) photo,
  ];

  void _toggle(GalleryPhoto photo) => setState(() {
    if (!_flipped.remove(photo.id)) _flipped.add(photo.id);
  });

  Future<void> _apply(List<DuplicateGroup> groups) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final discarded = _discarded(groups);
    final discardedIds = discarded.map((p) => p.id).toSet();
    setState(() => _working = true);
    try {
      final outcome = discarded.isEmpty
          ? null
          : await ref.read(trashRepositoryProvider).trash(discarded);
      if (outcome != null && outcome.count == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.checkpointRefused)));
        return;
      }
      if (outcome != null) {
        await ref
            .read(progressRepositoryProvider)
            .recordMilestone(Milestone.duplicateDeleted);
      }
      // Les photos gardées ici ne seront plus proposées au tri.
      final library = ref.read(libraryRepositoryProvider);
      for (final photo in groups.expand((g) => g.photos)) {
        if (!discardedIds.contains(photo.id)) {
          await library.decide(photo, Decision.kept);
        }
      }
      unawaited(ref.read(gallerySyncProvider.notifier).scan());
      if (outcome != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.checkpointDone(
                l10n.photoCount(outcome.count),
                l10n.fileSize(outcome.bytes),
              ),
            ),
          ),
        );
      }
      if (mounted) setState(_flipped.clear);
    } on Object catch (error) {
      debugPrint('Suppression des doublons impossible : $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.checkpointFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final groups = ref.watch(duplicatesProvider).value;
    final progress = ref.watch(hashProgressProvider).value;
    final analysing = progress != null && progress.done < progress.total;
    final discarded = groups == null
        ? const <GalleryPhoto>[]
        : _discarded(groups);
    final bytes = discarded.fold(0, (s, p) => s + (p.sizeBytes ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duplicatesTitle),
        actions: [
          if (groups != null && groups.isNotEmpty)
            TextButton.icon(
              onPressed: _working
                  ? null
                  : () => context.push(AppRoutes.duplicatesSwipe),
              icon: const Icon(Icons.swipe_outlined),
              label: Text(l10n.duplicatesSwipe),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (analysing) ...[
                  _Analysing(done: progress.done, total: progress.total),
                  const SizedBox(height: 16),
                ],
                if (groups == null)
                  const Center(child: CircularProgressIndicator())
                else if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Text(
                      analysing ? l10n.duplicatesNoneYet : l10n.duplicatesNone,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: tidy.inkMuted,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    l10n.duplicatesIntro(groups.length),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tidy.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bytes == 0
                        ? l10n.rawNothingToFree
                        : l10n.rawToFree(l10n.fileSize(bytes)),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.duplicatesHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tidy.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final group in groups) ...[
                    _GroupCard(
                      group: group,
                      kept: (photo) => _kept(group, photo),
                      onToggle: _working ? null : _toggle,
                      onOpen: (index) => showDuplicateViewer(
                        context,
                        group: group,
                        initialIndex: index,
                        kept: (photo) => _kept(group, photo),
                        onToggle: _toggle,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: groups == null || groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  style: discarded.isEmpty
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: tidy.delete,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                  onPressed: _working ? null : () => _apply(groups),
                  child: Text(
                    discarded.isEmpty
                        ? l10n.rawKeepAllCta
                        : l10n.checkpointDelete(
                            l10n.photoCount(discarded.length),
                            l10n.fileSize(bytes),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Analysing extends StatelessWidget {
  const _Analysing({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final ratio = total == 0 ? 0.0 : done / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.duplicatesAnalysing(l10n.percent((ratio * 100).floor())),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: tidy.line,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.duplicatesAnalysingHint,
              style: theme.textTheme.bodySmall?.copyWith(color: tidy.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.kept,
    required this.onToggle,
    required this.onOpen,
  });

  final DuplicateGroup group;
  final bool Function(GalleryPhoto photo) kept;
  final ValueChanged<GalleryPhoto>? onToggle;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, photo) in group.photos.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                _Member(
                  photo: photo,
                  kept: kept(photo),
                  onToggle: onToggle == null ? null : () => onToggle!(photo),
                  onOpen: () => onOpen(i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Member extends StatelessWidget {
  const _Member({
    required this.photo,
    required this.kept,
    required this.onToggle,
    required this.onOpen,
  });

  final GalleryPhoto photo;
  final bool kept;

  /// Le rond en haut à droite : garder ou supprimer.
  final VoidCallback? onToggle;

  /// La photo : l'ouvrir en grand.
  final VoidCallback onOpen;

  static const _side = 104.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final size = photo.sizeBytes ?? 0;
    final details = [
      if (photo.width > 0) '${photo.width} × ${photo.height}',
      if (size > 0) l10n.fileSize(size),
    ].join(' · ');
    final state = kept ? l10n.duplicatesKept : l10n.duplicatesDeleted;

    return Semantics(
      button: true,
      label: [?photo.folderName, details, state].join(' · '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onOpen,
        child: SizedBox(
          width: _side,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: _side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: kept ? 1 : 0.35,
                      child: PhotoThumbnail(photo: photo, size: 240),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusThumbnail,
                        ),
                        border: Border.all(
                          color: kept ? tidy.keep : tidy.delete,
                          width: 3,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onToggle,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            kept ? Icons.check_circle : Icons.cancel,
                            color: kept ? tidy.keep : tidy.delete,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                photo.folderName ?? state,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
              if (details.isNotEmpty)
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
