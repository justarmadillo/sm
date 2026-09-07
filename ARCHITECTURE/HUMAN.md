# Incremental Reader — Human Architecture and Study Guide

> Audience: maintainers and developers who can browse the repository. Scope:
> this guide describes every hand-written Dart library under
> <code>lib/</code>. It is intended to be read alongside the code, gradually.
> It deliberately explains the reasons behind the structure, so you can
> diagnose and repair the app without relying on an LLM. Generated code such
> as <code>lib/storage/database/app_database.g.dart</code> is described but is
> not a source of truth to edit.

For a conversational LLM that cannot browse the repository, use
<code>ARCHITECTURE/LLM.md</code> instead. That companion is deliberately
organized around symptoms, execution paths, and exact file packets.

## How to use this document

Do not try to memorize the whole project in one sitting. Treat it as a map:

1. Start with the one-page model and the startup path.
2. Pick one visible feature, then follow its query or command into the domain
   and storage layers.
3. Read the tests named in the testing section when a rule is unclear.
4. Return here when you need to answer “where should this code live?” or
   “what else must change if I alter this?”

### Verified scope and source-of-truth order

This snapshot was audited against the repository on 2026-09-07. At that
point, <code>lib/</code> contained 194 hand-written Dart files and one generated
Drift file, <code>app_database.g.dart</code>; the database schema version was 17.
The file-by-file tables later in this guide cover every hand-written library.
Counts are a completeness check, not a compatibility promise: rerun the
inventory after adding or deleting files.

When two descriptions disagree, use this order of authority:

1. Runtime code and its focused tests describe what the app does now.
2. <code>RULES.md</code> and the nearest <code>lib/**/README.md</code> describe
   intended ownership and coding constraints.
3. <code>plans/scheduler/SM20_AIO_SCHEDULER.md</code>, the implementation
   handoff, and the retained SM20 executable/fixtures describe compatibility
   evidence for the SM-20 port.
4. These architecture guides explain and route through those sources; update
   them when the sources change.

The app is local-first rather than network-free. It has no backend, account,
sync protocol, or remote database. It can nevertheless fetch a remote video
thumbnail and hand a timestamped link to the system browser. Collection rows,
imported image bytes, logs, and backups remain local.

The app has one local collection and no server. Application feature logic is
under <code>lib/</code>; the FSRS engine is the explicit vendored dependency in
<code>fsrs-dart/</code>. Most behaviour is intentionally expressed in plain
Dart classes, with Flutter reserved for presentation and Drift reserved for
persistence.

## One-page mental model

Incremental Reader manages four kinds of learning element:

| Element type | What it represents | How it is processed |
| --- | --- | --- |
| Source | An imported Markdown document | Read incrementally with SM-20 |
| Extract | A copied passage from a source or another extract | Read incrementally with SM-20 |
| Card | A Q&A, cloze, overlapper, or image-occlusion recall prompt | Reviewed with FSRS |
| Video element | A whole video or a chosen time range | Watched incrementally with SM-20 |

Three relationships must stay separate:

| Question | Authoritative data | Why it is separate |
| --- | --- | --- |
| What did this come from? | Extract provenance and card parent | Preserves context and citations |
| Where did the user file it? | <code>ElementSchedule.parentElementId</code> and <code>ordinal</code> | Lets the Browser rearrange a tree without corrupting provenance |
| When should it return? | <code>ElementSchedule</code> plus topic/card state | Scheduling must not change when content is moved or edited |

~~~mermaid
flowchart TB
  UI["Flutter screens and widgets<br/>lib/features"] --> VM["View models"]
  VM --> CQ["Commands and queries"]
  CQ --> RUN["Command runners"]
  RUN --> DOM["Pure domain rules<br/>documents, scheduling, settings"]
  RUN --> CONTRACTS["Storage contracts"]
  CONTRACTS --> DRIFT["Drift repositories"]
  DRIFT --> DB["SQLite collection and local files"]
  APP["app and main"] -. wires concrete objects .-> UI
  APP -. wires concrete objects .-> RUN
  APP -. wires concrete objects .-> DRIFT
~~~

The arrows above are intentional. A screen can ask a repository through a
contract, but it cannot import the concrete Drift or database code. A
scheduler can use a storage promise, but cannot know SQLite or Flutter.

## The dependency rules that keep the project understandable

<code>test/architecture/folder_rules_test.dart</code> automatically checks
these boundaries. If that test fails, do not enlarge its allow-list just to
make an import compile. Move the code to the layer that is allowed to own it.

| Folder | May know about | Must not know about | Main job |
| --- | --- | --- | --- |
| <code>shared/</code> | Nothing else in the app | Flutter, storage, features, domain layers | Small universal building blocks |
| <code>shared/ui/</code> | Flutter and shared/domain presentation types | A particular feature or database | Reusable visual language |
| <code>documents/</code> | <code>shared/</code> | Flutter, storage, scheduling, settings | Content models, parsing, positions, edits |
| <code>settings/</code> | <code>shared/</code>, storage contracts | Flutter and concrete storage | Typed configuration |
| <code>scheduling/</code> | <code>shared/</code>, <code>settings/</code>, storage contracts | Flutter and Drift/SQLite | Queue and scheduler mathematics |
| <code>storage/</code> | Documents, scheduling, shared | Screens and app wiring | Persist and retrieve the domain |
| <code>features/</code> | All domain layers and storage contracts | Drift and raw SQLite | A visible user capability |
| <code>app/</code> | Everything | Nothing by architecture rule | Choose concrete implementations and wire them |

This is a practical version of dependency inversion:

- Inner code describes what it needs through an interface.
- Outer code chooses the implementation.
- Tests can substitute a fake clock, ID generator, repository, or time zone
  without opening Flutter or SQLite.

## Startup: from process launch to the Study screen

<code>lib/main.dart</code> is the only entry point. It deliberately performs
critical work before the first Flutter frame:

1. <code>WidgetsFlutterBinding.ensureInitialized()</code> enables platform
   APIs.
2. <code>AppPaths.resolve()</code> finds application-support storage and
   <code>ensureCreated()</code> makes its database, backup, asset, and log
   folders.
3. <code>openCollectionOrFail()</code> checks an existing SQLite file,
   refuses a database from a newer schema, creates a pre-migration backup when
   necessary, then opens Drift.
4. A root Riverpod <code>ProviderContainer</code> is created with the real
   database and paths as overrides.
5. Partial image files and unreferenced immutable image blobs are cleaned up.
6. Settings are loaded before the first build so widgets do not briefly show
   defaults and then jump to saved values.
7. At most one rolling daily backup is created, before the session writes.
8. <code>IncrementalReaderApp</code> is attached with
   <code>UncontrolledProviderScope</code>; its home route is
   <code>QueueScreen</code>.

If step 3 fails, the app does not construct the normal provider graph.
<code>RecoveryApp</code> and <code>RecoveryScreen</code> instead offer backup
recovery without requiring the failed database to open.

### Bootstrap source reference

| File | Responsibility |
| --- | --- |
| <code>lib/main.dart</code> | Resolves paths, opens or classifies the collection, cleans asset remnants, warms settings, runs the daily backup, and starts the root provider scope. |
| <code>lib/app/incremental_reader_app.dart</code> | Root <code>MaterialApp</code>, shared theme, and initial <code>QueueScreen</code> route. |
| <code>lib/app/providers.dart</code> | Application-wide concrete dependency wiring. |
| <code>lib/app/startup_gate.dart</code> | Raw SQLite health/schema classification before the provider graph can exist. |
| <code>lib/app/startup_tasks.dart</code> | Settings warm-up and non-fatal once-per-study-day backup work. |

