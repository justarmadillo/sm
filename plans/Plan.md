# Incremental Reader v1 — Reader-First MVVM Implementation Plan (Final, discussion outcome incorporated)

> **Superseded on scheduling.** This plan was written before the exact SM20
> algorithm was available. Wherever it disagrees with
> `plans/scheduler/SM20_AIO_SCHEDULER.md`, the SM20 document wins and this
> one is discarded — the executable at `plans/sm20_binary/sm20.exe` is the
> tiebreaker for anything the document leaves open. This plan remains the
> record for the reader, extraction, formulation, content model, storage
> layout, and milestone structure.
>
> Already discarded from this document:
>
> * **Suspend / resume** and **Finish source / finish nudge** — SM20 has only
>   pending, memorized, dismissed, and deleted. Both meant "stop scheduling
>   this, keep the content", which is Dismiss; Undismiss restores the status
>   byte and nothing else.
> * **Schedule adjustments, effective due, and the deferral overlay** — a
>   postponement is a low-level reschedule of the canonical due date.
> * **The admission valve, the protected percentile, overload tolerance, and
>   Study More** — SM20 admits the whole Outstanding queue and sheds load
>   through Smart Postpone and Mercy instead.
> * **`topic_afactor_v1`** and every completion/yield modifier — the topic
>   scheduler is the exact SM20 A-factor machine.
> * `SuspendBranch` in the knowledge-tree operations, which becomes
>   Dismiss branch.

## Context

Personal SuperMemo-style incremental reading tool. The core SuperMemo algorithm is closed, but its behavior (topic/item distinction, priority queue, dismissal, mixing, overload handling) is replicated with transparent, configurable mechanisms. This document is the user's original draft plan with the design-review decisions merged in. Decisions incorporated: Windows-only v1 with Android and device handoff deferred to v1.1; dogfooding begins at M3; hybrid resume marker; priority-setting UI (slider + priority browser); undo last grade and edit-card-during-review; virtualized rendering for 10–50k-word sources proven in M0; rolling backups from M1; Markdown-only ingestion; count-based queue with auto-postpone (matches actual SuperMemo behavior — no time budgeting); FSRS with pinned defaults (optimizer post-v1); SuperMemo-style knowledge tree with branch operations and practice-mode subset review (v1, built after dogfooding starts); no RTL, no Anki interop, no statistics in v1. (Sibling burying was originally excluded and now ships as a setting — see Card scheduling.)

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
* **Extraction must be frictionless**: select → extract → keep reading. No modal, no metadata prompts. Provenance is inherited automatically; initial priority placement follows the versioned scheduler policy.
* **Priority is attention allocation, separate from due-ness.** Scheduling decides *eligibility* (what may appear today); priority decides *ordering and admission* among eligible elements (what deserves limited attention first). Absolute priority placement never pulls not-yet-due material forward or changes intervals/A-Factor; any separately named coupled nudge is versioned and calibrated independently. The collection is expected to exceed learning capacity — auto-postpone of lowest-priority overflow is normal, not an error.
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
    scheduling/           # topic/card state, priority, queue, overload, revlog
    settings/             # every tunable the schedulers read
    transfer/             # snapshot lineage and vault/export rules
  application/
    reader/
    extraction/
    formulation/
    review/
    queue/                # admission valve, Study More, Mercy, read model
    priority/             # slider, browser, spread
    scheduling/           # SchedulingContext, SchedulingJournal
    search/
    settings/             # SettingsStore
    diagnostics/
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
    priority/presentation/   # slider dialog + priority browser
    search/presentation/
    settings/presentation/
    diagnostics/presentation/
