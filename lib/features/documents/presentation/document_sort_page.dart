import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/document_file.dart';
import '../../../data/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../swipe/application/swipe_session.dart';
import '../../swipe/presentation/swipe_card.dart';
import '../../swipe/presentation/swipe_deck.dart';
import '../../swipe/presentation/swipe_page.dart';
import '../application/document_session.dart';

/// Aperçu d'un document : première page d'un PDF, début du texte d'un
/// Word, image… ou rien (une icône).
typedef DocumentPreview = ({Uint8List? image, int? pages, String? text});

final documentPreviewProvider = FutureProvider.autoDispose
    .family<DocumentPreview, DocumentFile>((ref, file) async {
      final source = ref.watch(documentSourceProvider);
      switch (file.kind) {
        case DocumentKind.pdf:
          final pdf = await source.pdfPreview(file.uri);
          return (image: pdf?.png, pages: pdf?.pages, text: null);
        case DocumentKind.image:
          return (
            image: await source.readBytes(file.uri),
            pages: null,
            text: null,
          );
        case DocumentKind.word ||
            DocumentKind.sheet ||
            DocumentKind.slides ||
            DocumentKind.text:
          final bytes = await source.readBytes(file.uri);
          return (
            image: null,
            pages: null,
            text: bytes == null ? null : DocumentText.extract(file, bytes),
          );
        default:
          return (image: null, pages: null, text: null);
      }
    });

/// Tri des documents au swipe, puis récap avant d'envoyer à la corbeille.
class DocumentSortPage extends ConsumerStatefulWidget {
  const DocumentSortPage({super.key});

  @override
  ConsumerState<DocumentSortPage> createState() => _DocumentSortPageState();
}

class _DocumentSortPageState extends ConsumerState<DocumentSortPage> {
  final _deck = GlobalKey<SwipeDeckState>();
  bool _recap = false;
  bool _working = false;
  late final int _total = ref.read(documentSessionProvider).queue.length;

  DocumentSession get _session => ref.read(documentSessionProvider.notifier);

