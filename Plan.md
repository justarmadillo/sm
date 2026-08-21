# Incremental Reader v1 — Reader-First MVVM Implementation Plan (Final, discussion outcome incorporated)

## Context

Personal SuperMemo-style incremental reading tool. The core SuperMemo algorithm is closed, but its behavior (topic/item distinction, priority queue, dismissal, mixing, overload handling) is replicated with transparent, configurable mechanisms. This document is the user's original draft plan with the design-review decisions merged in. Decisions incorporated: Windows-only v1 with Android and device handoff deferred to v1.1; dogfooding begins at M3; hybrid resume marker; priority-setting UI (slider + priority browser); undo last grade and edit-card-during-review; virtualized rendering for 10–50k-word sources proven in M0; rolling backups from M1; Markdown-only ingestion; count-based queue with auto-postpone (matches actual SuperMemo behavior — no time budgeting); FSRS with pinned defaults (optimizer post-v1); SuperMemo-style knowledge tree with branch operations and practice-mode subset review (v1, built after dogfooding starts); no RTL, no Anki interop, no sibling burying, no statistics in v1.

## Conceptual Model (from the IR design discussion)

This section fixes the mental model the whole plan implements. Terminology maps to SuperMemo: **topics** are elements the user reads/processes (sources and extracts); **items** are elements the user is tested on (cards).

The pipeline:

```text
SOURCE (article/chapter, imported Markdown)
   ↓ incremental reading (small portions per encounter)
EXTRACT (passage promoted to an independent learning object)
   ↓ revisit / process (keep, edit, extract further, or formulate)
CARD (Q&A or cloze formulated from an extract — or straight from the source)
   ↓ spaced recall (FSRS)
MEMORY
```

Extract-first is the *recommended* path, not a rule. As in SuperMemo, where
Alt+Z applies to whichever element is open, a card's parent is a reference to
another element: an extract, a source, or nothing at all. The database models
that directly (two nullable parent foreign keys on `cards`, at most one set),
so the knowledge tree in M5 sees one uniform element→children relation instead
of a special case for items.

Core principles the implementation must preserve:

* **The source itself is a scheduled learning object.** Unfinished reading is scheduled work, not a bookmark. A source is never "done/not done" — it has a reading position (the resume marker = the processing frontier cursor) and its own schedule. Position answers "how far have I processed this?"; the schedule answers "when do I process more?". Never conflate them.
* **Extraction creates a new independent object; it never cuts or moves source text.** An extract references its origin (source ID, block IDs, offsets — provenance) so context is always recoverable, but from creation onward it has its own schedule, priority, and lifecycle, fully independent of the parent's reading position or fate. Extracts can be extracted from recursively (source → extract → smaller extract → card).
* **Capture and formulation are separate operations, possibly days apart.** An extract is not obligated to become a card — it can stay an extract forever, be dismissed, or be refined across encounters until the user understands it well enough to formulate. Formulating never converts, reschedules, or removes the extract. This is the key difference from Anki's "interesting passage → card immediately" workflow.
* **Extraction must be frictionless**: select → extract → keep reading. No modal, no metadata prompts. Metadata (provenance, priority) is inherited automatically.
* **Priority is attention allocation, separate from due-ness.** Scheduling decides *eligibility* (what may appear today); priority decides *ordering and admission* among eligible elements (what deserves limited attention first). Priority never pulls not-yet-due material forward and never changes intervals. The collection is expected to exceed learning capacity — auto-postpone of lowest-priority overflow is normal, not an error.
* **Two scheduler families, one queue.** Cards use FSRS (memory model: "when should I retrieve this again?"). Topics use simple growing interval sequences (processing pacing: "when should I continue this?"). A unified queue mixes both streams so reading never starves review and vice versa. **The queue is the heart of the application** — the user's session is "work through today's queue", not "open a deck" or "open a book".
* **Every element shares a common scheduling shape** (type, priority rank, due, state, lifecycle) so the queue and scheduler treat sources, extracts, and cards uniformly, while each type keeps its own state (position for sources, provenance for extracts, FSRS state for cards).
* **Postpone ≠ failure.** "Later" means "wrong task right now" and only shifts eligibility; Anki-style Again is a memory signal that belongs to cards only. The two signals are modeled separately.