```

Important domain types and interfaces

* `ReaderAnchor(blockId, utf8Offset)`
* `SelectionRange(startAnchor, endAnchor, selectedTextHash)`
* `StudyDay(localDate, zoneId, rollover)`
* `TopicSchedule(schedulerKind, schedulerVersion, creationMode, initializerVersion, initialTextUtf16Length, intervalDays, aFactor, algorithmDueStudyDay, encounters, lastEncounterStudyDay)`
* `CardMemory(fsrsState, algorithmDueAtUtc, schedulerVersion)`
* Typed `ScheduleAdjustment` records for Later, overflow, siblings, Mercy, and exact manual presentation dates; these never overwrite either canonical schedule above
* `TopicEncounter`, `AFactorInitialization`, and later `AFactorTransition` events, with policy version and before/after snapshots
* `PriorityRank(orderKey)` and `PriorityScale`, which derive position, percentile, and the protected floor
* `RevlogEntry` / `RevlogEventType` — the universal repetition log
* `OverloadValve` — manual Later, auto-postpone, and Mercy delay arithmetic
* `AppSettings` — every tunable, as one immutable value with a total decoder
* `TopicScheduler`, `CardScheduler`, `QueuePolicy`, and `DeterministicRandom`
* `ContentRepository`, `LearningRepository`, `SettingsRepository`, `SearchRepository`, and `TransferRepository`
* `SchedulingContext` (assembles schedulers from live settings and the live priority order) and `SchedulingJournal` (writes the repetition log)
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
* Extraction is modal-free, preserves selected Markdown, does not move viewport or marker, inherits provenance, uses the versioned initial-rank fallback, and offers Undo.
* Store immutable source/block IDs, precise source offsets, and selected-text hash.
* Show prior extractions through persistent gutter marks.
* Context opens in a temporary browse overlay containing the selected passage, adjacent blocks, Expand, and Open Source.
* Extracts remain editable, searchable, and independently scheduled.
* Formulate creates one or more linked Q&A/cloze cards and returns to the same element. It is available on an extract *and* in the Reader (Alt+Z), where the current selection seeds the card text and the parent is the source.
* Formulate does not reschedule or dismiss the extract. Done advances it; Dismiss retains it while removing it from learning.
* Store clozes using canonical Anki syntax such as `{{c1::answer}}`; derive rendered ranges. The syntax is Anki's, not SuperMemo's — one canonical string stays the single source of truth, so editing the sentence can never desynchronize the deletions.
* A card's parent is optional and may be an extract or a source. Its initial rank follows the explicit, versioned card-insertion fallback; parent linkage must not silently turn an uncalibrated SuperMemo rule into a claim of fidelity.

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
* **Undo last grade** (Ctrl+Z): single-step revert of the most recent review —
  restore the prior FSRS state from the pre-review snapshot, remove the review
  event and its log rows, and return the card to the current session. A state
  restore, not an inverse calculation: FSRS is not invertible, so the snapshot
  is the only trustworthy way back. This and undoing a just-made extract are the
  only two writers allowed to shrink the append-only log.
* **Edit card during review** (E): inline edit of question/answer/cloze text
  without leaving the review flow and without any reschedule. A typo found
  mid-review is not new evidence about memory. A cloze edit must keep the
  deletion the card actually tests, or the card would silently start testing
  something else while keeping its memory state.
* New cards enter the new-card pool immediately but remain subject to its daily limit.
* Once a card starts learning or relearning, due intraday steps bypass admission limits and take the next card slot.
* **Sibling burying** (configurable, on by default): answering a card pushes
  same-parent cards that are due today to the next day, logged as a deferral and
  never as a review. Three clozes cut from one sentence give each other away, so
  seeing them together measures almost nothing. *This reverses the original v1
  decision to omit burying — it is cheap, it noticeably improves review quality,
  and it is now a setting rather than a policy.*
* **Leeches**: at a configurable lapse count (default 8) the card is flagged and
  its source passage offered one keystroke away. Flagged, never auto-suspended.
  Most repeated failures are badly written cards rather than hard facts, and
  suspending one hides the evidence instead of fixing the cause — this is the
  single highest-value use of the provenance tree.
* **Practice grades** (for M5 subset review) are logged and flagged, and change
  no FSRS state, no due date, and no admission. They are excluded from any future
  parameter optimization, because nothing about the schedule changed and the
  observation was therefore not a measurement of a scheduled recall.

Topic scheduling

The complete scheduling contract is
[`plans/scheduler/LLM_FIX_INSTRUCTIONS.md`](scheduler/LLM_FIX_INSTRUCTIONS.md),
with the rationale in
[`plans/scheduler/ARCHITECT_GUIDE.md`](scheduler/ARCHITECT_GUIDE.md). Those two
documents override this product plan for every scheduler behavior.

Canonical summary:

* **A topic is any ungraded learnable element.** Articles and extracts share the
  versioned `topic_afactor_v2` scheduler; cards use FSRS exclusively.
* A blank-created topic starts with A `1.2`, interval `1 day`, and due on the next
  StudyDay. Pasting or editing it later does not recalculate A.
* An atomic plain-text clipboard topic uses the recovered creation initializer
  `A = 1.25 + 150 / (UTF16_length + 200)`, displayed to three decimals, with the
  same one-day initial schedule.
* Absolute priority placement changes global rank only. It does not change A,
  interval, or next repetition. Special coupled priority commands remain behind
  an uncalibrated, versioned policy.
* A genuine topic encounter grows the stored interval from stored A. Exact
  SuperMemo rounding and later A transitions are still being calibrated; the
  transparent temporary fallback is
  `max(current + 1, round(current × A))`.
* Legacy fixed-sequence schedules retain their stored dates and steps until an
  explicit, previewed migration. They are not mixed with the new transition.
* **Four end-of-encounter actions must behave differently:**

  | Action | Interval | Read point | Logged as |
  |---|---|---|---|
  | Done | grows by A | advances | `topic_read` |
  | Later | **unchanged** | unchanged | `postpone` |
  | Finish | — | — | `finish` |
  | Dismiss | — | — | `dismiss` |

  If Later grew the interval, skipping an article five times would push it years
  into the future — silently deleting it by neglect. Later moves only the due
  date, and its delay scales with the element's own interval, because a fixed
  +1 day just returns it tomorrow into an equally full queue.
* Edit, Show Context, Extract More, Formulate, Back, cancellation, and crashes do not advance scheduling.
* A manual interval change is available (SuperMemo reads "I must see this in 11
  days, not 30" as a priority signal), but the priority change stays a separate,
  visible command rather than a hidden side effect.
* **Finish is always explicit.** Reaching the end, extracting every word,
  closing, navigating away, or crashing never finishes a topic automatically.
* **Extract finish nudge:** an extract that has produced at least one card and
  has been seen N times since the last one (default 3) is offered Finish.
  Without it, a collection fills with extracts the user mentally finished months
  ago but never formally closed.
* Dismiss retains content and provenance but removes scheduling.
* Suspend is a temporary removal; resume makes the element due today without resetting its interval.
* Finishing, dismissing, suspending, or deleting a parent never changes descendant schedules.

Priority and unified queue

**Priority sorts the queue; it does not shrink it.** Every failure mode in this
area traces back to conflating those two. Ordering and admission are separate
decisions, and neither may pull not-yet-due material forward or change an
interval.

Priority is **relative**, displayed as `0%` highest through `100%` lowest:

* Elements hold sortable fractional order keys; position, percentile, and
  pressure are derived at query time. An absolute 0–100 score inflates — every
  new import feels like an 80 — until twelve months in the field discriminates
  nothing and the overload valve has nothing left to work with. A relative order
  enforces scarcity structurally: there is exactly one 0%, and promoting one
  element necessarily demotes another.
* The rankable population contains every non-deleted element, including concepts
  and the collection root even when that root is unscheduled. Percent is a
  derived, discrete view of rank, not an independently stored value.
* Setting a priority rewrites one row. Reordering never renumbers the collection.
* **Priority UI:**
   * A percent slider on any element — reader, extract view, review, library,
     queue, and browser — on **Alt+P**, SuperMemo's own key. The dialog names the
     elements immediately above and below, because "more important than this,
     less important than that" is a judgement a person can make while an
     abstract 42% is not. SuperMemo's Shift+Ctrl+Up/Down Increase/Decrease
     commands are a separate, potentially A-coupled operation and stay disabled
     or version-gated until their transition is calibrated.
   * A **priority browser**: every element in one ordered list with
     drag-to-rebalance, filterable by type. The only place the shape of a
     collection's priorities is visible — usually the moment the user discovers
     that four hundred things are all "urgent".
   * **Spread**: lay a rank range across everything under one article while
     keeping its relative order. This is an explicit bulk reorder, not evidence
     that every new child inherits the parent's exact SuperMemo rank.
* SuperMemo 20 clipboard imports entered at position 1 in the controlled fresh
  collections. Exact extract, formatted-import, clone, and card insertion rules
  remain versioned product fallbacks until separately calibrated.
* Later parent-priority changes do not silently cascade.

Queue construction, per study day:

* Two streams — cards, and topics (sources and extracts competing together).
* Within each stream the sort key blends three signals:
  `priorityWeight × normalizedPriority + overdueWeight × cappedOverdue + jitter`
  (0.75 / 0.20 / ±5% by default). Strict priority order is wrong on its own:
  new material always feels important, so a precise sort lets today's imports
  displace last year's investment — the priority bias. The overdue term stops
  mid-priority material going stale invisibly; the jitter lets displaced
  material resurface. Zero randomization gives strict priority ordering.
* Randomization is **deterministic** per study day, so rebuilding the queue
  mid-session never moves the user's place.
* Default presentation is four cards followed by one topic, configurable. A hard
  **interleave floor** additionally guarantees a topic at least every N elements
  while topics remain due: items outnumber topics within months, and a pure sort
  front-loads items until reading stops — which kills the system, because
  reading is what generates future items.
* If one stream is empty, use the other without leaving unused slots.
* Default daily maxima, all configurable:
   * 200 unique cards
   * 20 new cards as a subset
   * 50 topics
   * at most 50% of a session from any one article's subtree
* These are maxima, not quotas. The queue is count-based and worked until the
  user stops — no time-budgeted sessions (this matches actual SuperMemo
  behavior; its "Plan" module is a separate day-planner, not the learning
  queue). Foreground durations are still logged from day 1 so time-based
  features remain possible post-v1.
* The queue reports what admission actually did — due volume, admitted volume,
  deferred volume, and **protection**: the percentile of the best-priority
  element that did not fit. Protection is the most honest indicator of whether
  priorities are being set honestly. If it sits at 3%, nothing in the 3–100%
  band is safe.

Settings

Every constant the schedulers run on is editable and none is compiled in. The
scheduling design's numbers are admitted starting points, not derived values, so
retuning one is a data change rather than a code change — and the same knobs are
what make this a SuperMemo-shaped tool rather than an imitation of one.

Settings are stored as flat key/value rows and consumed as one immutable
`AppSettings`. Decoding is **total**: a missing, unknown, or malformed value
falls back to the shipped default, because a collection that will not open
because one row is malformed is a collection that has been lost.

Sections: study day (zone, rollover) · daily queue (caps, proportion of topics,
interleave floor, randomization, sort weights, protected percentile, overload
tolerance, per-article share, Study More step) · topic scheduling (initializer
and transition policy versions, fallback bounds, explicit Finish, finish nudge)
· legacy interval sequences · cards (retention, learning and relearning
steps, maximum interval, fuzzing, leech threshold, sibling burying) ·
postponement (Later band, auto-postpone base, priority multiplier, dispersal,
Mercy horizon and cap) · reader (reminder distance) · diagnostics (log on/off,
rotation size, files kept, whether the panel may show element text).

The FSRS parameter vector itself stays pinned and versioned and is *not*
user-editable in v1: a hand-edited weight would silently reinterpret every
review already in the log. Retention, steps, and the interval cap are safe to
change at any time and are exposed.

Edits are held as a draft and written on Save, so a half-typed number never
reaches a scheduler. Saving invalidates everything that captured the previous
configuration — the calendar, the diagnostic sink's limits, today's queue, the
priority projections — so a changed cap applies without a restart.

Search

* Full-text search over sources, extracts, and cards, on **Ctrl+F**.
* Articles are indexed **whole**, not by title alone, so a passage is findable
  before it has ever been extracted. Cards are indexed on both sides, since a
  cloze carries its own answer.
* Free text is turned into a safe FTS5 expression: every token is quoted, so
  `NEAR`, `OR`, `*`, `-` and friends cannot leak through from prose, and the
  last token gets a prefix wildcard so results appear while the user types.
* Every result opens in **browse mode**. Looking something up must never be
  mistaken by the scheduler for having processed it.

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

The overload valve

A collection is expected to exceed learning capacity. That is the normal state
of incremental reading, not an error, so something has to shed work — and it
should be the lowest-priority work rather than whatever the user happens not to
reach. Three mechanisms, deliberately kept apart because conflating them is
where the failure modes come from:

* **Manual Later** — "wrong task right now". Delay scales with the element's own
  interval (10–30% by default), so Later on a two-day topic and on a one-year
  card do not mean the same thing.
* **Auto-postpone** — the daily valve, run when the queue is built. Delay is
  `interval × base × (1 + multiplier × pressure) × dispersal`. Three properties
  matter: it is **proportional**, so young elements are not lost to the void
  while mature ones recede far; **priority-graded**, so bottom-decile material
  goes roughly five times further than top; and **dispersed**, so a day's
  overflow does not land together on one future day and recreate the same
  overload.
* **Mercy** — a one-shot spread of an accumulated backlog across a horizon.
  Auto-postpone handles daily drift but chews a three-week absence one day at a
  time. Mercy resolves the whole backlog at once: the top of it lands within
  days and the tail lands months out. That distribution *is* the correct
  outcome, not damage control.

Rules all three obey:

* Preserve FSRS and topic algorithmic due dates and interval state. A deferral
  writes `deferredUntil` and nothing else — in particular never the last-review
  instant, because overwriting it would destroy the retention signal the whole
  schedule is built from.
* Original due remains available for overdue ranking and audit.
* Never create a fake review or topic encounter.
* Daily admission is transactional and **idempotent per study day**: its
  operation id is derived from the day, so rebuilding the queue five times in a
  session defers nothing a second time.
* Started learning/relearning steps are never auto-postponed. A brand-new card
  is *not* such a step — FSRS represents it as Learning too, but nothing has
  been started on it, so the daily new-card limit applies normally.
* **A protected top percentile (default 5%) is never auto-postponed.** Without
  this floor the valve eventually pushes everything out and the collection
  schedules nothing — the postpone death spiral. Protected elements stay due and
  force a decision: do it, or demote it by hand.
* **Study More** recalls automatic same-day deferrals, best priority first, and
  raises the caps for that build only. Manual postponements stand: the user said
  "not now" about that element specifically, and asking for more work is not
  them changing their mind. Raising a cap in Settings likewise does not undo a
  deferral already written; Study More is how those come back.
* A configurable home timezone and a default 04:00 study-day rollover. v1 offers
  the machine's own zone (daylight saving included, read from the OS) plus fixed
  UTC offsets. Naming an arbitrary IANA zone that differs from the machine's
  *and* follows its DST rules needs a bundled timezone database, which v1 does
  not carry — a city name would be a promise about daylight saving that could
  not be kept, so it is not offered. The domain already takes its offsets from
  an injected `TimeZoneRules`, so adding a database later is a data change.
* Sustained overflow above roughly 30% of due volume for several weeks means the
  collection is oversubscribed. The diagnostics panel says so, because the fix
  is bulk demotion in the priority browser, not a bigger cap.

## Persistence, Durability, and Export

* Keep the WAL-mode live SQLite database in platform-local application storage, never in Syncthing, Drive, or a synced folder.
* Enable foreign keys on every connection and enforce type, lifecycle, range, uniqueness, and one-to-one subtype invariants in SQL.
* Preserve immutable original Markdown, source hash, asset metadata, and immutable derived blocks.
* Store progress from the cursor rather than maintaining a second drift-prone percentage.
* Append review and activity events; increment item revision and dataset generation in every domain transaction.
* **The repetition log (`revlog_entries`) is the highest-value table in the
  collection**, because it is the only one that cannot be reconstructed. Every
  other table holds *current* state, which a bug can overwrite; this one records
  the inputs and the outputs of every scheduling decision — the A-factor's terms,
  a delay formula's inputs, the cap that triggered a deferral, the priority
  percentile at the time — for every element type in one indexed, queryable
  shape. It is append-only and written inside the same transaction as the change
  it describes. Undo appends an inverse/tombstone event; it never removes history.
   * One row per event: `review`, `topic_read`, `postpone`, `auto_postpone`,
     `manual_reschedule`, `dismiss`, `finish`, `suspend`, `resume`,
     `priority_change`, `bury`, `mercy`, `undo`, `practice`, `created`.
   * **Only `review` may ever feed a parameter optimizer.** A grade is attached
     only to `review` and `practice`, enforced in SQL as well as in Dart:
     training on postponements would teach the optimizer that the user's memory
     is worse than it is, because the elapsed time was never a retention test.
   * `elapsed_days` (what really passed) and `scheduled_days` (what the interval
     had been) are recorded separately. The gap between them is the signal, and
     it only exists because a postponement never overwrites the last-review
     instant.
   * `ReviewEvents` is not made redundant by it: that table remains the lossless
     FSRS record with full pre- and post-state JSON, one row per operation id,
     and is what undo and a future optimizer replay from.
* Build a transactional materialized `search_documents` table and a rebuildable
  external-content FTS5 index over it. Triggers keep the index in step inside
  whatever transaction wrote the content, so a search can never observe a
  half-applied import; the index stores no copy of the text and is restored from
  the materialized rows by a single statement.
* Create live backups through SQLite Online Backup or `VACUUM INTO`; validate before atomic rename. Never copy the active WAL files directly. [SQLite backup guidance](https://www.sqlite.org/backup.html) **Rolling backups exist from the end of M1** — before real study data accumulates.
* Retain 30 daily and 12 monthly backups. Keep pre-migration backups under separate retention.
* Snapshot and validate before Drift opens an older schema. Migrate transactionally, test every historical path, and reject newer unsupported schemas. Each step is written to be re-runnable — SQLite has no `ADD COLUMN IF NOT EXISTS`, and a migration that cannot be repeated is one that leaves the collection unopenable if it is interrupted. The current schema version is 5.
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

**Historical implementation status: complete; scheduling reconciliation now
required.** M4 was verified by 384 project tests, clean static analysis, the
native Windows workflow, the M2 and M3 regressions, and a Windows debug build.
Its scheduler sources and later SuperMemo calibration are now consolidated in
`plans/scheduler/LLM_FIX_INSTRUCTIONS.md`; any M4 behavior that conflicts with
that contract is legacy behavior to migrate, not current authority.

Delivered:

* **The historical A-factor topic model.** Its priority/completion/conversion
  modulation, priority-derived first intervals, and auto-finish are superseded.
  New work follows `topic_afactor_v2`; existing fixed-sequence and earlier
  A-factor data remain preserved until an explicit migration.
* **Relative priority in full**: derived percentiles and pressure, the Alt+P
  slider on every surface, Shift+Ctrl+Up/Down stepping, the priority browser with
  drag-to-rebalance and type filters, and Spread across an article's subtree.
* **The production queue**: blended priority/overdue/jitter ordering,
  deterministic per-day randomization, the configurable topic proportion and the
  hard interleave floor, per-stream caps with a new-card sub-limit, the
  per-article share cap, and admission counters including protection.
* **The overload valve**: interval-scaled manual Later, the daily auto-postpone
  pass with a protected top percentile, Study More, and Mercy.
* **The universal repetition log**, written by every command that changes a
  schedule, with the inputs of each decision and a hard separation between what
  an optimizer may train on and what it may not.
* **Undo-last-grade, edit-during-review, card postponement, sibling burying, and
  leech flagging.** Undo is reachable from the queue as well as the review
  screen, because that screen closes the moment a grade commits and the session
  is what the user is actually in the middle of.
* **FTS5 search** over articles, extracts, and cards, reachable on Ctrl+F.
* **Settings**: every scheduling constant, editable, with a total decoder.
* **A diagnostics panel** showing the day's admission numbers, recent commands,
  and — for one element — its schedule, its A-factor preview, and the before and
  after of every transition it has been through. Element text is withheld unless
  Settings turns it on, so the panel is safe to screenshot.
* **A local rotating structured log** of operation metadata, failures, and schema
  and app versions. Bounded, never throwing, and never containing element
  content.

Two product decisions departed from the earlier plan and are recorded above in
place: sibling burying ships (as a setting, on by default) rather than being
deferred past v1; and the home timezone offers the machine's own zone plus fixed
offsets rather than arbitrary IANA names, because v1 carries no timezone
database. Topic completion now always requires explicit Finish.

Gate — met: deterministic tests cover backlog (Mercy), repeated queue builds,
cap changes, DST, priority changes, failure recovery, and operation tracing;
undo-grade round-trips FSRS state identical to the pre-review snapshot;
priority-browser ordering survives restart.

M5 — Multi-block extraction, knowledge tree, and Windows polish

* Deliver multi-block extraction using proven native selection or the block-aware selector.
* Deliver the knowledge tree: folder hierarchy over sources, auto-lineage lower levels, drag-to-organize, and the four branch operations (review branch as practice session, set branch priority, suspend/resume branch, move/delete branch). Three of the four already have their machinery from M4: practice grades are implemented and provably inert, Spread is the bulk-reprioritization primitive, and suspend/resume are element commands — M5 adds the hierarchy and applies them to a subtree.
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
* Undo-grade restoring the exact pre-review FSRS state while appending an inverse/tombstone event and preserving the original event.
* Formulate without extract rescheduling.
* Back/crash without topic advancement; soft-position restore after process death.
* Idempotent Done, review, extraction, and auto-postpone.
* Unicode and formatted selection/provenance; anchors under virtualization (unmounted blocks).
* Timezone, DST, and 04:00 rollover.
* Migration, corruption, disk-full, restore, and interrupted export. (Handoff-return and divergence move to v1.1.)
* Topic initialization reference vectors: blank Alt+N starts at A `1.2`; later
  paste does not change it; Ctrl+N uses UTF-16 length; ASCII, `é`, and emoji at
  200 UTF-16 units all display A `1.625`; Later leaves canonical interval and A
  unchanged while a genuine Done advances exactly once.
* A postponement of any kind never writes a grade, an interval, or a
  last-review instant — and the log records it as a deferral.
* The protected top percentile survives a day that sheds everything else.
* Randomization is stable within a study day, so a rebuild does not move the
  user's place.
* Settings round-trip through storage, and a malformed row falls back to its
  default rather than failing to open the collection.
* Every migration step is re-runnable, so an interrupted upgrade is not fatal.

Assumptions:

* Markdown is the only v1 import format; other formats decided later.
* Typical sources are long chapters (10–50k words).
* Sources are immutable snapshots; importing changed content creates a new source version.
* SQLite remains canonical; the activity log supports diagnosis and audit but is not an event-sourced database.
* Exact undocumented SuperMemo formulas are replaced with transparent configurable topic sequences while preserving its topic/item, priority, dismissal, mixing, and overload behavior.
* FSRS runs on pinned default parameters in v1; a per-user optimizer is post-v1 and the review log already captures everything it needs.
* RTL/bidi, Anki import/export, sibling burying, and statistics/dashboards are out of scope for v1.
* PDF/HTML import, live synchronization, merge resolution, dashboards, knowledge graphs, highlights, notes, and assistance are post-v1.