  void _press(SwipeChoice choice) => _deck.currentState?.swipe(choice);

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await _session.trashAll();
      final state = ref.read(documentSessionProvider);
      messenger.hideCurrentSnackBar();
      if (state.failed.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.documentsFailed(l10n.documentsFiles(state.failed.length)),
            ),
          ),
        );
      } else if (state.freedCount > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.documentsDone(
                l10n.documentsFiles(state.freedCount),
                l10n.fileSize(state.freedBytes),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(documentSessionProvider);
    final current = state.current;
    final showRecap = _recap || current == null;
    final done = _total - state.queue.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(showRecap ? l10n.documentsRecapTitle : l10n.documentsTitle),
        actions: [
          if (!showRecap)
            TextButton(
              onPressed: () => setState(() => _recap = true),
              child: Text(l10n.swipeStop),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: showRecap
                ? _Recap(
                    state: state,
                    working: _working,
                    onSend: _send,
                    onRelease: _session.release,
                    onFinish: () => context.pop(),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Row(
                          children: [
                            Text(l10n.documentsProgress(done, _total)),
                            const Spacer(),
                            if (state.toTrash.isNotEmpty)
                              Text(
                                '${state.toTrash.length} · '
                                '${l10n.fileSize(state.toTrashBytes)}',
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: SwipeDeck(
                            key: _deck,
                            currentKey: current.uri,
                            nextKey: state.queue.length > 1
                                ? state.queue[1].uri
                                : null,
                            // Pas de favori pour un document.
                            accepts: (c) => c != SwipeChoice.favorite,
                            currentCard:
                                (
                                  context, {
                                  required isCurrent,
                                  stamp,
                                  strength = 0,
                                }) => DocumentCard(
                                  file: current,
                                  stamp: stamp,
                                  strength: strength,
                                ),
                            nextCard: state.queue.length > 1
                                ? (context) =>
                                      DocumentCard(file: state.queue[1])
                                : null,
                            onSwiped: (c) => unawaited(
                              _session.decide(trash: c == SwipeChoice.trash),
                            ),
                          ),
                        ),
                      ),
                      _Actions(
                        canUndo: state.history.isNotEmpty,
                        onUndo: () => unawaited(_session.undo()),
                        onPress: _press,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.canUndo,
    required this.onUndo,
    required this.onPress,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final ValueChanged<SwipeChoice> onPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: l10n.swipeUndo,
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          SwipeRoundButton(
            tooltip: l10n.swipeTrash,
            size: 72,
            background: theme.colorScheme.surfaceContainer,
            border: BorderSide(color: tidy.delete, width: 2),
            onPressed: () => onPress(SwipeChoice.trash),
            child: Icon(Icons.close_rounded, color: tidy.delete, size: 34),
          ),
          SwipeRoundButton(
            tooltip: l10n.swipeKeep,
            size: 72,
            background: tidy.keep,
            onPressed: () => onPress(SwipeChoice.keep),
            child: Icon(Icons.check_rounded, color: tidy.onKeep, size: 34),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Carte d'un document : aperçu, nom, taille, date, dossier, « Ouvrir ».
class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.file,
    this.stamp,
    this.strength = 0,
  });

  final DocumentFile file;
  final SwipeChoice? stamp;
  final double strength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final preview = ref.watch(documentPreviewProvider(file)).value;
    final modified = file.modified;
    final caption = [
      if (modified != null) l10n.shortDate(modified),
      l10n.fileSize(file.sizeBytes).toUpperCase(),
      if (preview?.pages != null)
        l10n.documentsPages(preview!.pages!).toUpperCase(),
    ].join(' · ');

    Widget body;
    if (preview?.image != null) {
      body = Image.memory(
        preview!.image!,
        fit: BoxFit.contain,
        cacheWidth: 1200,
        gaplessPlayback: true,
      );
    } else if (preview?.text != null) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tidy.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              preview!.text!,
              overflow: TextOverflow.fade,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    } else {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(file.kind), size: 72, color: tidy.inkMuted),
            const SizedBox(height: 12),
            Text(
              file.extension.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: tidy.inkMuted,
              ),
            ),
          ],
        ),
      );
    }

    return SwipeCardFrame(
      caption: caption,
      folder: file.folder == null || file.folder!.isEmpty
          ? null
          : file.folder!.substring(0, file.folder!.length - 1),
      stamp: stamp,
      strength: strength,
      image: Stack(
        fit: StackFit.expand,
        children: [
          body,
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _icon(file.kind),
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (!await ref.read(documentSourceProvider).open(file)) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.documentsOpenFailed)),
                      );
                    }
                  },
                  child: Text(l10n.documentsOpen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _icon(DocumentKind kind) => switch (kind) {
  DocumentKind.pdf => Icons.picture_as_pdf_outlined,
  DocumentKind.word => Icons.description_outlined,
  DocumentKind.sheet => Icons.table_chart_outlined,
  DocumentKind.slides => Icons.slideshow_outlined,
  DocumentKind.text => Icons.notes_rounded,
  DocumentKind.archive => Icons.folder_zip_outlined,
  DocumentKind.apk => Icons.android_rounded,
  DocumentKind.image => Icons.image_outlined,
  DocumentKind.audio => Icons.audiotrack_outlined,
  DocumentKind.video => Icons.movie_outlined,
  DocumentKind.other => Icons.insert_drive_file_outlined,
};

class _Recap extends StatelessWidget {
  const _Recap({
    required this.state,
    required this.working,
    required this.onSend,
    required this.onRelease,
    required this.onFinish,
  });

  final DocumentSortState state;
  final bool working;
  final VoidCallback onSend;
  final ValueChanged<DocumentFile> onRelease;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tidy = TidyColors.of(context);
    final files = state.toTrash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.queue.isEmpty)
                Text(
                  l10n.documentsAllSorted,
                  style: theme.textTheme.titleLarge,
                ),
              Text(
                files.isEmpty
                    ? l10n.documentsRecapNone
                    : l10n.documentsRecapSummary(
                        l10n.documentsFiles(files.length),
                        l10n.fileSize(state.toTrashBytes),
                      ),
                style: theme.textTheme.titleMedium,
              ),
              if (files.isNotEmpty)
                Text(
                  l10n.documentsRecapHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in files)
                ListTile(
                  leading: Icon(_icon(f.kind), color: tidy.delete),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l10n.fileSize(f.sizeBytes)),
                  trailing: Icon(Icons.cancel, color: tidy.delete),
                  onTap: working ? null : () => onRelease(f),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (files.isNotEmpty) ...[
                Text(
                  l10n.documentsSafety,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tidy.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tidy.delete,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: working ? null : onSend,
                  child: Text(
                    l10n.documentsRecapButton(
                      l10n.fileSize(state.toTrashBytes),
                    ),
                  ),
                ),
              ] else
                FilledButton(
                  onPressed: onFinish,
                  child: Text(l10n.documentsFinish),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
