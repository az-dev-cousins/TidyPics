import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/document_file.dart';
import '../../../data/providers.dart';

/// Où en est le tri des documents.
@immutable
class DocumentSortState {
  const DocumentSortState({
    this.queue = const [],
    this.toTrash = const [],
    this.history = const [],
    this.failed = const [],
    this.freedBytes = 0,
    this.freedCount = 0,
    this.finished = false,
  });

  final List<DocumentFile> queue;

  /// Au panier des documents, pas encore supprimés.
  final List<DocumentFile> toTrash;

  /// Décisions récentes, pour annuler : (fichier, mis au panier).
  final List<(DocumentFile, bool)> history;

  /// N'ont pas pu être supprimés (fichier en lecture seule…).
  final List<DocumentFile> failed;

  final int freedBytes;
  final int freedCount;

  /// Le récap a été validé.
  final bool finished;

  DocumentFile? get current => queue.firstOrNull;
  int get toTrashBytes => toTrash.fold(0, (s, f) => s + f.sizeBytes);

  DocumentSortState copyWith({
    List<DocumentFile>? queue,
    List<DocumentFile>? toTrash,
    List<(DocumentFile, bool)>? history,
    List<DocumentFile>? failed,
    int? freedBytes,
    int? freedCount,
    bool? finished,
  }) => DocumentSortState(
    queue: queue ?? this.queue,
    toTrash: toTrash ?? this.toTrash,
    history: history ?? this.history,
    failed: failed ?? this.failed,
    freedBytes: freedBytes ?? this.freedBytes,
    freedCount: freedCount ?? this.freedCount,
    finished: finished ?? this.finished,
  );
}

/// Tri des documents au swipe : gauche = au panier, droite = garder. Les
/// plus gros d'abord. Rien n'est supprimé avant le récap.
class DocumentSession extends Notifier<DocumentSortState> {
  static const undoDepth = 10;

  @override
  DocumentSortState build() => const DocumentSortState();

  /// Démarre un tri. [skipKept] : sans les documents déjà gardés (dossier
  /// trié une autre fois).
  Future<void> start(List<DocumentFile> files, {bool skipKept = true}) async {
    final kept = skipKept
        ? await ref.read(documentRepositoryProvider).keptUris()
        : const <String>{};
    final queue = {
      for (final f in files)
        if (!kept.contains(f.uri)) f.uri: f,
    }.values.toList()..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    state = DocumentSortState(queue: queue);
  }

  Future<void> decide({required bool trash}) async {
    final file = state.current;
    if (file == null) return;
    final history = [...state.history, (file, trash)];
    if (history.length > undoDepth) history.removeAt(0);
    state = state.copyWith(
      queue: state.queue.sublist(1),
      toTrash: trash ? [...state.toTrash, file] : state.toTrash,
      history: history,
    );
    if (!trash) await ref.read(documentRepositoryProvider).keep(file.uri);
  }

  Future<void> undo() async {
    if (state.history.isEmpty) return;
    final (file, trashed) = state.history.last;
    state = state.copyWith(
      queue: [file, ...state.queue],
      toTrash: [
        for (final f in state.toTrash)
          if (f != file) f,
      ],
      history: state.history.sublist(0, state.history.length - 1),
    );
    if (!trashed) await ref.read(documentRepositoryProvider).unkeep(file.uri);
  }

  /// Retire un document du panier au récap : il sera reproposé plus tard.
  void release(DocumentFile file) => state = state.copyWith(
    toTrash: [
      for (final f in state.toTrash)
        if (f != file) f,
    ],
  );

  /// Récap validé : à la corbeille de TidyPics (récupérables 30 jours).
  /// Ceux qui n'ont pas pu y aller restent dans [DocumentSortState.failed].
  Future<void> trashAll() async {
    final files = state.toTrash;
    if (files.isEmpty) {
      state = state.copyWith(finished: true);
      return;
    }
    final done = await ref.read(documentRepositoryProvider).trash(files);
    final ok = done.toSet();
    state = state.copyWith(
      toTrash: const [],
      failed: [
        for (final f in files)
          if (!ok.contains(f)) f,
      ],
      freedBytes: state.freedBytes + done.fold(0, (s, f) => s + f.sizeBytes),
      freedCount: state.freedCount + done.length,
      finished: true,
    );
  }
}

final documentSessionProvider =
    NotifierProvider<DocumentSession, DocumentSortState>(DocumentSession.new);

/// Dossiers dont l'accès est donné (« Trier mes documents »).
final documentFoldersProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(documentSourceProvider).folders(),
);

/// La corbeille des documents.
final documentTrashProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(documentRepositoryProvider).watchTrash(),
);
