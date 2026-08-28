/// ViewModel for the Reader.
///
/// Every schedule-touching action is an explicit command; everything else —
/// scrolling, selecting, opening context — changes only view state. The two
/// modes exist to keep that honest: **browse** mode cannot mutate progress at
/// all, so looking something up in the Library can never be mistaken by the
/// scheduler for having read it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/apply_source_edit.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/extract/extraction_commands.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/library/library_view_model.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/result.dart';

/// How the Reader was opened.
enum ReaderMode {
  /// Opened from the queue to continue processing. Terminal actions apply.
  scheduled,

  /// Opened for reference. Cannot mutate progress or schedules.
  browse,
}

/// Which source to open, and how.
@immutable
final class ReaderRequest {
  const ReaderRequest({
    required this.sourceId,
    this.mode = ReaderMode.browse,
    this.initialAnchor,
  });

  final String sourceId;
  final ReaderMode mode;

  /// Optional provenance position used only to open a browse view in context.
  /// It never mutates the source's resume marker or soft position.
  final ReaderAnchor? initialAnchor;

  @override
  bool operator ==(Object other) =>
      other is ReaderRequest &&
      other.sourceId == sourceId &&
      other.mode == mode &&
      other.initialAnchor == initialAnchor;

  @override
  int get hashCode => Object.hash(sourceId, mode, initialAnchor);
}

/// Everything the Reader screen renders.
@immutable
final class ReaderUiState {
  const ReaderUiState({
    required this.source,
    required this.document,
    required this.topic,
    required this.mode,
    required this.openedAt,
    this.effectiveDueDay,
    this.extracts = const <Extract>[],
    this.cardsFromSource = 0,
    this.lastExtractId,
    this.wordsThisSession = 0,
    this.reminderTarget = 500,
    this.reminderDismissed = false,
    this.softBannerDismissed = false,
    this.message,
    this.isBusy = false,
    this.isDone = false,
    this.wasRepetition = false,
    this.editingBlockId,
    this.canUndoEdit = false,
  });

  final Source source;
  final Document document;
  final TopicState topic;
  final ReaderMode mode;

  /// When this article may next be presented, adjustments included. Null only
  /// before the first load resolves it. Never the canonical due: showing that
  /// would report a Later the user just made as if it had not happened.
  final StudyDay? effectiveDueDay;

  /// Where this session started, for the reminder line.
  final ReaderAnchor? openedAt;

  /// Extracts already taken from this source, for the gutter marks.
  final List<Extract> extracts;

  /// Cards formulated straight from this article, with no extract between.
  final int cardsFromSource;

  /// The most recent extract, so Undo has something to point at.
  final String? lastExtractId;

  /// The block currently open in the editor.
  ///
  /// At most one. Editing is block-scoped so the splice it produces has known
  /// bounds; letting two blocks be open at once would reintroduce the question
  /// of what changed, which is the question this design exists to avoid.
  final String? editingBlockId;

  /// Whether this source has an edit that can be reversed.
  final bool canUndoEdit;

  /// Whether a block is open in the editor.
  bool get isEditing => editingBlockId != null;

  /// Rendered words between [openedAt] and the current position.
  final int wordsThisSession;

  /// How far into a session the reminder line appears. Read from Settings
  /// when the session opens, not compiled in.
  final int reminderTarget;

  final bool reminderDismissed;

  /// Whether the user closed the forgotten-marker banner this session.
  final bool softBannerDismissed;

  /// Ephemeral: shown once, then cleared.
  final UiMessage? message;

  final bool isBusy;

  /// Set once a terminal command has committed and the screen should close.
  final bool isDone;

  /// Whether the terminal command that set [isDone] was a repetition.
  ///
  /// Later Today and Dismiss end the visit without advancing any schedule, so
  /// they must not be counted as work completed.
  final bool wasRepetition;

  /// Whether terminal actions are offered at all.
  bool get canCommitProgress => mode == ReaderMode.scheduled;

  /// The authoritative resume marker.
  ReaderAnchor? get marker => source.resume.marker;

  /// The soft position, shown only when it is ahead of the marker.
  ReaderAnchor? get softPosition =>
      source.resume.hasUnconfirmedPosition ? source.resume.softPosition : null;