### Composition root and Riverpod

<code>lib/app/providers.dart</code> is the composition root. It is not a
service locator disguised as state management: providers merely assemble
objects that already receive dependencies through constructors.

It chooses:

- the concrete Drift repositories and transaction runner;
- <code>SystemClock</code>, UUID IDs, timezone resolution, and the device ID;
- cached typed settings and the live scheduling context;
- in-memory plus rotating-file diagnostics;
- content-addressed asset storage and backup services;
- feature-independent read models such as effective due dates.

Feature provider files only build objects needed by one screen. For example,
<code>features/reader/reader_providers.dart</code> makes a
<code>ReaderCommandRunner</code>; it does not add it to the app-wide provider
list.

### Flutter and Riverpod vocabulary used here

| Term | Meaning in this project |
| --- | --- |
| Widget | A visual component. Screens are usually <code>ConsumerStatefulWidget</code> when they need local UI state or effects. |
| Provider | A recipe for one object or value; it is built lazily by Riverpod. |
| View model | An <code>AsyncNotifier</code> holding screen state and translating taps into commands. It does not own SQL. |
| Provider family | One view model per argument, such as one reader state per source ID. Riverpod names the inherited argument <code>arg</code>. |
| <code>ref.watch</code> | Rebuild when the watched value changes. |
| <code>ref.read</code> | Use an object without subscribing to future changes; typical for an action handler. |
| <code>ref.invalidate</code> | Throw away a cached provider so it reloads current data after a mutation. |

## The standard read/write shape

The same vocabulary is used across features:

| File suffix | Responsibility | May write? |
| --- | --- | --- |
| <code>_screen.dart</code> | Widgets, routing, dialogs, local visual state | No direct persistence |
| <code>_view_model.dart</code> | Screen state and action orchestration | Starts commands through a runner |
| <code>_commands.dart</code> | Immutable description of one requested mutation | No |
| <code>_command_runner.dart</code> | Validates, applies domain rules, persists one transaction | Yes, via contracts |
| <code>_query.dart</code> | Normally builds a read projection for a screen | Normally no; see the queue exception below |
| <code>_providers.dart</code> | Creates that feature’s collaborators | No domain work |
| <code>widgets/</code> | Feature-local visual pieces | No direct persistence |

### What happens when a user presses a button

For a write such as “Later” on a source, the intended path is:

1. The screen or its view model creates a command carrying one
   <code>OperationId</code>.
2. The command runner begins a transaction through
   <code>TransactionRunner</code>.
3. It asks <code>SchedulingContext</code> for current settings, the study-day
   calendar, scheduler, priority scale, and persisted SM-20 random state.
4. Pure scheduling code calculates the replacement state.
5. The runner saves it through a storage contract, appends history, activity,
   and diagnostics as appropriate, and persists a new random seed when draws
   were consumed.
6. The successful domain transaction advances the collection generation.
7. The view model refreshes its query and shows a success or failure message.

<code>shared/command_execution.dart</code> centralizes the normal command
boundary: transaction execution, duplicate-operation detection, optional
replay, dataset-generation advance, and structured diagnostics. A few
specialized runners use the same guarantees directly because their work has
custom replay rules.

There is one deliberate naming exception: <code>QueueQuery.load()</code> first
invokes the idempotent <code>QueueCommandRunner.runDailyAdmission()</code>, then
projects the persisted plan. Admission may run automatic Smart Postpone,
append newly due work, sort once for the study day, and update runtime/history
state. Its operation ID is derived from the study day, so refreshing or
restarting cannot repeat the admission. All other query methods remain pure
reads; new write-through queries should not be added by analogy.

### Safety properties every mutation should preserve

| Property | Mechanism |
| --- | --- |
| Expected mistakes do not crash the UI | Commands return <code>Result&lt;T&gt;</code> with named failures such as validation, not found, conflict, storage, or unexpected. |
| A double tap does not count twice | One <code>OperationId</code> flows through commands, activity rows, review rows, edit journals, and scheduler events. |
| Compound changes do not partially commit | Command runners own one database transaction; repositories do not open independent policy transactions. |
| Simultaneous edits/reviews do not silently overwrite | Schedule rows and content revisions are checked with compare-and-swap or explicit revision comparisons. |
| Time-sensitive code is testable | Domain code receives a <code>Clock</code>; it never calls <code>DateTime.now()</code>. |
| Random SM-20 decisions are reproducible | The one global Delphi-compatible PRNG seed is persisted in the SM-20 runtime state. |
| Diagnostics do not leak study content | Diagnostic fields contain IDs, counts, versions, and failure types, not source text. |

## Domain model: the collection in memory

~~~mermaid
classDiagram
  class Source {
    Markdown text
    content revision
    explicit marker
    soft position
  }
  class Extract {
    copied Markdown
    provenance range
    own schedule
  }
  class Video {
    URL and metadata
  }
  class VideoElement {
    time range
    optional parent clip
    own schedule
  }
  class Card {
    front and back
    optional parent
    own FSRS state
  }
  class ElementSchedule {
    priority
    lifecycle
    due day
    Browser parent and ordinal
  }
  Source "1" --> "*" Extract : provenance may start here
  Extract "1" --> "*" Extract : nested provenance
  Source "1" --> "*" Card : optional direct parent
  Extract "1" --> "*" Card : optional parent
  VideoElement "1" --> "*" Card : optional parent
  Video "1" --> "*" VideoElement : ranges
  VideoElement "0..1" --> "*" VideoElement : clip parent
  Source --> ElementSchedule
  Extract --> ElementSchedule
  VideoElement --> ElementSchedule
  Card --> ElementSchedule
~~~

### Shared element identity and lifecycle

<code>scheduling/element.dart</code> gives every schedulable thing an
<code>ElementRef</code>: an ID plus an <code>ElementType</code>. The enum
ordering is stored in the database, search index, and history; append new
values only, never reorder existing ones.

Each element has one <code>ElementSchedule</code>:

- <code>priority</code> is a relative lexicographic order key;
- <code>lifecycle</code> is active, dismissed, or deleted;
- <code>dueDay</code> and <code>originalDueDay</code> record eligibility and
  its un-postponed baseline;
- <code>rootId</code> retains a source citation;
- <code>parentElementId</code> and <code>ordinal</code> represent Browser
  filing, not provenance;
- <code>revision</code> supports optimistic concurrency.

An active element may enter the queue. Dismissed content remains intact but
does not schedule. Deleted is a soft lifecycle state; the Reader’s
<code>DeleteSource</code> uses it. Permanent erasure is deliberately confined
to the Browser delete command and requires confirmation.

### Content entities

| Entity | Important invariant |
| --- | --- |
| <code>Source</code> | Markdown is normalized and SHA-256 hashed. Reading position is separate from schedule. It has an explicit marker that counts as progress and a soft saved scroll position that never does. |
| <code>Document</code> and <code>Block</code> | A source parsed at one content revision. Blocks retain exact raw Markdown spans, visible text spans, and source offsets. |
| <code>Extract</code> | Stores a copy of selected Markdown plus provenance into its immediate parent. It keeps an independent schedule and survives parent editing/deletion. |
| <code>Card</code> | Supports Q&A, cloze, cloze overlapper, and image occlusion. Its parent may be a source, extract, video range, or null for a standalone card. |
| <code>Video</code> | One remote URL and metadata. It is not itself scheduled. |
| <code>VideoElement</code> | A whole-video range or a clip. A clip is simply a narrower range with a parent video element, and gets its own schedule. |
| <code>SourceAsset</code> | Metadata for an image reference in source Markdown. Actual bytes are immutable content-addressed files outside SQLite. |
| <code>CardOcclusion</code> | One card’s image hash, dimensions, normalized rectangle set, active region, and reveal mode. |

