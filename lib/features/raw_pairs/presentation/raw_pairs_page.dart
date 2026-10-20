import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/gallery_photo.dart';
import '../../../data/models/photo_groups.dart';
import '../../../data/providers.dart';
import '../../../data/sources/local_db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/photo_image.dart';
import '../../gallery/application/gallery_controller.dart';

/// Ce qu'on garde d'une paire JPG + RAW.
enum RawKeep { jpg, raw, both }

/// Doublons JPG + RAW (F6) : un choix pour toutes les paires, modifiable
/// paire par paire d'un tap. Les fichiers écartés partent à la corbeille
/// en un seul lot.
class RawPairsPage extends ConsumerStatefulWidget {
  const RawPairsPage({super.key});

  @override
  ConsumerState<RawPairsPage> createState() => _RawPairsPageState();
}

class _RawPairsPageState extends ConsumerState<RawPairsPage> {
  RawKeep _all = RawKeep.jpg;

  /// Choix différents du choix général, par paire.
  final _overrides = <String, RawKeep>{};

  /// Tailles lues à l'ouverture (elles ne sont pas toujours connues).
  final _sizes = <String, int>{};
  bool _working = false;
  bool _loadingSizes = false;

  RawKeep _keepFor(PhotoItem pair) => _overrides[pair.id] ?? _all;

  int _size(GalleryPhoto photo) => _sizes[photo.id] ?? photo.sizeBytes ?? 0;

  /// Les fichiers qui partiront à la corbeille avec les choix actuels.
  List<GalleryPhoto> _discarded(List<PhotoItem> pairs) => [
    for (final pair in pairs)
      ...switch (_keepFor(pair)) {
        RawKeep.jpg => [pair.photos[1]],
        RawKeep.raw => [pair.photos[0]],
        RawKeep.both => const <GalleryPhoto>[],
      },
  ];

  Future<void> _loadSizes(List<PhotoItem> pairs) async {
    if (_loadingSizes) return;
    _loadingSizes = true;
    final gallery = ref.read(gallerySourceProvider);
    final library = ref.read(libraryRepositoryProvider);
    for (final photo in pairs.expand((p) => p.photos)) {
      if (photo.sizeBytes != null || _sizes.containsKey(photo.id)) continue;
      final size = await gallery.fileSize(photo.id);
      await library.setSize(photo.id, size);
      if (!mounted) return;
      setState(() => _sizes[photo.id] = size);
    }
    _loadingSizes = false;
  }

  void _cycle(PhotoItem pair) {
    const order = [RawKeep.jpg, RawKeep.raw, RawKeep.both];
    final next = order[(order.indexOf(_keepFor(pair)) + 1) % order.length];
    setState(() {
      if (next == _all) {
        _overrides.remove(pair.id);
      } else {
        _overrides[pair.id] = next;
      }
    });
  }

  Future<void> _apply(List<PhotoItem> pairs) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final discarded = [
      for (final p in _discarded(pairs)) p.copyWith(sizeBytes: _size(p)),
    ];
    final discardedIds = discarded.map((p) => p.id).toSet();
    setState(() => _working = true);
    try {
      final library = ref.read(libraryRepositoryProvider);
      final outcome = discarded.isEmpty
          ? null
          : await ref.read(trashRepositoryProvider).trash(discarded);
      if (outcome != null && outcome.count == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.checkpointRefused)));
        return;
      }
      // Les fichiers gardés ne seront plus proposés au tri.
      for (final photo in pairs.expand((p) => p.photos)) {
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
      setState(_overrides.clear);
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
    final pairs = ref.watch(rawPairsProvider).value;
    if (pairs != null) unawaited(_loadSizes(pairs));

    final discarded = pairs == null
        ? const <GalleryPhoto>[]
        : _discarded(pairs);
    final bytes = discarded.fold(0, (s, p) => s + _size(p));
    final what = switch (_all) {
      RawKeep.jpg => l10n.rawWhatRaw,
      RawKeep.raw => l10n.rawWhatJpg,
      RawKeep.both => '',
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.swipeRawPairBadge)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: pairs == null
                ? const Center(child: CircularProgressIndicator())
                : pairs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        l10n.rawEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: tidy.inkMuted,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Text(
                        l10n.rawIntro(pairs.length),
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
                      const SizedBox(height: 20),
                      Text(
                        l10n.rawForAll.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tidy.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<RawKeep>(
                        segments: [
                          ButtonSegment(
                            value: RawKeep.jpg,
                            label: Text(l10n.rawKeepJpg),
                          ),
                          ButtonSegment(
                            value: RawKeep.raw,
                            label: Text(l10n.rawKeepRaw),
                          ),
                          ButtonSegment(
                            value: RawKeep.both,
                            label: Text(l10n.rawKeepBoth),
                          ),
                        ],
                        selected: {_all},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() {
                          _all = s.first;
                          _overrides.clear();
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.rawTapHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tidy.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            for (final (i, pair) in pairs.indexed) ...[
                              if (i > 0) const Divider(height: 1),
                              _PairRow(
                                pair: pair,
                                keep: _keepFor(pair),
                                sizeOf: _size,
                                onTap: _working ? null : () => _cycle(pair),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: pairs == null || pairs.isEmpty
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
                  onPressed: _working ? null : () => _apply(pairs),
                  child: Text(
                    discarded.isEmpty
                        ? l10n.rawKeepAllCta
                        : _overrides.isEmpty && what.isNotEmpty
                        ? l10n.rawDeleteCta(what, l10n.fileSize(bytes))
                        : l10n.rawDeleteFilesCta(
                            discarded.length,
                            l10n.fileSize(bytes),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PairRow extends ConsumerWidget {
  const _PairRow({
    required this.pair,
    required this.keep,
    required this.sizeOf,
    required this.onTap,
  });

  final PhotoItem pair;
  final RawKeep keep;
  final int Function(GalleryPhoto photo) sizeOf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final jpg = pair.photos[0];
    final raw = pair.photos[1];
    final name = jpg.title ?? raw.title ?? '';
    final base = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;

    Widget thumb(GalleryPhoto photo, String tag, bool kept) => SizedBox.square(
      dimension: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: kept ? 1 : 0.3,
            child: PhotoThumbnail(photo: photo, size: 140),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(tag, style: theme.textTheme.labelSmall),
              ),
            ),
          ),
        ],
      ),
    );

    final keepLabel = switch (keep) {
      RawKeep.jpg => l10n.rawKeepJpg,
      RawKeep.raw => l10n.rawKeepRaw,
      RawKeep.both => l10n.rawKeepBoth,
    };

    return Semantics(
      button: true,
      label: '$base · $keepLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              thumb(jpg, 'JPG', keep != RawKeep.raw),
              const SizedBox(width: 6),
              thumb(raw, 'RAW', keep != RawKeep.jpg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      base,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'JPG ${l10n.fileSize(sizeOf(jpg))} · '
                      'RAW ${l10n.fileSize(sizeOf(raw))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tidy.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tidy.mint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    keepLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tidy.onMint,
                    ),
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
