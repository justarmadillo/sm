/// ViewModel for independently processing one extract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/extraction/extraction_commands.dart';
import '../../../application/formulation/formulation_commands.dart';
import '../../../application/reader/reader_commands.dart';
import '../../../core/result.dart';
import '../../../core/tracing.dart';
import '../../../domain/content/card.dart';
import '../../../domain/content/document.dart';
import '../../../domain/content/extract.dart';
import '../../../domain/content/reader_anchor.dart';
import '../../../domain/scheduling/element.dart';
import '../../../domain/scheduling/topic_scheduler.dart';
import '../../library/presentation/library_view_model.dart';

/// Whether the extract is being processed or only consulted for context.
enum ExtractMode { scheduled, browse }

@immutable
final class ExtractRequest {
  const ExtractRequest({
    required this.extractId,
    this.mode = ExtractMode.browse,
    this.initialAnchor,
  });

  final String extractId;
  final ExtractMode mode;
  final ReaderAnchor? initialAnchor;

  @override
  bool operator ==(Object other) =>
      other is ExtractRequest &&
      other.extractId == extractId &&
      other.mode == mode &&
      other.initialAnchor == initialAnchor;

  @override
  int get hashCode => Object.hash(extractId, mode, initialAnchor);
}

@immutable
final class ExtractUiState {
  const ExtractUiState({
    required this.extract,
    required this.document,
    required this.topic,
    required this.mode,
    required this.children,
    required this.cards,
    this.lastExtractId,
    this.message,
    this.isBusy = false,
    this.isDone = false,
  });

  final Extract extract;
  final Document document;
  final TopicState topic;
  final ExtractMode mode;
  final List<Extract> children;
  final List<Card> cards;
  final String? lastExtractId;
  final UiMessage? message;
  final bool isBusy;
  final bool isDone;

  bool get canMutate => mode == ExtractMode.scheduled;
  bool get canEdit => children.isEmpty;

  Map<String, int> get extractMarksByBlock {
    final counts = <String, int>{};
    for (final child in children) {
      final blockId = child.provenance.startAnchor.blockId;
      counts[blockId] = (counts[blockId] ?? 0) + 1;
    }
    return counts;
  }

  List<Extract> extractsStartingIn(String blockId) => <Extract>[
    for (final child in children)
      if (child.provenance.startAnchor.blockId == blockId) child,
  ];

  ExtractUiState copyWith({
    Extract? extract,
    Document? document,
    TopicState? topic,
    ExtractMode? mode,
    List<Extract>? children,
    List<Card>? cards,
    String? lastExtractId,
    bool clearLastExtract = false,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
    bool? isDone,
  }) => ExtractUiState(
    extract: extract ?? this.extract,
    document: document ?? this.document,
    topic: topic ?? this.topic,
    mode: mode ?? this.mode,
    children: children ?? this.children,
    cards: cards ?? this.cards,
    lastExtractId: clearLastExtract
        ? null
        : (lastExtractId ?? this.lastExtractId),
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
    isDone: isDone ?? this.isDone,
  );
}