## Documents, Markdown, and safe editing

This is one of the most important subsystems to study because it protects
references made today from edits made months later.

### Four coordinate spaces

Only one coordinate is stored permanently: a UTF-8 byte offset into the exact
Markdown source. The app translates among four spaces in
<code>documents/reader_coordinates.dart</code>:

| Space | Unit | Used by |
| --- | --- | --- |
| Document | UTF-8 byte offset in the complete Markdown | Stored markers and extract provenance |
| Block raw | UTF-16 index in <code>Block.raw</code> | Parser and block editing |
| Block content | UTF-16 index after syntax such as heading markers is removed | Block display |
| Rendered | UTF-16 index in parsed inline plain text | Selection and highlighting |

Why UTF-8 bytes? Dart’s string indices are UTF-16, but persisted documents
need a stable, encoding-independent address. Emoji and other non-BMP
characters make a naive character-count approach wrong. All conversions are
centralized in <code>shared/utf8_offsets.dart</code>.

### Parsing and rendering

<code>markdown_block_parser.dart</code> normalizes line endings, splits source
Markdown into headings, paragraphs, list items, quotes, fences, and other
block types, and records exact byte offsets. It runs at import and after a
source edit. <code>markdown_inline_parser.dart</code> handles emphasis, strong
text, code, links, images, strikethrough, and math-like inline spans while
preserving a map between rendered text and original Markdown.

The persisted <code>blocks</code> table is a derived cache. A source edit
rebuilds the whole block set rather than trying to patch nearby blocks. No
persisted object refers to a block ID, so this is safe and avoids ambiguous
partial re-parsing.

### Editing is an explicit splice, never a diff

<code>TextSplice</code> says: replace the half-open UTF-8 byte range
<code>[startUtf8, endUtf8)</code> with normalized text. Insert, delete, and
replace are the same operation.

The app does not diff an old and new document. Repeated phrases mean a diff
can have several plausible answers, and a wrong answer would silently move a
marker or extract to the wrong paragraph. Block editing makes the exact source
range known before the user types.

When a splice is applied:

1. It is validated for bounds, UTF-8 character boundaries, size, and whether
   it changes anything.
2. <code>applySourceEditToText</code> calculates the new text, new revision,
   moved marker/soft position, and migrated child provenance as a pure
   function.
3. A source-edit journal row stores the splice, removed text, operation ID,
   and positions that migration cannot reconstruct exactly.
4. The source, affected provenance, and derived blocks are committed in one
   transaction.
5. Undo appends the inverse splice at a new revision. It never rewinds or
   deletes history.

If an edit overlaps a child extract’s original range, its provenance becomes
<code>stale</code> or <code>orphaned</code>; it is never “repaired” by
searching for matching text, because repeated text would make that repair
untrustworthy.

### Reader-specific visual modules

The Reader is intentionally decomposed because selection and rendering have
many interacting coordinate rules:

- <code>reader_view.dart</code> supplies scrolling, positioning, and a
  block-based viewport.
- <code>block_view.dart</code> draws one visible block and its edit/extract
  affordances.
- <code>block_span_builder.dart</code> builds styled spans and inline images.
- <code>reader_selection.dart</code>, <code>selection_knobs.dart</code>, and
  <code>selection_toolbar.dart</code> own text selection and extraction
  interactions.
- <code>reader_side_panel.dart</code> presents outline and extracts.
- <code>block_editor.dart</code> edits a known block range.
- <code>extract_highlights.dart</code> determines source spans already
  extracted.

## Scheduling: when something comes back

Scheduling is pure Dart wherever possible. This lets a due-date bug be
reproduced with a unit test rather than a widget test or a real database.

### Study days and time zones

<code>StudyDay</code> is a local calendar date with a configurable rollover
(default 04:00), not simply midnight in the machine’s current zone.
<code>StudyDayCalendar</code> maps UTC instants to that date and handles
daylight-saving boundaries explicitly. A persisted named home zone is resolved
through <code>storage/platform/time_zones.dart</code>, not through the
travelling device’s current clock setting.

### Topics use SM-20; cards use FSRS

| Family | Applies to | Core state | Main implementation |
| --- | --- | --- | --- |
| SM-20 topic scheduling | Sources, extracts, video elements | <code>TopicState</code>: A-factor, stored interval, status, repetitions, postponements, exact Real48 values | <code>scheduling/topics/topic_scheduler.dart</code> |
| FSRS card scheduling | Cards | <code>CardMemory</code>: stability, difficulty, state, learning step, due instant, repetitions and lapses | <code>scheduling/cards/card_scheduler.dart</code> |

This split is intentional. A source is processed; a card tests recall. Changing
FSRS settings must never reinterpret source/extract/video schedules.

#### SM-20 details worth preserving

- <code>TopicScheduler</code> is the one topic state machine. It creates,
  completes, remembers, force-repeats, reschedules, postpones, dismisses,
  restores, forgets, deletes, and adjusts A-factor.
- <code>sm20_numeric.dart</code> implements Delphi-compatible Real48 storage,
  tie-to-even rounding where required, a global 32-bit random stream, random
  spreading, and heap-sort ties. Replacing these with ordinary Dart rounding,
  <code>Random</code>, or a library sort can change future intervals.
- <code>Sm20RuntimeStore</code> persists queues, stages, global PRNG seed,
  learning start day, and automatic-pass timestamps as one versioned settings
  value: <code>sm20.runtime.v1</code>.
- A low-level reschedule changes due/interval state but is not a repetition.
  Postpone, Smart Postpone, Advance, and Mercy must not invent a review.

#### FSRS details worth preserving

- <code>CardScheduler</code> hides the third-party <code>fsrs_dart</code>
  types behind application-owned, versioned values.
- A new card is immediately eligible but has null stability/difficulty until
  its first genuine rating.
- A genuine review creates a lossless <code>ReviewRecord</code> with full
  pre/post memory JSON, then writes a new card state. The record preserves
  enough information for deterministic replay and recovery.
- <code>FsrsMemoryRecomputer</code> replays real review history if an FSRS
  parameter vector changes. It does not replay postpone or practice events.
- A card can be identified as a leech after its configured lapse threshold.
  The Review screen gives the user a reformulation escape hatch.

### Priority is relative, not an absolute score

<code>PriorityRank</code> stores a lexicographically sortable string. Lower
keys are more important. A new key can be created between two neighbouring
keys without rewriting the entire collection.

<code>PriorityScale</code> derives position, percentage, normalized priority,
and pressure from the current sorted collection. A displayed percentile is
therefore a projection, not durable data. This avoids the false implication
that priority is an independent numerical score.

### The daily queue

<code>QueuePolicy</code> builds the Outstanding queue:

1. Load active, due, non-pending candidates.
2. Split card/item and topic families.
3. Score by current relative priority.
4. Use the SM-20-compatible heap ordering.
5. Apply configured randomization while consuming the shared PRNG stream.
6. Merge item and topic streams according to the configured topic percentage.

Pending and Final Drill are separate stages rather than silently being mixed
into Outstanding. <code>QueueCommandRunner</code> persists admission, stage
transitions, manual randomization, and Smart Postpone consequences.
<code>QueueQuery</code> is read-only and turns stored state into screen rows.

### Backlog tools