## Summary

Build a local-first Flutter application around:

Source → Extract topic → Formulated card → Review

Sources and extracts are independently scheduled topics. Cards are separate items using FSRS. Formulating never converts or removes the extract.

Use pragmatic MVVM with an explicit Application and pure Domain layer. Riverpod supplies ViewModels, reactive state, and dependency injection; it must not leak into domain or persistence code. This follows Flutter's recommended MVVM structure while adding the domain layer required by the Reader, schedulers, queue, and export protocol. [Flutter architecture guidance](https://docs.flutter.dev/app-architecture/guide)

**Windows is the sole v1 target.** Every milestone ends with a runnable Windows slice. Android parity and exclusive device handoff ship in **v1.1**. Domain, application, and data layers must remain platform-clean (no Windows-only dependencies) so v1.1 is presentation/platform work, not a rewrite. The build is paced for early dogfooding: the user starts studying with the tool daily at the end of M3, and later milestones are built while the tool is in real use.

## Architecture and Code Organization

Dependency flow

```text
View / Flutter widgets
        ↓ commands       ↑ immutable UiState
Riverpod ViewModel
        ↓
Application command/query handler
        ├── Pure domain models and state machines
        └── Repository interfaces
                         ↓
              Repository implementations
                         ↓
          Drift DAOs / files / platform APIs
```

Dependencies only point inward:

* Views know one ViewModel and presentation types.
* ViewModels know application APIs and read projections.
* Application handlers coordinate domain logic, repositories, and transactions.
* Domain code imports only Dart and other domain modules.
* Data implementations depend on domain/application interfaces.
* Drift rows, Riverpod `Ref`, Flutter types, and platform objects never enter the domain layer.

MVVM rules