final class ExtractViewModel
    extends FamilyAsyncNotifier<ExtractUiState, ExtractRequest> {
  DateTime? _sessionStartedAt;

  @override
  Future<ExtractUiState> build(ExtractRequest arg) async {
    _sessionStartedAt = ref.read(clockProvider).nowUtc();
    return _load(arg.mode);
  }

  Future<ExtractUiState> _load(ExtractMode mode) async {
    final content = ref.read(contentRepositoryProvider);
    final extract = await content.findExtract(arg.extractId);
    if (extract == null) {
      throw StateError('extract ${arg.extractId} is not in the library');
    }
    final topic = await ref
        .read(learningRepositoryProvider)
        .findTopic(ElementRef(id: extract.id, type: ElementType.extract));
    if (topic == null) {
      throw StateError('extract ${arg.extractId} has no schedule');
    }
    return ExtractUiState(
      extract: extract,
      document: Document.parse(
        sourceId: extract.id,
        markdown: extract.markdown,
      ),
      topic: topic,
      mode: mode,
      children: await content.listExtractsOfParent(extract.id),
      cards: await content.listCardsOfExtract(extract.id),
    );
  }

  void continueScheduled() {
    final current = state.valueOrNull;
    if (current == null || current.canMutate) return;
    state = AsyncValue<ExtractUiState>.data(
      current.copyWith(
        mode: ExtractMode.scheduled,
        message: const UiMessage('Processing for today'),
      ),
    );
  }

  Future<void> edit(String markdown) async {
    final current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    await _command<Extract>(
      (OperationId operation) => ref
          .read(extractionHandlersProvider)
          .editExtract(
            EditExtract(
              operation,
              extractId: current.extract.id,
              markdown: markdown,
            ),
          ),
      apply: (ExtractUiState latest, Extract extract) => latest.copyWith(
        extract: extract,
        document: Document.parse(
          sourceId: extract.id,
          markdown: extract.markdown,
        ),
      ),
      success: (_) => 'Extract updated',
    );
  }

  Future<Extract?> extractSelection(SelectionRange range) async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.canMutate ||
        current.isBusy ||
        !range.isSameBlock) {
      return null;
    }
    state = AsyncValue<ExtractUiState>.data(current.copyWith(isBusy: true));
    final result = await ref
        .read(extractionHandlersProvider)
        .createExtract(
          CreateExtract(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parentId: current.extract.id,
            parentIsSource: false,
            range: range,
          ),
        );
    final latest = state.valueOrNull ?? current;
    if (result.isErr) {
      state = AsyncValue<ExtractUiState>.data(
        latest.copyWith(
          isBusy: false,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return null;
    }
    final created = result.unwrap();
    state = AsyncValue<ExtractUiState>.data(
      latest.copyWith(
        children: await _reloadChildren(latest.extract.id),
        lastExtractId: created.id,
        isBusy: false,
        message: const UiMessage('Extracted'),
      ),
    );
    return created;
  }

  Future<void> undoExtract(String extractId) async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isBusy ||
        current.lastExtractId != extractId) {
      return;
    }
    state = AsyncValue<ExtractUiState>.data(current.copyWith(isBusy: true));
    final result = await ref
        .read(extractionHandlersProvider)
        .undoExtract(
          UndoExtract(
            OperationId(ref.read(idGeneratorProvider).newId()),
            extractId: extractId,
          ),
        );
    final latest = state.valueOrNull ?? current;
    state = AsyncValue<ExtractUiState>.data(
      latest.copyWith(
        children: await _reloadChildren(latest.extract.id),
        clearLastExtract: true,
        isBusy: false,
        message: result.fold(
          (_) => const UiMessage('Extract removed'),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  Future<void> done() async {
    final current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerHandlersProvider)
          .completeEncounter(
            CompleteTopicEncounter(
              operation,
              ref: current.topic.ref,
              foregroundMs: _foregroundMs(),
            ),
          ),
      apply: (ExtractUiState latest, TopicState topic) =>
          latest.copyWith(topic: topic, isDone: true),
    );
  }

  Future<void> later({int days = 1}) async {
    final current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerHandlersProvider)
          .postpone(
            PostponeElement(
              operation,
              ref: current.topic.ref,
              until: ref.read(readerHandlersProvider).today.addDays(days),
            ),
          ),
      apply: (ExtractUiState latest, TopicState topic) =>
          latest.copyWith(topic: topic, isDone: true),
    );
  }

  Future<void> dismiss() async {
    final current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerHandlersProvider)
          .dismiss(DismissElement(operation, ref: current.topic.ref)),
      apply: (ExtractUiState latest, TopicState topic) =>
          latest.copyWith(topic: topic, isDone: true),
    );
  }

  Future<void> refreshCards() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<ExtractUiState>.data(
      current.copyWith(
        cards: await ref
            .read(contentRepositoryProvider)
            .listCardsOfExtract(current.extract.id),
      ),
    );
  }

  /// Creates linked cards without advancing or dismissing this extract.
  Future<bool> formulate(List<CardDraft> drafts) async {
    final current = state.valueOrNull;
    if (current == null || !current.canMutate || current.isBusy) return false;
    state = AsyncValue<ExtractUiState>.data(current.copyWith(isBusy: true));
    final result = await ref
        .read(formulationHandlersProvider)
        .formulate(
          FormulateCards(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parent: CardParent.extract(current.extract.id),
            drafts: drafts,
          ),
        );
    final latest = state.valueOrNull ?? current;
    if (result.isErr) {
      state = AsyncValue<ExtractUiState>.data(
        latest.copyWith(
          isBusy: false,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return false;
    }
    final cards = result.unwrap();
    state = AsyncValue<ExtractUiState>.data(
      latest.copyWith(
        cards: await ref
            .read(contentRepositoryProvider)
            .listCardsOfExtract(latest.extract.id),
        clearLastExtract: true,
        isBusy: false,
        message: UiMessage(
          '${cards.length} card${cards.length == 1 ? '' : 's'} created',
        ),
      ),
    );
    return true;
  }

  void clearMessage() {
    final current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<ExtractUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }

  Future<List<Extract>> _reloadChildren(String extractId) =>
      ref.read(contentRepositoryProvider).listExtractsOfParent(extractId);

  int? _foregroundMs() {
    final started = _sessionStartedAt;
    if (started == null) return null;
    return ref.read(clockProvider).nowUtc().difference(started).inMilliseconds;
  }

  Future<void> _command<T>(
    Future<Result<T>> Function(OperationId operation) run, {
    required ExtractUiState Function(ExtractUiState state, T value) apply,
    String Function(T value)? success,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<ExtractUiState>.data(current.copyWith(isBusy: true));
    final result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
    );
    final latest = state.valueOrNull ?? current;
    state = AsyncValue<ExtractUiState>.data(
      result.fold(
        (T value) => apply(latest, value).copyWith(
          isBusy: false,
          message: success == null ? null : UiMessage(success(value)),
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }
}

final AsyncNotifierProviderFamily<
  ExtractViewModel,
  ExtractUiState,
  ExtractRequest
>
extractViewModelProvider =
    AsyncNotifierProvider.family<
      ExtractViewModel,
      ExtractUiState,
      ExtractRequest
    >(ExtractViewModel.new);