| Tool | Pure decision code | Persistence workflow |
| --- | --- | --- |
| Later / automatic postpone | Topic/card low-level reschedule rules, plus <code>sm20_postpone.dart</code> | Moves canonical due state without a review |
| Smart Postpone | <code>SmartPostponeEngine</code> chooses candidates and delays; supports profiles, protected count, scope, simulation, forced pass | Queue runner applies exact decisions transactionally |
| Advance | <code>Sm20AdvanceEngine</code> pulls eligible future work closer while consuming draws in executable order | Priority Browser runner applies topic repetitions or card reschedules as appropriate |
| Mercy | <code>Sm20MercyEngine</code> gathers, scores, orders, and assigns future days using a 20×20 factor matrix | Preview is stored, Apply checks snapshots, Undo restores exact canonical states |

Mercy deserves special caution: its preview, apply, and undo can be separated
by a restart. <code>MercyBatch</code> persists the preview and exact
before/after state. A stale preview is rejected before any write, rather than
recomputed against changed collection state.

### History and diagnostics

There are several complementary histories:

| Record | What it preserves |
| --- | --- |
| <code>ReviewEvents</code> | Full FSRS review pre/post state, retained for deterministic replay/recovery and parameter replay |
| <code>RevlogEntries</code> / <code>ReviewLogEntry</code> | One flat, queryable scheduling event for any element type |
| <code>SchedulerEvents</code> | Rich authoritative audit envelope: study day, versions, canonical before/after states, due values, batch and undo links |
| <code>ActivityEvents</code> | Command-level audit/diagnostic activity, not a replacement for current state |
| <code>DiagnosticSink</code> | Recent in-memory events and optional rotating text log |

Only genuine scheduled reviews feed a future FSRS optimizer. Postponements and
practice grades do not measure retention and must stay out of that training
data.

## Settings

Settings are stored as flat string key/value rows but used as one immutable
<code>AppSettings</code> object. <code>SettingsStore</code> loads once,
caches, saves only changed keys, and invalidates the cache deliberately.

| Group file | Controls |
| --- | --- |
| <code>study_day_settings.dart</code> | Home IANA timezone and rollover minutes |
| <code>queue_settings.dart</code> | Topic/item mix, randomization, auto-sort, Final Drill and stage confirmations |
| <code>remember_settings.dart</code> | Initial topic interval range |
| <code>card_settings.dart</code> | FSRS parameters/version, retention, steps, max interval, fuzzing, leeches, sibling burying, overlap context |
| <code>postpone_settings.dart</code> | Whether automatic postpone is enabled plus profile assignment registry |
| <code>smart_postpone_settings.dart</code> | Scope, profiles, limits, thresholds, simulation, and item/topic delay rules |
| <code>mercy_settings.dart</code> | Mode, horizons, cap, score weights, and optional factor matrix |
| <code>diagnostics_settings.dart</code> | Rotating log enablement, size, retention, and content visibility in diagnostics |

The Settings screen keeps a draft until Save. It uses
<code>FsrsSettingsRescheduler</code> to atomically save FSRS-relevant changes,
recompute card memory when parameter versions change, and optionally
recalculate due dates. It then invalidates providers that captured old
configuration.

Persisted key strings are data compatibility contracts. Renaming a Dart field
is normally safe; renaming a string such as <code>queue.auto_sort</code> is a
migration and must not be done casually.

## Persistence and recoverability

### Storage contracts and concrete repositories

Features and scheduling code depend on these interfaces:

| Contract | Owns |
| --- | --- |
| <code>ContentRepository</code> | Sources, documents/blocks, source edits, extracts, and cards |
| <code>VideoRepository</code> | Videos and scheduled video ranges |
| <code>LearningRepository</code> | Schedules, topic/card state, queue facts, priority, review/history/activity, Mercy batches |
| <code>SourceAssetRepository</code> | Source Markdown image metadata |
| <code>OcclusionRepository</code> | Card-owned image mask metadata |
| <code>SearchRepository</code> | Materialized full-text documents and FTS search |
| <code>SettingsRepository</code> | Raw key/value settings |
| <code>TransferRepository</code> | Dataset identity and monotonically increasing generation |
| <code>TransactionRunner</code> | One atomic transaction boundary |
| <code>DatabaseMaintenance</code> | Derived-data repair, compaction, and statistics |
| <code>DatabaseCheck</code> | Physical check followed by atomic logical-integrity repair |

Every storage contract has a matching <code>Drift…Repository</code> in
<code>storage/drift/</code>. The implementations contain SQL, query ordering,
row mapping, and persistence mechanics; they do not decide scheduling policy.
<code>row_converters.dart</code> is the explicit boundary where Drift row
shapes and frozen storage names become readable domain values.

### SQLite schema

The current schema version is 17. Drift tables are defined in
<code>storage/database/tables.dart</code>; migrations, indexes, FTS triggers,
and SQLite health helpers live in <code>app_database.dart</code>.

| Table | Purpose |
| --- | --- |
| <code>sources</code> | Source Markdown, hash, revisions, markers, and soft positions |
| <code>source_assets</code> | Source-owned image references and blob metadata |
| <code>source_edits</code> | Append-only text-splice journal |
| <code>blocks</code> | Derived parsed block cache |
| <code>extracts</code> | Extract text and provenance |
| <code>videos</code> | One remote video URL and metadata |
| <code>video_elements</code> | Whole-video ranges and clips |
| <code>cards</code> | Prompt content and optional polymorphic parent |
| <code>card_occlusions</code> | One image/mask configuration per occlusion card |
| <code>element_schedules</code> | Common identity, priority, lifecycle, due projection, Browser filing |
| <code>topic_states</code> | Exact SM-20 state for sources, extracts, and video elements |
| <code>card_memories</code> | Exact FSRS state for cards |
| <code>review_events</code> | Lossless FSRS review records |
| <code>revlog_entries</code> | Universal append-only repetition log |
| <code>scheduler_events</code> | Rich scheduler audit events |
| <code>mercy_batches</code> | Durable Mercy preview/apply/undo state |
| <code>search_documents</code> | Materialized search content for external-content FTS5 |
| <code>activity_events</code> | Append-only command activity |
| <code>settings</code> | Flat persisted configuration and runtime values |
| <code>dataset_meta</code> | Dataset ID, generation, writer epoch, and owner device |

The FTS5 index is derived from <code>search_documents</code>, maintained by
SQLite triggers, and can be rebuilt. It is not the source of truth.

### Database compatibility rules

Do not edit <code>app_database.g.dart</code>; regenerate it with the normal
Drift/build process after a deliberate schema change.

More importantly, these names are frozen by persisted data:

- Drift table getter names and database column names in
  <code>tables.dart</code>;
- enum order or explicit stored values;
- settings keys;
- JSON keys/snapshots and raw SQL migration strings;
- historic names such as <code>revlog_entries</code>, <code>reps</code>, and
  <code>prng_seed</code>.

A new column or table requires a new schema version, an appended migration
step, generated code, and migration tests. Never rename database data because
it “looks cleaner” without a migration plan.

### Local files, assets, backups, and recovery

<code>AppPaths</code> chooses application-support storage. The live SQLite
file must not be placed in a sync folder: a sync client copying a database
while its WAL files are changing can corrupt it.