  /// Whether to offer forgotten-marker recovery.
  ///
  /// Only worth offering when there is no marker at all — once a marker
  /// exists it is authoritative, and a banner about an older scroll position
  /// is noise. It is also dismissible, because a reminder the user has
  /// already answered should not keep asking.
  bool get showSoftPositionBanner =>
      canCommitProgress &&
      !softBannerDismissed &&
      marker == null &&
      source.resume.softPosition != null;

  /// Whether the nonblocking reminder line should be visible.
  bool get showReminder =>
      canCommitProgress &&
      !reminderDismissed &&
      wordsThisSession >= reminderTarget;

  /// How many extracts start in each block, keyed by block id.
  ///
  /// Persistent gutter marks are the only record the Reader keeps of prior
  /// extraction: the text itself is never altered, so without them a passage
  /// already processed looks identical to one that has not been.
  Map<String, int> get extractMarksByBlock {
    final counts = <String, int>{};
    for (final extract in extracts) {
      final blockId = _startBlockId(extract);
      if (blockId == null) continue;
      counts[blockId] = (counts[blockId] ?? 0) + 1;
    }
    return counts;
  }

  /// Extracts whose selection begins in [blockId].
  List<Extract> extractsStartingIn(String blockId) => <Extract>[
    for (final extract in extracts)
      if (_startBlockId(extract) == blockId) extract,
  ];

  /// Block this extract's recorded range starts in, or null when it has none
  /// in this document: an extract of an extract, or one whose link back has
  /// degraded and no longer describes a place here.
  String? _startBlockId(Extract extract) {
    final provenance = extract.provenance;
    if (!provenance.parentIsSource || !provenance.isIntact) return null;
    if (provenance.parentId != document.sourceId) return null;
    return document.blockAtOffset(provenance.startUtf8)?.id;
  }

  /// How far through the document the marker sits, as a percentage.
  double get progressPercent {
    final anchor = marker;
    if (anchor == null) return 0;
    final index = document.blockIndexAtOffset(anchor.utf8Offset);
    if (index == null || document.blocks.isEmpty) return 0;
    return (index + 1) / document.blocks.length * 100;
  }

  ReaderUiState copyWith({
    Source? source,
    TopicState? topic,
    ReaderMode? mode,
    ReaderAnchor? openedAt,
    List<Extract>? extracts,
    int? cardsFromSource,
    String? lastExtractId,
    bool clearLastExtract = false,
    int? wordsThisSession,
    bool? reminderDismissed,
    bool? softBannerDismissed,
    StudyDay? effectiveDueDay,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
    bool? isDone,
    bool? wasRepetition,
    String? editingBlockId,
    bool clearEditing = false,
    bool? canUndoEdit,
    Document? document,
  }) => ReaderUiState(
    source: source ?? this.source,
    document: document ?? this.document,
    topic: topic ?? this.topic,
    mode: mode ?? this.mode,
    openedAt: openedAt ?? this.openedAt,
    effectiveDueDay: effectiveDueDay ?? this.effectiveDueDay,
    extracts: extracts ?? this.extracts,
    cardsFromSource: cardsFromSource ?? this.cardsFromSource,
    lastExtractId: clearLastExtract
        ? null
        : (lastExtractId ?? this.lastExtractId),
    wordsThisSession: wordsThisSession ?? this.wordsThisSession,
    reminderTarget: reminderTarget,
    reminderDismissed: reminderDismissed ?? this.reminderDismissed,
    softBannerDismissed: softBannerDismissed ?? this.softBannerDismissed,
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
    isDone: isDone ?? this.isDone,
    wasRepetition: wasRepetition ?? this.wasRepetition,
    editingBlockId: clearEditing ? null : (editingBlockId ?? this.editingBlockId),
    canUndoEdit: canUndoEdit ?? this.canUndoEdit,
  );
}