* Implement one ViewModel per screen or durable workflow: `ReaderViewModel`, `QueueViewModel`, `ExtractViewModel`, `ReviewViewModel`, `LibraryViewModel`, `PriorityBrowserViewModel`, and `SettingsViewModel`. (`HandoffViewModel` arrives in v1.1.)
* Implement ViewModels with Riverpod `Notifier` or `AsyncNotifier`, the recommended Riverpod mechanism for user-mutated state. [Riverpod Notifier guidance](https://docs-v2.riverpod.dev/docs/providers/notifier_provider)
* Views contain layout, animations, focus, and simple visibility decisions only.
* ViewModels expose immutable screen-specific `UiState` plus intention-named methods such as `done()`, `moveResumeMarker()`, or `formulate()`.
* Keep navigation, snackbars, and dialogs as ephemeral `UiEffect` values rather than durable application state.
* Never mutate providers during widget build and never put interval, priority, SQL, or transaction logic in a ViewModel.
* Use Riverpod as the composition root instead of a service locator. Dependencies remain constructor-injected and private.

Application and domain rules

* Represent every mutation as an explicit immutable command, for example:
   * `MoveResumeMarker`
   * `CompleteTopicEncounter`
   * `PostponeElement`
   * `CreateExtract`
   * `FormulateCards`
   * `ReviewCard`
   * `UndoLastReview`
   * `EditCard`
   * `SetPriority`
   * `DismissElement`
   * `MoveBranch`
   * `SetBranchPriority`
   * `SuspendBranch`
   * `StartPracticeSession`
   * `ExportVault`
* Give each command an operation ID and timestamp. One application handler owns validation, transaction scope, domain invocation, persistence, and emitted activity events.
* Do not introduce a generic reflection-based command bus. Handlers remain ordinary named Dart classes and methods.
* Implement schedulers and lifecycle rules as pure transitions:

```text
(current state, command, clock, settings)
    → new state + domain events
```

* Use repositories as single sources of truth. Compound operations run through a shared `TransactionRunner` so multiple repositories participate in one Drift transaction.
* Repositories are organized by aggregate, not table: content/library, learning schedules, settings, and transfer state.
* DAOs contain SQL only. They do not decide schedules, lifecycle transitions, or user-visible policy.
* Use typed sealed `Result<T>` and `AppFailure` values across application boundaries. Preserve original exception and stack trace in structured diagnostic logs.
* Use native Dart immutable classes, sealed classes, records, and explicit `copyWith` implementations. Avoid pervasive code generation beyond Drift.

Project structure

```text
lib/src/
  app/                    # bootstrap, router, themes, Riverpod wiring
  core/                   # Clock, IDs, Result, failures, tracing
  domain/
    content/              # Source, Block, Extract, Card, anchors
    scheduling/           # topic/card state, priority, queue policies
    transfer/             # snapshot lineage and vault/export rules
  application/
    reader/
    extraction/
    formulation/
    review/
    queue/
    library/
    transfer/
  data/
    database/             # Drift schema, migrations, DAOs
    repositories/         # repository implementations and mappings
    files/                # assets, vault, backup storage
    platform/             # links, lifecycle adapters (SAF arrives with Android in v1.1)
  features/
    reader/presentation/
    extract/presentation/
    review/presentation/
    queue/presentation/
    library/presentation/
    priority/presentation/   # priority browser
    settings/presentation/
```

Important domain types and interfaces

* `ReaderAnchor(blockId, utf8Offset)`
* `SelectionRange(startAnchor, endAnchor, selectedTextHash)`
* `StudyDay(localDate, zoneId, rollover)`
* `TopicSchedule(profileId, stepIndex, dueDay, originalDueDay, deferredUntil)`
* `CardSchedule(fsrsState, dueAtUtc, originalDueAtUtc, deferredUntil)`
* `PriorityRank(orderKey)` with derived position and percentile
* `TopicScheduler`, `CardScheduler`, and `QueuePolicy`
* `ContentRepository`, `LearningRepository`, `SettingsRepository`, and `TransferRepository`
* `TransactionRunner`, `Clock`, `IdGenerator`, and `DiagnosticSink`

## Product and Scheduling Behavior

Reader

* Use continuous scrolling with compact persistent bars. Secondary controls appear in temporary overlays.
* Rendering is lazy/virtualized: typical sources are long chapters (10–50k words), and blocks are mounted/unmounted as the user scrolls. Anchors and coordinate mapping must resolve for unmounted blocks (an unmounted block still resolves `ReaderAnchor(blockId, utf8Offset)`). This is proven in M0, not deferred.
* **Hybrid resume marker:**
   * The authoritative resume marker is explicitly placed by clicking or tapping the empty document margin and persisted immediately. It alone drives scheduling and "open at marker".
   * A **soft position** — the last stable scroll position — is auto-persisted on pause/close/process death. On reopen it is shown as a visually distinct secondary indicator ("you were here") so a forgotten explicit marker never loses the place.
   * The soft position never drives scheduling, never counts as progress, and is freely overwritten by scrolling. One tap converts it into the explicit marker.
* Extract gutter markers open previews; tapping empty gutter moves the resume marker.
* Scheduled mode opens at the marker with brief preceding context.
* Back, backgrounding, process death, link navigation, or ordinary scrolling never reschedules the source; it remains due.
* Library, search, and context open in browse mode. Browse mode cannot mutate progress or schedules unless the user explicitly selects scheduled continuation.
* Done commits one topic encounter, advances the schedule once, logs foreground duration, and opens the next queue element. Zero-progress Done is legal and idempotent.
* Later changes the next eligible date without advancing the interval sequence.
* Reaching EOF does not complete a source automatically; show an explicit Finish Source action.
* Show a nonblocking reminder line approximately 500 words after the session's opening marker. The global target is configurable.
* Support global typography with per-source overrides, technical Markdown, code, tables, inline/block math, Unicode, and images. (RTL/bidi is out of scope for v1.)
* Copy local images into managed storage. Cache remote images while retaining original URLs and show offline/failure placeholders.
* Open external links in the system browser.
* Include no highlights, freeform notes, or built-in assistance in v1.

Extraction and formulation

* Same-block extraction ships first; multi-block extraction is required before v1 release but is not a prerequisite for daily use (it lands in M5, after dogfooding begins).
* Extraction is modal-free, preserves selected Markdown, does not move viewport or marker, inherits provenance and priority, and offers Undo.
* Store immutable source/block IDs, precise source offsets, and selected-text hash.
* Show prior extractions through persistent gutter marks.
* Context opens in a temporary browse overlay containing the selected passage, adjacent blocks, Expand, and Open Source.
* Extracts remain editable, searchable, and independently scheduled.
* Formulate creates one or more linked Q&A/cloze cards and returns to the same element. It is available on an extract *and* in the Reader (Alt+Z), where the current selection seeds the card text and the parent is the source.
* Formulate does not reschedule or dismiss the extract. Done advances it; Dismiss retains it while removing it from learning.
* Store clozes using canonical Anki syntax such as `{{c1::answer}}`; derive rendered ranges. The syntax is Anki's, not SuperMemo's — one canonical string stays the single source of truth, so editing the sentence can never desynchronize the deletions.
* A card's parent is optional and may be an extract or a source. Priority is inherited from whatever element produced it, once, at creation.

Card scheduling

* Use pinned `fsrs` 2.0.1 behind `CardScheduler`, verified against reference vectors. [Dart FSRS package](https://pub.dev/packages/fsrs)
* Defaults:
   * Desired retention: `0.90`
   * Learning: `1m, 10m`
   * Relearning: `10m`
   * Maximum interval: `36500d`
   * Fuzzing: enabled
* Use Again, Hard, Good, and Easy.
* Store all card instants in UTC and persist scheduler/parameter versions with every review event. Each review event also carries a pre-review FSRS state snapshot (enables undo and post-v1 parameter optimization; the log is lossless, so a per-user FSRS optimizer can be added later without data migration).
* **Undo last grade:** single-step revert of the most recent review — restore the prior FSRS state from the pre-review snapshot, remove the review event, and return the card to the current session.
* **Edit card during review:** inline edit of question/answer/cloze text without leaving the review flow and without any reschedule.
* New cards enter the new-card pool immediately but remain subject to its daily limit.
* Once a card starts learning or relearning, due intraday steps bypass admission limits and take the next card slot.
* No sibling burying in v1.

Topic scheduling

All sequences are editable in Settings and repeat their final value:

* Focused source: `1,2,3,5,7,10,14,21,30`
* Normal source: `1,3,7,14,30,60,120,240,365`
* Slow source: `7,14,30,60,120,240,365,730`
* Extract: `1,3,7,14,30,60,120`

Behavior:

* New sources are due today; new extracts are due next study-day.
* Done advances the sequence once.
* Tomorrow/custom Postpone changes only next eligibility.
* Edit, Show Context, Extract More, Formulate, Back, cancellation, and crashes do not advance scheduling.
* Dismiss retains content and provenance but removes scheduling.
* Suspend is a temporary removal; resume makes the element due today without resetting its interval step.
* Finishing, dismissing, suspending, or deleting a parent never changes descendant schedules.

Priority and unified queue

* Use a SuperMemo-style relative priority queue displayed as `0%` highest through `100%` lowest.
* Store sortable order keys and derive positions/percentiles; do not store priority as a misleading absolute score.
* **Priority UI:**
   * A percent slider is available on any element — in the reader, extract view, review, and library — with a keyboard shortcut on Windows (SuperMemo Alt+P equivalent).
   * A **priority browser**: a list of all elements sorted by rank with drag-to-rebalance; dragging rewrites order keys. This is the bulk-rebalancing equivalent of SuperMemo's priority queue view.
* New root elements start at the middle by default. Extracts and cards inherit their parent's current rank once at creation.
* Later parent-priority changes do not silently cascade.
* Priority affects admission and ordering but never pulls not-yet-due material forward or changes intervals.
* Build two streams:
   * Cards
   * Topics: sources and extracts competing together
* Default presentation pattern is approximately four cards followed by one topic. The topic proportion starts near 20% and is configurable.
* If one stream is empty, use the other without leaving unused slots.
* Within each stream, rank by priority, capped overdue correction, original due date, and stable ID.
* Add deterministic configurable daily randomization, default 5%; zero produces strict priority ordering.
* Default daily maxima:
   * 200 unique cards
   * 20 new cards as a subset
   * 50 topics
* These values are configurable maxima, not mandatory quotas. The queue is count-based, worked until the user stops — no time-budgeted sessions (this matches actual SuperMemo behavior; its "Plan" module is a separate day-planner, not the learning queue). Foreground durations are still logged from day 1 so time-based features remain possible post-v1.

Knowledge tree and subset review (v1, built after the M3 dogfooding gate)

* The Library is a SuperMemo-style knowledge tree:
   * **Lower levels build themselves from provenance**: extracts appear as children of their source; cards as children of their extract. Never manually arranged.
   * **Upper levels are user-organized**: user-created folders ("Cardiology", "Pharmacology", nested freely); sources are dragged into folders. Unfiled sources live in a default root.
* Branch operations (context menu on any folder or source, applying to everything beneath):
   * **Review branch now** — subset review (below).
   * **Set branch priority** — spread a chosen priority range across all elements under the branch (mass reprioritization; rewrites order keys).
   * **Suspend / resume branch** — pause a whole subject temporarily; resume follows the standard suspend semantics (due today, interval step preserved).
   * **Move / delete branch** — reorganize the hierarchy; delete a subject wholesale (with confirmation; delete follows standard retention rules).
* **Subset review** ("review all cardiology now, even not-yet-due") runs as a **practice session**:
   * Shows the branch's cards regardless of due date.
   * Grades are logged as separately flagged practice events; they **never** modify FSRS state, due dates, or daily-queue admission, and are excluded from any future FSRS parameter optimization.
   * The daily queue is completely unaffected.
* Tree structure is persisted (folder table + source placement); provenance relations are already stored, so only the upper-level hierarchy is new schema.

Auto-postpone

* Auto-postpone lowest-priority excess cards and topics.
* Preserve FSRS/topic algorithmic due dates and interval state.
* Store postponement separately in `deferredUntil`; original due remains available for overdue ranking and audit.
* Never create a fake review or topic encounter.
* Make daily admission and deferral transactional and idempotent.
* Started learning/relearning steps are never auto-postponed.
* Raising a limit or selecting Study More can recall automatic same-day deferrals; manual postponements remain.
* Use a configurable home IANA timezone and default 04:00 study-day rollover.

## Persistence, Durability, and Export

* Keep the WAL-mode live SQLite database in platform-local application storage, never in Syncthing, Drive, or a synced folder.
* Enable foreign keys on every connection and enforce type, lifecycle, range, uniqueness, and one-to-one subtype invariants in SQL.
* Preserve immutable original Markdown, source hash, asset metadata, and immutable derived blocks.
* Store progress from the cursor rather than maintaining a second drift-prone percentage.
* Append review and activity events; increment item revision and dataset generation in every domain transaction.
* Build a transactional materialized `search_documents` table and rebuildable external-content FTS5 index.
* Create live backups through SQLite Online Backup or `VACUUM INTO`; validate before atomic rename. Never copy the active WAL files directly. [SQLite backup guidance](https://www.sqlite.org/backup.html) **Rolling backups exist from the end of M1** — before real study data accumulates.
* Retain 30 daily and 12 monthly backups. Keep pre-migration backups under separate retention.
* Snapshot and validate before Drift opens an older schema. Migrate transactionally, test every historical path, and reject newer unsupported schemas.
* Export a plaintext vault from one immutable snapshot:
   * Original Markdown and managed assets
   * Versioned NDJSON state, reviews, and activity
   * Schema documentation
   * Manifest with versions, lineage, counts, and SHA-256 checksums
* Validate the complete export before atomically updating `LATEST`.
* Show a privacy warning for plaintext exports.

Exclusive device handoff — **deferred to v1.1** (only meaningful with a second device):

* v1 keeps the cheap schema groundwork from M0: dataset ID, generation, writer epoch, and owner-device columns exist so v1.1 needs no migration of history.
* v1.1 implements the protocol: export behind an exclusive write gate, source device becomes read-only, destination accepts only the expected dataset lineage and assumes the next writer epoch, mismatches rejected without changing either copy, both branches preserved with explicit authoritative-branch selection.
* No merge, live sync, or last-write-wins overwrite. (Folder-based sync is a possible v2+ replacement once the tool is proven — noted, not planned.)

## Staged Implementation

M0 — Architecture, database, and Reader feasibility

* Scaffold Flutter Windows and enforce the dependency rules above (project stays cross-platform buildable; no Android work).
* Configure strict Dart analysis and an automated boundary test that rejects Flutter, Riverpod, or Drift imports from domain code.
* Implement core result/failure types, command tracing, fake clock, transaction runner, repository contracts, and safe migration/backup baseline. Schema includes dataset ID / generation / writer epoch / owner-device fields (for v1.1 handoff).
* Create the immutable document model and rendering adapter.
* Prove exact same-block source-coordinate mapping across formatting, links, code, math, Unicode, font changes, and window resizing.
* Prove **lazy/virtualized block rendering at 50k words** with smooth scrolling, and that anchors and coordinate mapping resolve for blocks not currently mounted.
* Prototype cross-block native selection and lock the block-aware fallback if native anchors are unreliable.

Gate: domain/application tests run without Flutter or SQLite; Windows Reader fixture produces stable anchors; 50k-word fixture scrolls smoothly and anchors resolve for unmounted blocks.

M1 — Durable source Reader

* Implement Markdown paste/file import, assets, Library, Reader, resume marker (explicit + soft position), typography, reminder line, browse mode, source scheduling, and Done/Later/Finish.
* Add `ReaderViewModel` and explicit reader commands without scheduler logic in widgets or ViewModel.
* Implement rolling live-DB backups (`VACUUM INTO`, validation, retention) — must exist by end of M1.

Gate: import → read → mark → restart → resume works mid-paragraph; killing the app without placing a marker reopens at the soft position; interruption does not reschedule; terminal commands execute exactly once; a valid backup is produced and restorable.

M2 — Extraction

**Status: complete — M3 is unblocked.** Verified by the full automated suite,
the native Windows import → read → extract → Undo workflow, and a Windows
debug build.

* Implement same-block extraction, exact provenance, Undo, gutter markers, and context overlay.
* Execute creation through `CreateExtractHandler` in one transaction.

Gate: complex selections round-trip exactly; overlapping extracts, Undo, and context restoration work without cursor/schedule mutation.

M3 — Complete IR loop

**Status: complete — daily Windows dogfooding is unblocked.** Verified by all
216 project tests (including the pinned FSRS reference vector and a real-database
restart under a fake clock), the native Windows import → extract → batch
formulation → heterogeneous queue → review workflow, the M2 native regression,
clean static analysis, and a Windows debug build.

* Add extract processing, recursive extraction, Q&A/cloze formulation, FSRS review, and minimal heterogeneous queue.
* Add pure topic/card state-machine tests before wiring presentation.

Gate: import → read → extract → revisit → formulate multiple cards → Done/Dismiss → review works after restart and fake-clock advancement. **Exit criterion: the user starts studying with the tool daily on Windows.** M4–M6 are built while the tool is in real use; friction feeds back into them.

M4 — Production queue, search, priority UI, and diagnostics

* Complete relative priority, topic proportion, randomization, caps, auto-postpone, Study More, FTS5, suspend/delete/restore, and Settings.
* Add the priority slider (all surfaces + keyboard shortcut) and the priority browser with drag-to-rebalance.
* Add undo-last-grade and edit-card-during-review.
* Add a development diagnostics panel showing current entity state, schedule, last commands, and pre/post transitions without exposing source content by default.
* Add a local rotating structured log containing operation metadata, failures, schema/app versions, and integrity results.

Gate: deterministic tests cover backlog, repeated queue builds, cap changes, DST, priority changes, failure recovery, and operation tracing; undo-grade round-trips FSRS state identical to the pre-review snapshot; priority-browser ordering survives restart.

M5 — Multi-block extraction, knowledge tree, and Windows polish

* Deliver multi-block extraction using proven native selection or the block-aware selector.
* Deliver the knowledge tree: folder hierarchy over sources, auto-lineage lower levels, drag-to-organize, and the four branch operations (review branch as practice session, set branch priority, suspend/resume branch, move/delete branch).
* Complete keyboard-only Windows flow, 200% text scaling, screen-reader labels, and offline images.

Gate: paragraph/list/code/math/image ranges preserve Markdown and context; branch operations apply transactionally to every descendant and are idempotent; practice sessions leave FSRS state and daily-queue admission byte-identical; accessibility and performance targets pass on Windows.

M6 — Recovery, vault, and release

* Complete vault export/import, restore UI, corruption recovery, and migration drills.
* Package Windows for release.

Gate: DB → vault → fresh DB reproduces content, assets, markers, extracts, cards, settings, schedules, and history; interrupted exports preserve the previous snapshot.

v1.1 — Android and handoff

* Android parity: lifecycle restoration, 48dp targets, screen-reader labels, long-press selection, SAF platform adapter, release APK.
* Exclusive device handoff protocol and UI (schema fields already exist; no migration).

Gate: Android smoke of the full loop; handoff-return and divergence are safely rejected.

## Test Strategy and Assumptions

Testing follows the architecture:

* Domain: pure transition, scheduler, priority, queue, anchor, and lineage tests.
* Application: command-handler tests with fake repositories, clock, IDs, and transaction runner.
* Data: repository/DAO integration tests against temporary SQLite databases.
* ViewModel: Riverpod `ProviderContainer` tests for state and effects.
* View: widget tests for rendering, focus, selection, actions, and accessibility.
* End-to-end: Windows full workflow at every milestone. (Android E2E arrives in v1.1.)

Required scenarios include:

* Every source/extract/card lifecycle transition.
* FSRS reference-vector compatibility.
* Undo-grade restoring the exact pre-review FSRS state and removing the event.
* Formulate without extract rescheduling.
* Back/crash without topic advancement; soft-position restore after process death.
* Idempotent Done, review, extraction, and auto-postpone.
* Unicode and formatted selection/provenance; anchors under virtualization (unmounted blocks).
* Timezone, DST, and 04:00 rollover.
* Migration, corruption, disk-full, restore, and interrupted export. (Handoff-return and divergence move to v1.1.)

Assumptions:

* Markdown is the only v1 import format; other formats decided later.
* Typical sources are long chapters (10–50k words).
* Sources are immutable snapshots; importing changed content creates a new source version.
* SQLite remains canonical; the activity log supports diagnosis and audit but is not an event-sourced database.
* Exact undocumented SuperMemo formulas are replaced with transparent configurable topic sequences while preserving its topic/item, priority, dismissal, mixing, and overload behavior.
* FSRS runs on pinned default parameters in v1; a per-user optimizer is post-v1 and the review log already captures everything it needs.
* RTL/bidi, Anki import/export, sibling burying, and statistics/dashboards are out of scope for v1.
* PDF/HTML import, live synchronization, merge resolution, dashboards, knowledge graphs, highlights, notes, and assistance are post-v1.