| File subsystem | Design |
| --- | --- |
| Source assets | <code>SourceAssetFileStore</code> writes immutable blobs by SHA-256 filename. Database rows refer to hashes, so deduplication and safe cleanup are possible. |
| Image occlusion | Reuses the same asset directory; card rows carry the image hash and normalized rectangle metadata. |
| Daily backup | <code>BackupService</code> takes a consistent SQLite snapshot through SQLite itself, validates it, packages referenced assets, then atomically promotes it. |
| Pre-migration backup | <code>createPreMigrationBackupIfNeeded</code> creates a separately retained database snapshot before Drift upgrades schema. A failure blocks startup. |
| Restore | <code>BackupRestoreService</code> validates a backup before provider construction, moves current database/WAL/SHM files aside, and rolls back displaced files if promotion fails. |
| Logs | <code>RotatingLogSink</code> serializes compact JSON lines and rotates bounded files. A log failure disables logging rather than breaking the app. |

<code>DriftDatabaseMaintenance</code> checks health, rebuilds a stale FTS
index, checkpoints WAL, vacuums, and analyzes. <code>DriftDatabaseCheck</code>
first runs SQLite’s quick check, then repairs relationships SQLite cannot
express through ordinary foreign keys: orphan search rows, missing schedules,
invalid parent/root links, inconsistent FSRS snapshots, malformed state, and
derived index issues. It distinguishes a corrupt file from a repairable
logical inconsistency.

## Feature guide

All visible capabilities live in <code>lib/features/</code>. The home screen
is Today / <code>QueueScreen</code>; its app bar opens Browser, Priority,
Search, Settings, Diagnostics, and creation flows.

### Browser — collection tree and permanent deletion

The Browser is the one visual tree for the entire collection. It separates
provenance from filing: moving a row changes its schedule row’s parent/ordinal
only, never an extract’s recorded source range.

| File | Role |
| --- | --- |
| <code>add_element_flow.dart</code> | Starts standalone Markdown source, video, card, and occlusion creation flows from Home. |
| <code>browser_screen.dart</code> | Tree UI, selection mode, filtering, drag/drop, import, create, search, and destructive-delete confirmation. |
| <code>browser_view_model.dart</code> | Turns UI intentions into commands and exposes one-shot messages. |
| <code>browser_tree_query.dart</code> | Loads all elements and arranges them by filing parent/ordinal into nested nodes. |
| <code>element_content_query.dart</code> | Loads one element’s editable/readable body for dialogs. |
| <code>open_element.dart</code> | The one dispatcher that opens a source, extract, video, or card in the appropriate browse/editor surface. |
| <code>browser_commands.dart</code> | Immutable move, nest, lift, file-under, delete-one, and delete-many requests. |
| <code>browser_command_runner.dart</code> | Transactional filing and permanent subtree erasure; deletes in foreign-key-safe order and removes queue references. |
| <code>browser_providers.dart</code> | Wires the tree query, runner, and content query. |
| <code>import_sheet.dart</code> | Markdown source import dialog. |

Browser deletion is the only irreversible content removal path. It removes
selected branches (including descendants and provenance dependents) in an
order compatible with foreign keys. Scheduling history is normally retained;
card review history must be removed only because its foreign key requires it.

### Reader — source processing and Markdown editing

The Reader has two modes:

- <strong>scheduled</strong>: Done, Later, Dismiss, priority and progress
  actions are available;
- <strong>browse</strong>: the source can be inspected/edited but merely
  looking at it cannot record a repetition.

| File | Role |
| --- | --- |
| <code>reader_screen.dart</code> | Source reading surface, scheduled action bars, side-panel presentation, routing helpers, and local scroll/session behaviour. |
| <code>reader_view_model.dart</code> | Loads a source/document/state and starts reader commands; keyed by <code>ReaderRequest</code>. |
| <code>reader_commands.dart</code> | Import, marker/soft position, Done, Later, lifecycle, rename, block edits, images, section moves, and source-edit undo. |
| <code>reader_command_runner.dart</code> | Applies all Reader mutations, including topic scheduling, text edits, images, search materialization, and histories. |
| <code>reader_providers.dart</code> | Wires the runner and replaceable native image input. |
| <code>reader_image_input.dart</code> | File picker/clipboard abstraction for image import, replaceable in tests. |
| <code>typography_controller.dart</code> | Riverpod notifier for Reader typography. |
| <code>widgets/reader_view.dart</code> | Continuous block scroll view and scrolling-to-anchor support. |
| <code>widgets/block_view.dart</code> | One rendered block, gutter, marker, and extract affordances. |
| <code>widgets/block_span_builder.dart</code> | Inline text/image spans and highlight projections. |
| <code>widgets/block_editor.dart</code> | Block-scoped Markdown editor that creates an exact splice. |
| <code>widgets/reader_selection.dart</code> | Selection model/controller and viewport coordination. |
| <code>widgets/selection_toolbar.dart</code> | Contextual selection actions. |
| <code>widgets/selection_knobs.dart</code> | Draggable selection handles. |
| <code>widgets/reader_side_panel.dart</code> | Outline and extract side panel, including section editing. |
| <code>widgets/extract_highlights.dart</code> | Converts extract provenance into visible source highlights. |

Reader text edits deliberately do not read or write a due date, priority,
review log, or scheduler event. Improving Markdown is not evidence about
learning.

### Extract — independent passages and card formulation

An extract is created from a verified selection, not by cutting source text.
It receives its own topic schedule and priority while retaining a precise link
back to its parent.

| File | Role |
| --- | --- |
| <code>extract_screen.dart</code> | Scheduled/browse processing surface for one extract. |
| <code>extract_view_model.dart</code> | Loads extract state and starts scheduled actions. |
| <code>extract_commands.dart</code> | Create, undo a just-created extract, and edit extract text. |
| <code>extract_command_runner.dart</code> | Verifies selection hash/provenance, creates independent extract state, undo, and text refinement. |
| <code>extract_providers.dart</code> | Wires extract and formulation runners. |
| <code>extract_context_overlay.dart</code> | Shows surrounding source context in browse mode without affecting schedule or position. |
| <code>formulation_dialog.dart</code> | Batch UI for Q&A, cloze, and cloze-overlapper drafts. |
| <code>formulation_commands.dart</code> | Parent-agnostic card drafts and formulate request. |
| <code>formulation_command_runner.dart</code> | Creates cards plus new FSRS state, search documents, and corresponding histories in one transaction. |

### Video — incremental processing of external media

Video playback is intentionally external. The app creates supported
timestamped links (currently YouTube is known; unknown platforms are honest
about requiring a manual seek) and stores only user-entered metadata.

| File | Role |
| --- | --- |
| <code>video_screen.dart</code> | Timeline-like processing surface, note editing, resume time, clips, open-link action, scheduled/browse modes. |
| <code>video_view_model.dart</code> | One range’s state and actions. |
| <code>video_commands.dart</code> | Import video, cut clip, move resume time, edit element. |
| <code>video_command_runner.dart</code> | Reuses one video row per URL, creates independently scheduled ranges, and uses SM-20 media extraction for clips. |
| <code>video_providers.dart</code> | Wires the runner. |
| <code>import_video_sheet.dart</code> | Video URL/metadata import dialog. |
| <code>video_clip_dialog.dart</code> | Validates a child clip inside the parent range. |

The reusable document-side helpers are <code>documents/video.dart</code>,
<code>video_time.dart</code>, and <code>video_link.dart</code>.

### Review — reveal, grade, postpone, and edit

| File | Role |
| --- | --- |
| <code>review_screen.dart</code> | Reveal-first card UI, ratings, inline editing, leech notice, context navigation, and occlusion display. |
| <code>review_view_model.dart</code> | Per-card reveal/grade state. |
| <code>review_commands.dart</code> | Review, edit card, and postpone card requests. |
| <code>review_command_runner.dart</code> | Exactly-once FSRS review transition, card editing, postpone, history writes, and sibling burying. |
| <code>review_providers.dart</code> | Wires the runner. |

