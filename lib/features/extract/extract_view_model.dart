/// ViewModel for independently processing one extract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/extract/extraction_commands.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/library/library_view_model.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/result.dart';

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
    this.effectiveDueDay,
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

  /// When this extract may next be presented, adjustments included. Showing
  /// the canonical date instead would report a Later as if it never happened.
  final StudyDay? effectiveDueDay;
  final String? lastExtractId;
  final UiMessage? message;
  final bool isBusy;
  final bool isDone;

  bool get canMutate => mode == ExtractMode.scheduled;
  bool get canEdit => children.isEmpty;

  Map<String, int> get extractMarksByBlock {
    final counts = <String, int>{};
    for (final child in children) {
      final blockId = _startBlockId(child);
      if (blockId == null) continue;
      counts[blockId] = (counts[blockId] ?? 0) + 1;
    }
    return counts;
  }

  List<Extract> extractsStartingIn(String blockId) => <Extract>[
    for (final child in children)
      if (_startBlockId(child) == blockId) child,
  ];

  /// Block a child's recorded range starts in, or null when its link back to
  /// this text has degraded and no longer names a place here.
  String? _startBlockId(Extract child) {
    if (!child.provenance.isIntact) return null;
    return document.blockAtOffset(child.provenance.startUtf8)?.id;
  }

  ExtractUiState copyWith({
    Extract? extract,
    Document? document,
    TopicState? topic,
    ExtractMode? mode,
    List<Extract>? children,
    List<Card>? cards,
    StudyDay? effectiveDueDay,
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
    effectiveDueDay: effectiveDueDay ?? this.effectiveDueDay,
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
      effectiveDueDay: await ref
          .read(effectiveDueQueryProvider)
          .forTopic(topic),
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
        !current.document.isSameBlock(range)) {
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

  /// Later: moves eligibility without advancing anything.
  ///
  /// With no explicit day the handler scales the delay by the extract's own
  /// interval, because a fixed one day just returns it tomorrow into an
  /// equally full queue.
  Future<void> later({int? days}) async {
    final current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    final StudyDay? until = days == null
        ? null
        : (await ref.read(readerHandlersProvider).today()).addDays(days);
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerHandlersProvider)
          .postpone(
            PostponeElement(operation, ref: current.topic.ref, until: until),
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