/// The Reader's ViewModel, one per open source.
final class ReaderViewModel
    extends FamilyAsyncNotifier<ReaderUiState, ReaderRequest> {
  DateTime? _sessionStartedAt;
  int _extractsThisSession = 0;
  Future<void> _positionWrites = Future<void>.value();

  @override
  Future<ReaderUiState> build(ReaderRequest arg) async {
    _sessionStartedAt = ref.read(clockProvider).nowUtc();
    return _load(arg.mode);
  }

  Future<ReaderUiState> _load(ReaderMode mode) async {
    final content = ref.read(contentRepositoryProvider);
    final source = await content.findSource(arg.sourceId);
    final document = await content.findDocument(arg.sourceId);
    if (source == null || document == null) {
      throw StateError('source ${arg.sourceId} is not in the library');
    }
    final topic = await ref
        .read(learningRepositoryProvider)
        .findTopic(ElementRef(id: source.id, type: ElementType.source));
    if (topic == null) {
      throw StateError('source ${arg.sourceId} has no schedule');
    }
    return ReaderUiState(
      source: source,
      document: document,
      topic: topic,
      mode: mode,
      effectiveDueDay: await ref
          .read(effectiveDueQueryProvider)
          .forTopic(topic),
      reminderTarget: (await ref.read(schedulingContextProvider).settings())
          .reader
          .reminderWords,
      openedAt:
          (arg.initialAnchor != null &&
              document.containsAnchor(arg.initialAnchor!))
          ? arg.initialAnchor
          : (source.resume.openAt ?? document.startAnchor),
      extracts: await content.listExtractsOfParent(source.id),
      cardsFromSource: (await content.listCardsOfSource(source.id)).length,
      canUndoEdit: (await content.latestSourceEdit(source.id)) != null,
    );
  }

  /// Places the resume marker at the start of [block].
  ///
  /// The only Reader gesture that records progress — and even it leaves the
  /// schedule alone.
  Future<void> placeMarker(Block block) async {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    await _command<Source>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .moveResumeMarker(
            MoveResumeMarker(
              operation,
              sourceId: current.source.id,
              anchor: ReaderAnchor(
                utf8Offset: block.sourceStartUtf8,
                contentRevision: current.document.contentRevision,
              ),
            ),
          ),
      apply: (ReaderUiState s, Source source) => s.copyWith(source: source),
    );
  }

  /// Places the resume marker at an exact position inside a block.
  ///
  /// This is what the selection toolbar uses: the user has already pointed at
  /// a specific spot, so rounding it to the start of the block would throw
  /// away the precision they just gave.
  Future<void> placeMarkerAt(ReaderAnchor anchor) async {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    await _command<Source>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .moveResumeMarker(
            MoveResumeMarker(
              operation,
              sourceId: current.source.id,
              anchor: anchor,
            ),
          ),
      apply: (ReaderUiState s, Source source) =>
          s.copyWith(source: source, softBannerDismissed: true),
      success: (_) => 'Marker set',
    );
  }

  /// Closes the forgotten-marker banner for this session.
  void dismissSoftBanner() {
    final current = state.valueOrNull;
    if (current == null || current.softBannerDismissed) return;
    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(softBannerDismissed: true),
    );
  }

  /// Records the last stable scroll position and updates the session count.
  ///
  /// Runs on every scroll, so it is deliberately cheap and never logged.
  Future<void> recordPosition(ReaderAnchor anchor) async {
    final current = state.valueOrNull;
    if (current == null) return;

    if (!current.document.containsAnchor(anchor)) return;
    final start = current.openedAt;
    final words = start == null
        ? current.wordsThisSession
        : current.document.wordsBetween(start, anchor);

    if (!current.canCommitProgress) {
      // Browse mode reads without leaving a trace of any kind.
      state = AsyncValue<ReaderUiState>.data(
        current.copyWith(wordsThisSession: words),
      );
      return;
    }

    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(wordsThisSession: words),
    );
    _positionWrites = _positionWrites.then((_) async {
      final result = await ref
          .read(readerCommandRunnerProvider)
          .saveSoftPosition(
            SaveSoftPosition(
              OperationId(ref.read(idGeneratorProvider).newId()),
              sourceId: current.source.id,
              anchor: anchor,
            ),
          );
      final latest = state.valueOrNull;
      if (latest == null || result.isErr) return;
      state = AsyncValue<ReaderUiState>.data(
        latest.copyWith(source: result.unwrap()),
      );
    });
    await _positionWrites;
  }

  /// Promotes the soft position to the authoritative marker.
  Future<void> confirmSoftPosition() async {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    await _command<Source>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .confirmSoftPosition(
            ConfirmSoftPosition(operation, sourceId: current.source.id),
          ),
      apply: (ReaderUiState s, Source source) =>
          s.copyWith(source: source, softBannerDismissed: true),
      success: (_) => 'Marker moved to where you left off',
    );
  }

  /// Switches a browse session into scheduled continuation.
  void continueScheduled() {
    final current = state.valueOrNull;
    if (current == null || current.canCommitProgress) return;
    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(
        mode: ReaderMode.scheduled,
        message: const UiMessage('Reading for today — Done will advance it'),
      ),
    );
  }

  /// Done: commits one encounter and closes the Reader.
  Future<void> done() async {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .completeEncounter(
            CompleteTopicEncounter(
              operation,
              ref: current.topic.ref,
              foregroundMs: _foregroundMs(),
              // The A-factor's yield term needs both halves of the ratio: an
              // article that keeps producing extracts should keep coming back,
              // and a barren one should recede.
              wordsRead: current.wordsThisSession,
              extractsCreated: _extractsThisSession,
            ),
          ),
      apply: (ReaderUiState s, TopicState topic) =>
          s.copyWith(topic: topic, isDone: true, wasRepetition: true),
      successAsync: (TopicState topic) async =>
          'Next on ${await _refreshEffectiveDue(topic)}',
    );
  }

  /// Later: moves eligibility without growing the interval.
  ///
  /// With no explicit day the handler scales the delay by the source's own
  /// interval, because a fixed one day just returns it tomorrow into an
  /// equally full queue.
  Future<void> later({int? days}) async {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    final StudyDay? until = days == null
        ? null
        : (await ref.read(readerCommandRunnerProvider).today()).addDays(days);
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .postpone(
            PostponeElement(operation, ref: current.topic.ref, until: until),
          ),
      apply: (ReaderUiState s, TopicState topic) =>
          s.copyWith(topic: topic, isDone: true, wasRepetition: false),
      successAsync: (TopicState topic) async {
        final StudyDay due = await _refreshEffectiveDue(topic);
        final StudyDay today = await ref.read(readerCommandRunnerProvider).today();
        // Later Today on an element that is already Outstanding is a
        // queue-only shift: section 8.4 leaves the due date alone. Reporting
        // the canonical due here would name a day that has already passed for
        // anything overdue, and promise a return that is not scheduled.
        return due <= today
            ? "Moved to the back of today's queue"
            : 'Back on $due';
      },
    );
  }

  /// Reads the adjustment-aware due back and stores it on the state, so the
  /// status bar and the toast cannot disagree about when this comes back.
  Future<StudyDay> _refreshEffectiveDue(TopicState topic) async {
    final StudyDay due = await ref
        .read(effectiveDueQueryProvider)
        .forTopic(topic);
    final ReaderUiState? current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue<ReaderUiState>.data(
        current.copyWith(effectiveDueDay: due),
      );
    }
    return due;
  }

  /// Dismisses the source: stops scheduling it, keeps the content.
  ///
  /// SM20 has no Finish. Dismiss is the command that means "I am done with
  /// this", and it clears the repetition state and sends priority to 100 as
  /// the executable does — never automatically at the end of the text.
  Future<void> dismiss() async {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .dismiss(
            DismissElement(
              operation,
              ref: ElementRef(id: current.source.id, type: ElementType.source),
            ),
          ),
      apply: (ReaderUiState s, TopicState topic) =>
          s.copyWith(topic: topic, isDone: true, wasRepetition: false),
      success: (_) => 'Dismissed. It stays in the Library.',
    );
  }

  /// Extracts [range] into a new independent element.
  ///
  /// Available in browse mode too: capturing a passage is not progress on the
  /// source, so it does not need scheduled continuation. It leaves the
  /// viewport, the marker, and the schedule exactly where they were.
  Future<Extract?> extractSelection(SelectionRange range) async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isBusy ||
        !current.canCommitProgress ||
        !current.document.isSameBlock(range)) {
      return null;
    }
    state = AsyncValue<ReaderUiState>.data(current.copyWith(isBusy: true));

    final result = await ref
        .read(extractionCommandRunnerProvider)
        .createExtract(
          CreateExtract(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parentId: current.source.id,
            parentIsSource: true,
            range: range,
          ),
        );

    final latest = state.valueOrNull ?? current;
    if (result.isErr) {
      state = AsyncValue<ReaderUiState>.data(
        latest.copyWith(
          message: UiMessage(result.failureOrNull!.message, isError: true),
          isBusy: false,
        ),
      );
      return null;
    }

    final created = result.unwrap();
    _extractsThisSession++;
    state = AsyncValue<ReaderUiState>.data(
      latest.copyWith(
        extracts: await _reloadExtracts(latest.source.id),
        lastExtractId: created.id,
        message: const UiMessage('Extracted'),
        isBusy: false,
      ),
    );
    return created;
  }

  /// Removes an extract created moments ago.
  Future<void> undoExtract(String extractId) async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isBusy ||
        current.lastExtractId != extractId) {
      return;
    }
    if (_extractsThisSession > 0) _extractsThisSession--;
    state = AsyncValue<ReaderUiState>.data(current.copyWith(isBusy: true));

    final result = await ref
        .read(extractionCommandRunnerProvider)
        .undoExtract(
          UndoExtract(
            OperationId(ref.read(idGeneratorProvider).newId()),
            extractId: extractId,
          ),
        );

    final latest = state.valueOrNull ?? current;
    state = AsyncValue<ReaderUiState>.data(
      latest.copyWith(
        extracts: await _reloadExtracts(latest.source.id),
        clearLastExtract: true,
        isBusy: false,
        message: result.fold(
          (_) => const UiMessage('Extract removed'),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Formulates cards straight from this article, with no extract between.
  ///
  /// SuperMemo allows exactly this — an item can be made from whatever
  /// element is open — and the article is left untouched: no reschedule, no
  /// marker move, no change to its text.
  Future<bool> formulate(List<CardDraft> drafts) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy || !current.canCommitProgress) {
      return false;
    }
    state = AsyncValue<ReaderUiState>.data(current.copyWith(isBusy: true));

    final result = await ref
        .read(formulationCommandRunnerProvider)
        .formulate(
          FormulateCards(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parent: CardParent.source(current.source.id),
            drafts: drafts,
          ),
        );

    final latest = state.valueOrNull ?? current;
    if (result.isErr) {
      state = AsyncValue<ReaderUiState>.data(
        latest.copyWith(
          message: UiMessage(result.failureOrNull!.message, isError: true),
          isBusy: false,
        ),
      );
      return false;
    }

    final created = result.unwrap().length;
    state = AsyncValue<ReaderUiState>.data(
      latest.copyWith(
        cardsFromSource: latest.cardsFromSource + created,
        message: UiMessage(
          created == 1 ? '1 card created' : '$created cards created',
        ),
        isBusy: false,
      ),
    );
    return true;
  }

  Future<List<Extract>> _reloadExtracts(String sourceId) =>
      ref.read(contentRepositoryProvider).listExtractsOfParent(sourceId);

  /// Hides the session reminder line until the next session.
  void dismissReminder() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(reminderDismissed: true),
    );
  }

  /// Consumes the one-shot completion signal.
  ///
  /// `isDone` means "a terminal command just committed", not "this source is
  /// finished". The provider is a keyed family and is not autoDispose, so
  /// reopening the same source hands back the same state: left set, the flag
  /// would fire again the moment the reader rebuilt, popping the screen before
  /// the user could read a word and counting a repetition that never happened.
  void clearDone() {
    final ReaderUiState? current = state.valueOrNull;
    if (current == null || !current.isDone) return;
    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(isDone: false, wasRepetition: false),
    );
  }

  /// Clears the one-shot message after the view has shown it.
  void clearMessage() {
    final current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<ReaderUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }

  /// Opens [block] in the editor.
  ///
  /// Any live selection is dropped rather than carried in: the paragraph it
  /// was measured against is about to be replaced by a text field, and offsets
  /// resolved against a layout that no longer exists are exactly the kind of
  /// quietly-wrong coordinate this design removes.
  void beginEditing(Block block) {
    final current = state.valueOrNull;
    if (current == null || !current.canCommitProgress) return;
    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(editingBlockId: block.id, clearMessage: true),
    );
  }

  /// Closes the editor without writing anything.
  void cancelEditing() {
    final current = state.valueOrNull;
    if (current == null || !current.isEditing) return;
    state = AsyncValue<ReaderUiState>.data(
      current.copyWith(clearEditing: true),
    );
  }

  /// Commits [markdown] as the new text of [block].
  Future<void> commitEdit(Block block, String markdown) => _runEdit(
    (OperationId operation, ReaderUiState current) => ref
        .read(readerCommandRunnerProvider)
        .editSourceBlock(
          EditSourceBlock(
            operation,
            sourceId: current.source.id,
            blockId: block.id,
            markdown: markdown,
            baseContentRevision: current.document.contentRevision,
          ),
        ),
  );

  /// Removes [block] and the separator that went with it.
  Future<void> deleteBlock(Block block) => _runEdit(
    (OperationId operation, ReaderUiState current) => ref
        .read(readerCommandRunnerProvider)
        .deleteSourceBlock(
          DeleteSourceBlock(
            operation,
            sourceId: current.source.id,
            blockId: block.id,
            baseContentRevision: current.document.contentRevision,
          ),
        ),
  );

  /// Reverses the most recent edit to this source's text.
  Future<void> undoEdit() => _runEdit(
    (OperationId operation, ReaderUiState current) => ref
        .read(readerCommandRunnerProvider)
        .undoSourceEdit(
          UndoSourceEdit(operation, sourceId: current.source.id),
        ),
  );

  /// Shared body for the editing commands.
  ///
  /// Rebuilds from the returned document rather than reloading the screen: the
  /// block list has been re-derived and its ids differ from the previous
  /// parse, so anything still holding an old block id has to be discarded in
  /// the same frame the new document arrives.
  Future<void> _runEdit(
    Future<Result<SourceEdited>> Function(
      OperationId operation,
      ReaderUiState current,
    )
    run,
  ) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy || !current.canCommitProgress) return;
    state = AsyncValue<ReaderUiState>.data(current.copyWith(isBusy: true));

    final result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
      current,
    );
    final latest = state.valueOrNull ?? current;

    if (result case Err<SourceEdited>(:final failure)) {
      state = AsyncValue<ReaderUiState>.data(
        latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      );
      return;
    }

    final SourceEdited edited = result.unwrap();
    final content = ref.read(contentRepositoryProvider);
    state = AsyncValue<ReaderUiState>.data(
      latest.copyWith(
        source: edited.source,
        document: edited.document,
        extracts: await content.listExtractsOfParent(edited.source.id),
        isBusy: false,
        clearEditing: true,
        canUndoEdit:
            (await content.latestSourceEdit(edited.source.id)) != null,
        openedAt: edited.source.resume.openAt,
        message: edited.didChange
            ? _editMessage(edited.outcome!)
            : const UiMessage('Nothing changed'),
      ),
    );
  }

  /// What to say after an edit that displaced something.
  ///
  /// Silence would be wrong here: an extract whose source text is gone is
  /// still a usable card, but the user is the only one who can decide what to
  /// do about the broken link, and they can only decide if they are told.
  static UiMessage _editMessage(SourceEditOutcome outcome) {
    final int orphaned = outcome.provenanceUpdates
        .where(
          (ProvenanceUpdate u) =>
              u.provenance.state == ProvenanceState.orphaned,
        )
        .length;
    final int stale = outcome.provenanceUpdates
        .where(
          (ProvenanceUpdate u) => u.provenance.state == ProvenanceState.stale,
        )
        .length;
    if (orphaned == 0 && stale == 0) return const UiMessage('Saved');
    final parts = <String>[
      if (orphaned > 0) '$orphaned extract${orphaned == 1 ? '' : 's'} orphaned',
      if (stale > 0) '$stale extract${stale == 1 ? '' : 's'} now stale',
    ];
    return UiMessage('Saved — ${parts.join(', ')}');
  }

  int? _foregroundMs() {
    final started = _sessionStartedAt;
    if (started == null) return null;
    return ref.read(clockProvider).nowUtc().difference(started).inMilliseconds;
  }

  Future<void> _command<T>(
    Future<Result<T>> Function(OperationId operation) run, {
    required ReaderUiState Function(ReaderUiState state, T value) apply,
    String Function(T value)? success,
    Future<String> Function(T value)? successAsync,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<ReaderUiState>.data(current.copyWith(isBusy: true));

    final result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
    );
    // The async message builder may itself refresh the state (the effective
    // due is read back from storage), so the base to apply onto is taken
    // after it has run, not before.
    String? asyncMessage;
    final Future<String> Function(T value)? buildAsync = successAsync;
    if (buildAsync != null && result is Ok<T>) {
      asyncMessage = await buildAsync(result.value);
    }
    final latest = state.valueOrNull ?? current;

    state = AsyncValue<ReaderUiState>.data(
      result.fold(
        (T value) => apply(latest, value).copyWith(
          isBusy: false,
          message: asyncMessage != null
              ? UiMessage(asyncMessage)
              : (success == null ? null : UiMessage(success(value))),
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }
}

/// The Reader ViewModel provider, keyed by which source and mode.
final AsyncNotifierProviderFamily<ReaderViewModel, ReaderUiState, ReaderRequest>
readerViewModelProvider =
    AsyncNotifierProvider.family<ReaderViewModel, ReaderUiState, ReaderRequest>(
      ReaderViewModel.new,
    );