Reviewing a card can change FSRS memory and may bury sibling cards from the
same parent so one cloze does not reveal another. Editing a card only changes
content; it is not a review. There is currently no standalone review-undo
command; do not infer one from the generic undo event types retained in the
scheduling history model.

### Image occlusion

| File | Role |
| --- | --- |
| <code>occlusion_screen.dart</code> | Imports/pastes an image, draws regions, creates cards, and reopens an existing occlusion for editing. |
| <code>occlusion_commands.dart</code> | Create card(s) from regions or replace an existing occlusion configuration. |
| <code>occlusion_command_runner.dart</code> | Saves content-addressed image bytes and card/mask/schedule/search state transactionally. |
| <code>occlusion_providers.dart</code> | Wires the runner. |
| <code>widgets/occlusion_canvas.dart</code> | Interactive normalized rectangle editor. |
| <code>widgets/occlusion_view.dart</code> | Read-only image renderer that applies masks for question/answer side. |

One region normally creates one card; “hide all, guess all” instead makes one
card for the complete set. Region geometry is stored as fractions of image
dimensions, not screen pixels.

### Daily queue — the study session and backlog control

| File | Role |
| --- | --- |
| <code>queue_screen.dart</code> | Home screen, queue UI, destinations, stage prompts, Smart Postpone/Mercy dialogs, and launching the correct study surface. |
| <code>queue_view_model.dart</code> | Loads/refreshes queue projections and executes queue actions. |
| <code>queue_query.dart</code> | Read-only projection of today’s queue, counters, and row metadata. |
| <code>queue_commands.dart</code> | Daily admission, stages, drill cutting, randomization, Smart Postpone, and Mercy requests. |
| <code>queue_command_runner.dart</code> | Persists daily admission, Outstanding/Pending/Final Drill state, manual queue commands, and Smart Postpone. |
| <code>mercy_command_runner.dart</code> | Durable preview, apply, stale validation, and exact undo of Mercy batches. |
| <code>smart_postpone_dialog.dart</code> | Preview/confirmation UI for Smart Postpone. |
| <code>study_screen_outcome.dart</code> | Distinguishes a terminal study action from route cancellation. |
| <code>queue_providers.dart</code> | Wires queue query, queue runner, and Mercy runner. |

### Priority — one element slider and collection-wide learning commands

| File | Role |
| --- | --- |
| <code>priority_dialog.dart</code> | Relative-priority slider dialog for one element. |
| <code>priority_view_model.dart</code> | State for the slider and Priority Browser controls. |
| <code>priority_commands.dart</code> | Set rank, percentile, neighbouring order, and batch priority requests. |
| <code>priority_command_runner.dart</code> | Creates relative priority keys and saves schedule/history changes. |
| <code>priority_query.dart</code> | Reads priority rows, positions, contexts, and branches. |
| <code>priority_browser_screen.dart</code> | Collection-wide sortable/filterable priority table with multi-selection and dialogs. |
| <code>priority_browser_commands.dart</code> | Selection commands such as remember, forget, dismiss, done, stages, history reset, A-factor adjustment, and Advance. |
| <code>priority_browser_command_runner.dart</code> | Applies the command group in transactions across selected elements. |
| <code>learning_commands.dart</code> | UI-facing command vocabulary and answer helpers. |
| <code>learning_command_menu.dart</code> | Menu/dialog controls for the learning command group. |
| <code>priority_providers.dart</code> | Wires queries and runners. |

### Search

| File | Role |
| --- | --- |
| <code>search_screen.dart</code> | Search input, type filter, keyboard shortcut, and result routing. |
| <code>search_query.dart</code> | Escapes user prose into safe FTS5 matching syntax, decorates hits with schedule/effective due data. |
| <code>search_providers.dart</code> | Wires the query. |

Sources index their complete Markdown, so a passage can be found before it has
been extracted. Search is read-only.

### Settings, Diagnostics, and Recovery

| Feature | Files | Responsibility |
| --- | --- | --- |
| Settings | <code>settings_screen.dart</code>, <code>settings_view_model.dart</code>, <code>settings_controls.dart</code>, <code>fsrs_settings_rescheduler.dart</code> | Draft/edit/save settings, reusable controls, maintenance/check actions, FSRS replay/reschedule workflow |
| Diagnostics | <code>diagnostics_screen.dart</code>, <code>diagnostics_query.dart</code>, <code>scheduler_metrics_query.dart</code>, <code>diagnostics_providers.dart</code> | Explain scheduler decisions, recent commands, collection state, and derived pacing/retention/future-load metrics; it never steers scheduling |
| Recovery | <code>recovery_screen.dart</code> | Minimal app shell that lists/restores verified backups before the normal provider graph exists |

## Shared library reference

| File | Why it exists |
| --- | --- |
| <code>shared/clock.dart</code> | <code>Clock</code>, <code>SystemClock</code>, and testable <code>FakeClock</code>. |
| <code>shared/id_generator.dart</code> | UUID production IDs and predictable test IDs. |
| <code>shared/operation_id.dart</code> | Typed correlation ID for one user action. |
| <code>shared/result.dart</code> | Typed success/failure boundary and named failure classes. |
| <code>shared/command_base.dart</code> | Common immutable command base with operation ID and timestamp. |
| <code>shared/command_execution.dart</code> | Shared transaction/idempotency/generation/diagnostic command boundary. |
| <code>shared/diagnostics_sink.dart</code> | Diagnostic event model and no-op/test sinks. |
| <code>shared/in_memory_diagnostic_sink.dart</code> | Bounded newest-first diagnostics buffer for the panel. |
| <code>shared/fan_out_diagnostic_sink.dart</code> | Sends a diagnostic event to multiple sinks. |
| <code>shared/utf8_offsets.dart</code> | Exact UTF-8-byte ↔ Dart UTF-16 index conversion. |
| <code>shared/text_excerpt.dart</code> | One-line whitespace-normalized bounded list preview. |
| <code>shared/ui/app_theme.dart</code> | Material theme, palette, and reader typography model. |
| <code>shared/ui/screen_width.dart</code> | Central compact-versus-wide layout decision and responsive dialog width. |
| <code>shared/ui/desktop_scroll_view.dart</code> | Keyboard-scrollable list with explicit desktop scrollbar. |
| <code>shared/ui/element_type_badge.dart</code> | One icon/colour/label vocabulary for mixed element lists. |
| <code>shared/ui/status_pill.dart</code> | Compact shared status label. |
| <code>shared/ui/toast_message.dart</code> | One self-dismissing overlay toast at a time. |
| <code>shared/ui/video_thumbnail.dart</code> | Best-effort remote/data-URI video preview that fails quietly. |

## Documents library reference

| File | Why it exists |
| --- | --- |
| <code>documents/source.dart</code> | Source, resume marker, soft position, normalization/hash/word count. |
| <code>documents/document.dart</code> | Parsed source Markdown at a particular content revision. |
| <code>documents/block.dart</code> | Block type, raw source coordinates, rendered mapping helpers. |
| <code>documents/block_content.dart</code> | Raw/content span representation with syntax removed. |
| <code>documents/markdown_block_parser.dart</code> | Deterministic block parser and line-ending normalization. |
| <code>documents/markdown_inline_parser.dart</code> | Inline parser that preserves source/rendered correspondence. |
| <code>documents/inline_markup.dart</code> | Inline styles, segments, and layout mapping types. |
| <code>documents/reader_anchor.dart</code> | Revision-stamped UTF-8 anchors and selection ranges. |
| <code>documents/reader_coordinates.dart</code> | The single conversion path between rendered selection and persisted offsets. |
| <code>documents/text_splice.dart</code> | Validated exact source text replacement. |
| <code>documents/position_migration.dart</code> | Deterministic movement of positions/ranges across a splice. |
| <code>documents/apply_source_edit.dart</code> | Pure source-edit result, child provenance migration, and edit-result variants. |
| <code>documents/source_edit.dart</code> | Append-only edit-journal record and undo restoration snapshots. |
| <code>documents/block_edit.dart</code> | Block edit/remove/insert/section-swap splice construction. |
| <code>documents/outline.dart</code> | Heading hierarchy and exact section ownership. |
| <code>documents/extract.dart</code> | Extract and provenance model, including stale/orphaned state. |
| <code>documents/card.dart</code> | Card model, cloze parsing/rendering, and card-parent model. |
| <code>documents/occlusion.dart</code> | Normalized occlusion regions, modes, JSON decoding, and review-side coverage. |
| <code>documents/source_asset.dart</code> | Markdown image reference metadata and state. |
| <code>documents/video.dart</code> | Video/video-element models and uncovered-range calculation. |
| <code>documents/video_time.dart</code> | Human video-time parsing and formatting. |
| <code>documents/video_link.dart</code> | Platform detection and truthful timestamped-link construction. |

## Scheduling library reference

| File | Why it exists |
| --- | --- |
| <code>scheduling/element.dart</code> | Common element identity, lifecycle, schedule, and due provenance. |
| <code>scheduling/study_day.dart</code> | Named-zone study-day model, rollover, and DST-safe boundaries. |
| <code>scheduling/priority_rank.dart</code> | Relative order-key generation and current collection priority scale. |
| <code>scheduling/scheduling_context.dart</code> | Factory for live settings, calendar, schedulers, priority scale, and runtime state. |
| <code>scheduling/effective_due_query.dart</code> | One adjustment-aware answer to “when is this element due?” |
| <code>scheduling/sm20_numeric.dart</code> | Delphi Real48, rounding, global PRNG, spread, and heap sort compatibility. |
| <code>scheduling/sm20_collection_state.dart</code> | Persistable collection-wide SM-20 queues and timestamps. |
| <code>scheduling/sm20_runtime_store.dart</code> | Versioned settings-row codec for SM-20 runtime state. |
| <code>scheduling/topics/topic_scheduler.dart</code> | SM-20 topic state machine and extraction/rescheduling primitives. |
| <code>scheduling/cards/card_scheduler.dart</code> | FSRS-compatible card state, review transition, reschedule and leech logic. |
| <code>scheduling/cards/fsrs_memory_recomputer.dart</code> | Replays genuine reviews under a changed parameter vector. |
| <code>scheduling/daily_queue/queue_policy.dart</code> | Outstanding candidate scoring, randomization, merge, and stage plan. |
| <code>scheduling/postpone/sm20_postpone.dart</code> | Smart Postpone and automatic-postpone candidate selection/decision mathematics. |
| <code>scheduling/postpone/sm20_advance.dart</code> | Exact Advance candidate selection and random draw order. |
| <code>scheduling/mercy/mercy.dart</code> | Mercy matrix, score, gathering, ordering, redistribution, and capacity planning. |
| <code>scheduling/mercy/mercy_workflow.dart</code> | Durable Mercy preview/apply/undo representations and codecs. |
| <code>scheduling/history/review_log.dart</code> | Universal scheduling log event types, snapshots, and entries. |
| <code>scheduling/history/scheduler_event.dart</code> | Rich scheduler audit event type and due encoding. |
| <code>scheduling/history/scheduling_journal.dart</code> | Consistent construction/appending of review-log and scheduler-event records. |
| <code>scheduling/metrics/scheduler_metrics.dart</code> | Pure calculation of pacing, distribution, priority, workload, and topic-policy metrics. |

## Settings library reference

| File | Why it exists |
| --- | --- |
| <code>settings/app_settings.dart</code> | Composes every settings group and owns resilient flat-map decoding/encoding. |
| <code>settings/settings_store.dart</code> | Cached read/save façade over raw settings rows. |
| <code>settings/study_day_settings.dart</code> | Timezone and rollover fields. |
| <code>settings/queue_settings.dart</code> | Queue ordering/stage controls. |
| <code>settings/remember_settings.dart</code> | Initial topic interval settings. |
| <code>settings/card_settings.dart</code> | FSRS and recall-card settings. |
| <code>settings/postpone_settings.dart</code> | Auto-postpone toggle, named profile registry, and branch assignments. |
| <code>settings/smart_postpone_settings.dart</code> | One Smart Postpone profile and its scope/threshold rules. |
| <code>settings/mercy_settings.dart</code> | Mercy configuration and optional matrix. |
| <code>settings/diagnostics_settings.dart</code> | Diagnostics log/panel configuration. |
| <code>settings/settings_list_equality.dart</code> | Content equality helpers for list-shaped settings. |

## Storage library reference

| File | Why it exists |
| --- | --- |
| <code>storage/contracts/content_repository.dart</code> | Storage promise for sources, documents, edits, extracts, and cards. |
| <code>storage/contracts/video_repository.dart</code> | Storage promise for videos and ranges. |
| <code>storage/contracts/learning_repository.dart</code> | Storage promise for schedules, state, priority, logs, activity, and Mercy. |
| <code>storage/contracts/source_asset_repository.dart</code> | Source image-reference metadata storage promise. |
| <code>storage/contracts/occlusion_repository.dart</code> | Card occlusion metadata storage promise. |
| <code>storage/contracts/search_repository.dart</code> | Materialized FTS document/search promise. |
| <code>storage/contracts/settings_repository.dart</code> | Raw string key/value storage promise. |
| <code>storage/contracts/transfer_repository.dart</code> | Dataset identity/generation storage promise. |
| <code>storage/contracts/transaction_runner.dart</code> | Atomic transaction interface. |
| <code>storage/contracts/database_maintenance.dart</code> | Maintenance report and interface. |
| <code>storage/contracts/database_check.dart</code> | Integrity-check report and interface. |
| <code>storage/database/tables.dart</code> | Drift table definitions, constraints, and frozen column warnings. |
| <code>storage/database/app_database.dart</code> | Schema v17, migrations, indexes, FTS5 triggers, health helpers. |
| <code>storage/database/connection.dart</code> | Live local-file and in-memory test database opening policy. |
| <code>storage/database/row_converters.dart</code> | Domain ↔ Drift row conversion and safe persisted-JSON decoding. |
| <code>storage/drift/drift_content_repository.dart</code> | Drift implementation of content storage, including source edit and block rebuild. |
| <code>storage/drift/drift_video_repository.dart</code> | Drift implementation for video/range storage. |
| <code>storage/drift/drift_learning_repository.dart</code> | Drift implementation for schedules, states, history, queue facts, and activity. |
| <code>storage/drift/drift_source_asset_repository.dart</code> | Drift implementation for source asset metadata. |
| <code>storage/drift/drift_occlusion_repository.dart</code> | Drift implementation for occlusion metadata. |
| <code>storage/drift/drift_search_repository.dart</code> | Drift implementation for FTS5 materialized content/search. |
| <code>storage/drift/drift_settings_repository.dart</code> | Drift implementation for settings rows. |
| <code>storage/drift/drift_transfer_repository.dart</code> | Drift implementation for dataset identity/generation. |
| <code>storage/drift/drift_transaction_runner.dart</code> | Drift transaction implementation. |
| <code>storage/drift/drift_database_maintenance.dart</code> | FTS repair/checkpoint/VACUUM/ANALYZE implementation. |
| <code>storage/drift/drift_database_check.dart</code> | Atomic logical-integrity repair implementation. |
| <code>storage/files/source_asset_file_store.dart</code> | Content-addressed asset bytes, validation, cleanup, and staging handling. |
| <code>storage/files/backup_service.dart</code> | Backup creation, validation, retention, and pre-migration backups. |
| <code>storage/files/backup_restore_service.dart</code> | Cold backup validation and safe file promotion/rollback. |
| <code>storage/files/rotating_log_sink.dart</code> | Durable bounded structured diagnostic log. |
| <code>storage/platform/app_paths.dart</code> | Platform-local root/database/backup/asset/log paths. |
| <code>storage/platform/time_zones.dart</code> | Pinned IANA timezone rules and Windows-to-IANA aliases. |
| <code>storage/dataset_lineage.dart</code> | Dataset ownership, writer epoch, and generation value object. |

## External dependencies and their boundaries

| Dependency | Used for | Kept out of |
| --- | --- | --- |
| Flutter / Material | Screens and reusable UI | Documents, scheduling, settings |
| flutter_riverpod | Object wiring and view-model state | Pure domain rules |
| Drift / SQLite | Local relational persistence and FTS5 | Screens and scheduling mathematics |
| fsrs_dart | FSRS algorithm adapter | Stored/public card model |
| markdown | Markdown support used by parsing/rendering support | Scheduling |
| timezone | Pinned named-zone offsets | Scheduling’s injected timezone interface |
| uuid | Production entity IDs | Tests through <code>FakeIdGenerator</code> |
| crypto | SHA-256 content/provenance/blob hashes | UI |
| archive | Portable backup packages | Normal storage contracts |
| file_selector / super_clipboard | Native file and image input | Core document model |
| url_launcher | Open a video externally | Video domain rules |

## Tests: the executable specification

Read tests as documentation, especially before changing scheduling or storage.

| Area | Where to look first |
| --- | --- |
| Layering rules | <code>test/architecture/folder_rules_test.dart</code> |
| Startup/recovery | <code>test/app/startup_gate_test.dart</code>, <code>test/workflows/daylight_saving_and_recovery_test.dart</code> |
| Markdown, UTF-8, edits, outline | <code>test/documents/</code> and <code>test/features/reader/</code> |
| SM-20 numerical compatibility | <code>test/scheduling/sm20_numeric_test.dart</code>, <code>test/scheduling/sm20_collection_fixture_test.dart</code> |
| Topic, card, queue, postpone, Mercy logic | <code>test/scheduling/</code> |
| Feature command runners and widgets | <code>test/features/</code> |
| Schema, migrations, backup, restore, repair | <code>test/storage/</code> |
| End-to-end workflows | <code>test/workflows/</code> and <code>integration_test/</code> |

Important integration examples:

- <code>integration_test/import_read_extract_undo_test.dart</code>
- <code>integration_test/extract_to_card_review_loop_test.dart</code>
- <code>integration_test/editor_smoke_test.dart</code>
- <code>integration_test/priority_caps_and_overload_valve_test.dart</code>

Before declaring a code change complete, the project rules require:

    dart analyze
    flutter test

Run only the formatter on files you personally changed. For a documentation-only
change, a whitespace check such as <code>git diff --check</code> is the
relevant lightweight verification.

## Practical repair and change playbook

### First question: which layer owns the rule?

| You want to change… | Start here |
| --- | --- |
| A button, visual layout, dialog, or navigation | The corresponding <code>features/&lt;name&gt;/</code> screen/widget |
| Screen state / loading / feedback | That feature’s view model |
| A new user mutation | Add a command and runner method in that feature |
| What a screen displays | That feature’s query |
| Markdown parsing, selection, provenance, or text edit | <code>documents/</code> and Reader tests |
| Due dates, queues, postpone, priority, SM-20/FSRS math | <code>scheduling/</code> with focused unit tests |
| A user setting/default | Settings group + <code>app_settings.dart</code> + Settings UI |
| A persisted row, SQL query, backup, or schema | Storage contracts/Drift/database |
| A globally shared implementation choice | <code>app/providers.dart</code> |

### When something breaks

1. Reproduce with the smallest relevant test or a minimal manual sequence.
2. Find the visible feature and identify whether the issue is a query
   (read-only), command runner (application workflow), pure domain rule, or
   persistence conversion.
3. Inspect the corresponding diagnostic event, activity row, repetition log,
   or scheduler event. The Diagnostics screen is designed to answer “why did
   this schedule change?”
4. For a due-date issue, freeze the clock/zone/random seed in a unit test.
   Do not debug by repeatedly clicking a live collection.
5. For an editing issue, inspect UTF-8 offsets, content revision, and
   <code>SourceEdit</code> journal entries before changing a migration rule.
6. For a storage issue, run integrity/maintenance tools or restore a verified
   backup. Never hand-edit the SQLite file while the app is open.

### Red flags

- A screen imports <code>storage/drift/</code> or <code>storage/database/</code>.
- A query writes data.
- A scheduler imports Flutter or calls <code>DateTime.now()</code>.
- A command generates a new operation ID halfway through its work.
- A text edit is implemented by diffing entire documents.
- A migration renames storage strings without a compatibility plan.
- A postpone is recorded as a review.
- A data-loss “fix” bypasses the Browser’s confirmation/repository order.

## Suggested incremental study path

| Session | Read | Goal |
| --- | --- | --- |
| 1 | <code>lib/README.md</code>, this overview, <code>main.dart</code> | Know the folders and startup sequence. |
| 2 | <code>app/providers.dart</code>, <code>shared/result.dart</code>, <code>shared/command_execution.dart</code> | Understand construction, failures, transactions, and idempotency. |
| 3 | <code>documents/source.dart</code>, <code>document.dart</code>, <code>block.dart</code>, <code>reader_anchor.dart</code> | Learn the content and coordinate model. |
| 4 | <code>text_splice.dart</code>, <code>position_migration.dart</code>, <code>apply_source_edit.dart</code>, their tests | Understand the safest and hardest editing path. |
| 5 | <code>scheduling/element.dart</code>, <code>study_day.dart</code>, <code>priority_rank.dart</code> | Learn shared schedule vocabulary. |
| 6 | <code>topics/topic_scheduler.dart</code> and SM-20 tests | Learn source/extract/video scheduling before the UI. |
| 7 | <code>cards/card_scheduler.dart</code>, <code>review_command_runner.dart</code>, review tests | Learn FSRS review lifecycle. |
| 8 | <code>daily_queue/queue_policy.dart</code>, queue query/runner | Learn how today's work is built. |
| 9 | <code>reader_view_model.dart</code>, reader command runner, Reader screen | Trace a real feature end to end. |
| 10 | Extract/formulation, Browser tree, and Priority modules | Learn relationships, navigation, filing, and bulk commands. |
| 11 | <code>tables.dart</code>, one storage contract, matching Drift repository, converters | Learn persistence without changing it. |
| 12 | Backups, recovery, database checks, migrations, and workflow tests | Learn how to preserve user data while repairing the app. |

## Final ownership rules

This codebase is intentionally conservative around user data. Prefer a named
pure function, a test, and a small command over a clever shortcut. Preserve
the distinctions between content, provenance, filing, schedule, and history.
If you keep those distinctions intact, the project remains navigable even as
it grows.
