# Incremental Reader — Repository Guide for a File-Blind LLM

> Audience: a conversational LLM that cannot inspect this repository. The user
> should attach this document first. Use it to decide which *complete source
> files* to request next, in small evidence-driven batches. Do not guess that a
> file exists: the authoritative path inventory is in this document.

## Mission

Your job is to diagnose or design a change without direct filesystem access.
This guide gives you enough architecture to ask the user for the right files.
It does not contain the implementation itself. Never propose a final patch for
an unseen file. First request the smallest coherent packet, read it, and then
request the next dependency only if the evidence requires it.

The repository is a Flutter/Dart, local-first incremental-reading application.
Its application code is under `lib/`; tests are under `test/` and
`integration_test/`; a vendored FSRS package is under `fsrs-dart/`. There is no
server, network API, authentication layer, or remote database. SQLite through
Drift is the authoritative collection store. Image bytes and backups are local
files.

## Instructions to the LLM

### Start every bug conversation this way

Ask the user for:

1. The exact symptom and what they expected instead.
2. A minimal numbered reproduction from a fresh app launch.
3. Whether it happens before or after restarting the app.
4. The full error/stack trace as text, including the first application frame.
5. Platform and command used: Windows/Android/etc., debug/release, and whether
   the failure comes from `dart analyze`, `flutter test`, build, startup, or a
   user interaction.
6. Any recent diff touching the suspected files. Prefer `git diff -- <paths>`.
7. The initial file packet selected from the routing tables below.

Request whole files with their paths. Do not ask for screenshots of code,
isolated methods, or line fragments: imports, private helpers, switch exhaustiveness,
and types elsewhere in the file are often decisive. Ask the user to replace
personal Markdown/card text with equivalent synthetic text if content matters.

### Use staged disclosure

- **Packet 0 — evidence:** reproduction, output, stack trace, environment, and
  recent diff. This document has already supplied the repository map.
- **Packet 1 — owning path:** UI/view model/query for a display problem, or
  commands/runner/domain rule for a mutation problem, plus its closest test.
- **Packet 2 — boundary:** the storage contract and concrete Drift repository
  when data is read, written, missing after restart, duplicated, or malformed.
- **Packet 3 — substrate:** table definitions, converters, migrations,
  composition providers, or shared command execution only when Packet 1 or the
  stack trace crosses that boundary.
- **Packet 4 — generated/vendor/platform:** generated Drift code, vendored FSRS
  internals, plugin/build files, or platform runners only when the failure is
  demonstrably there.

Do not request all of `lib/` by default. A coherent 4–10 file packet is easier
to reason about than a repository dump and is less likely to exceed context.

### Classify the failure before selecting files

| Observation | Primary owner | First file shape |
| --- | --- | --- |
| Wrong pixels, layout, focus, scrolling, dialog, or navigation | Presentation | `lib/features/<feature>/*_screen.dart` or `widgets/*.dart` |
| Screen remains loading, shows stale state, or reports the wrong message | State orchestration | feature `*_view_model.dart`, `*_providers.dart`, and query/runner it calls |
| Wrong value is displayed but no write occurred | Read path | feature `*_query.dart`, storage contract, matching Drift repository |
| Tap writes the wrong thing, writes twice, or partly writes | Command path | `*_commands.dart`, `*_command_runner.dart`, domain rule, `shared/command_execution.dart` |
| Pure parsing, coordinate, scheduling, ranking, or date calculation is wrong | Domain | matching file in `documents/` or `scheduling/` plus focused unit test |
| Correct until restart, then wrong/missing | Persistence | contract, Drift repository, `row_converters.dart`, tables/schema if needed |
| Only old collections fail | Migration/compatibility | `app_database.dart`, `tables.dart`, startup gate, relevant migration test |
| Provider missing, wrong concrete object, or dependency differs in tests | Composition | feature provider, `lib/app/providers.dart`, test harness |
| Compiler mentions a generated Drift symbol | Code generation | source table/database file first; generated `.g.dart` only as evidence |
| Platform plugin, manifest, linker, or packaging failure | Build/platform | `pubspec.yaml`, lock excerpt, named platform build/manifest file |

### Rules for making a proposed fix

- Preserve the existing layer direction. UI may use contracts but must not
  import `storage/drift/` or `storage/database/`.
- Queries are read-only. Mutations belong in feature command runners and use a
  transaction.
- Domain code receives time; it must not call `DateTime.now()` directly.
- One user action carries one `OperationId` through command, activity, review,
  edit journal, and scheduler events.
- Do not generate a second operation ID inside an operation.
- Do not replace an exact source splice with a whole-document diff.
- Do not conflate provenance, Browser filing, schedule, or content ownership.
- Do not hand-edit SQLite, generated Drift code, or immutable image blobs.
- Do not rename stored enum ordinals, persisted strings, or settings keys
  without a migration/compatibility plan.
- A source edit must not change due dates or create a review.
- Postponement must not be logged as a genuine review.
- Permanent deletion stays in the Browser flow and requires confirmation.
- Any storage/schema fix must account for existing user collections and backup
  recovery, not only a new in-memory database.

## System model

Incremental Reader manages four scheduled element types:

| Element | Content | Scheduler |
| --- | --- | --- |
| Source | Imported Markdown plus reading anchors | SM-20 topic scheduling |
| Extract | Copied passage with provenance | SM-20 topic scheduling |
| Card | Q&A, cloze, overlapper, or image occlusion | FSRS card scheduling |
| Video element | Whole video or selected time range | SM-20 topic scheduling |

A `Video` record holds URL metadata but is not itself scheduled. A
`VideoElement` is the scheduled range.

Three relationships are deliberately independent:

| Relationship | Authority |
| --- | --- |
| Content origin/provenance | `Extract` provenance and `Card` content parent |
| User-visible Browser filing | `ElementSchedule.parentElementId` and `ordinal` |
| Return time and learning state | `ElementSchedule`, `TopicState`, or `CardMemory` |

Moving an element in the Browser must not alter provenance. Editing content
must not alter scheduling. Dismissing is reversible lifecycle state; Browser
permanent deletion is physical erasure.

### Layer direction

```text
lib/main.dart
  -> lib/app/                 composition and startup
     -> lib/features/        screens, state, commands, queries
        -> lib/documents/    content rules (pure Dart)
        -> lib/scheduling/   learning rules (pure Dart plus contracts)
        -> lib/settings/     typed settings
        -> lib/storage/contracts/
     -> lib/storage/drift/ and database/   concrete persistence
     -> lib/storage/files/ and platform/   local filesystem/platform

lib/shared/                  foundational values; no app-layer dependency
lib/shared/ui/               reusable Flutter presentation
```

`test/architecture/folder_rules_test.dart` is the executable authority for
these boundaries.

### Standard feature vocabulary

| Suffix | Meaning |
| --- | --- |
| `_screen.dart` | Widgets, routes, dialogs, local visual state |
| `_view_model.dart` | Async screen state and user-intent orchestration |
| `_commands.dart` | Immutable request values; no persistence |
| `_command_runner.dart` | Validation, domain calls, and atomic persistence |
| `_query.dart` | Read projection; never writes |
| `_providers.dart` | Riverpod construction only |
| `widgets/` | Feature-local presentation pieces |

### Shared mutation boundary

Most writes pass through `lib/shared/command_execution.dart`. It centralizes
transaction execution, duplicate-operation detection/replay, dataset-generation
advance, and structured diagnostics. `lib/shared/result.dart` represents
expected validation/not-found/conflict/storage/unexpected failures. Concrete
repositories do not create independent business-policy transactions; the
command runner owns the atomic unit.

## Canonical runtime flows

Use these chains to locate the first incorrect transition. Files earlier in a
chain express UI intent; middle files own policy; later files persist it.

### Startup and recovery

```text
lib/main.dart
 -> lib/storage/platform/app_paths.dart
 -> lib/app/startup_gate.dart
 -> lib/storage/database/connection.dart
 -> lib/storage/database/app_database.dart
 -> lib/app/providers.dart
 -> lib/app/startup_tasks.dart
 -> lib/app/incremental_reader_app.dart
 -> lib/features/daily_queue/queue_screen.dart
```

If database opening/classification fails, normal providers are not created:

```text
lib/main.dart
 -> lib/app/startup_gate.dart
 -> lib/features/recovery/recovery_screen.dart
 -> lib/storage/files/backup_restore_service.dart
 -> lib/storage/files/backup_service.dart
```

### Load today's queue

```text
queue_screen.dart -> queue_view_model.dart -> queue_query.dart
 -> scheduling_context.dart + queue_policy.dart + priority_rank.dart
 -> content_repository.dart + video_repository.dart + learning_repository.dart
 -> matching drift repositories
```

### Import and read a Markdown source

```text
add_element_flow.dart/import_sheet.dart
 -> reader_commands.dart (ImportSource)
 -> reader_command_runner.dart
 -> source.dart + markdown_block_parser.dart
 -> content_repository.dart + learning_repository.dart + search_repository.dart
 -> Drift implementations
 -> reader_view_model.dart -> reader_screen.dart -> widgets/reader_view.dart
```

### Render Markdown and select text

```text
markdown_block_parser.dart -> document.dart/block.dart/block_content.dart
 -> markdown_inline_parser.dart/inline_markup.dart
 -> block_span_builder.dart -> block_view.dart -> reader_view.dart

reader_selection.dart -> reader_coordinates.dart -> reader_anchor.dart
 -> shared/utf8_offsets.dart
```

### Edit source text, move a section, or undo an edit

```text
block_editor.dart or reader_side_panel.dart
 -> reader_view_model.dart
 -> reader_commands.dart
 -> reader_command_runner.dart
 -> block_edit.dart + text_splice.dart + apply_source_edit.dart
 -> position_migration.dart + outline.dart (section moves)
 -> content_repository.dart
 -> drift_content_repository.dart
 -> source_edit.dart journal + rebuilt derived Blocks
```

### Create an extract

```text
selection_toolbar.dart/reader_screen.dart
 -> reader_view_model.dart
 -> extract_commands.dart (CreateExtract)
 -> extract_command_runner.dart
 -> reader_coordinates.dart + extract.dart + topic_scheduler.dart
 -> content_repository.dart + learning_repository.dart + search_repository.dart
 -> Drift implementations
```

The selected-text hash and revision-stamped provenance are validated before
creation. Source text is copied, never cut.

### Formulate cards

```text
formulation_dialog.dart -> formulation_commands.dart
 -> formulation_command_runner.dart
 -> documents/card.dart + cards/card_scheduler.dart
 -> content_repository.dart + learning_repository.dart + search_repository.dart
 -> Drift implementations
```

### Review or edit a card

```text
review_screen.dart -> review_view_model.dart -> review_commands.dart
 -> review_command_runner.dart -> cards/card_scheduler.dart
 -> scheduling_journal.dart/review_log.dart/scheduler_event.dart
 -> content_repository.dart + learning_repository.dart -> Drift implementations
```

Review supports reveal/grade, content edit, card postpone, leech handling, and
sibling burying. There is currently no standalone `UndoReview` command.

### Import/process a video and make a clip

```text
import_video_sheet.dart/video_clip_dialog.dart/video_screen.dart
 -> video_view_model.dart -> video_commands.dart
 -> video_command_runner.dart
 -> documents/video.dart + video_time.dart + video_link.dart
 -> topic_scheduler.dart
 -> video_repository.dart + learning_repository.dart + search_repository.dart
 -> Drift implementations
```

Playback is external through a timestamped URL; there is no embedded player.

### Create/edit image occlusion

```text
occlusion_screen.dart/occlusion_canvas.dart
 -> occlusion_commands.dart -> occlusion_command_runner.dart
 -> documents/occlusion.dart
 -> source_asset_file_store.dart
 -> occlusion_repository.dart + content_repository.dart
    + learning_repository.dart + search_repository.dart
 -> Drift implementations
```

Review display uses `features/occlusion/widgets/occlusion_view.dart`.

### Move/file/delete Browser elements

```text
browser_screen.dart -> browser_view_model.dart -> browser_commands.dart
 -> browser_command_runner.dart -> browser_tree_query.dart
 -> content/video/learning/search contracts -> Drift implementations
```

Filing changes only schedule parent/ordinal. Permanent subtree deletion is
ordered for foreign keys and also clears necessary queue/search state.

### Change priority or apply bulk learning commands

```text
priority_dialog.dart/priority_browser_screen.dart
 -> priority_view_model.dart
 -> priority_commands.dart + priority_command_runner.dart
    OR priority_browser_commands.dart + priority_browser_command_runner.dart
 -> priority_rank.dart + topic/card/queue domain state
 -> learning_repository.dart -> drift_learning_repository.dart
```

### Daily admission, stages, Smart Postpone, and Mercy

```text
queue_screen.dart -> queue_view_model.dart -> queue_commands.dart
 -> queue_command_runner.dart
 -> queue_policy.dart + sm20_postpone.dart + scheduling_context.dart
 -> learning_repository.dart

Mercy:
queue_view_model.dart -> mercy_command_runner.dart
 -> mercy.dart + mercy_workflow.dart
 -> topic/card schedulers + learning_repository.dart
```

Mercy preview/apply/undo is durable and compare-and-swap protected. Smart
Postpone and Mercy are different workflows and should not share guessed logic.

### Save settings and reschedule FSRS

```text
settings_screen.dart -> settings_view_model.dart
 -> settings_store.dart -> settings_repository.dart
 -> drift_settings_repository.dart

FSRS-sensitive change:
settings_view_model.dart -> fsrs_settings_rescheduler.dart
 -> fsrs_memory_recomputer.dart + card_scheduler.dart
 -> learning_repository.dart in one transaction
```

### Search

```text
search_screen.dart -> search_query.dart
 -> search_repository.dart + learning_repository.dart
 -> drift_search_repository.dart + drift_learning_repository.dart
 -> app_database.dart FTS5 support
```

Search materialization is written by feature command runners when content is
created/edited; the search query itself is read-only.

## Symptom-to-file packet router

In every row, also request the closest named test and the full error output.
“Escalate” means ask only if the initial files or stack trace point there.

### Startup, database, files, and recovery

| Symptom | Initial packet | Escalate with |
| --- | --- | --- |
| App fails before first screen | `lib/main.dart`, `lib/app/startup_gate.dart`, `lib/storage/database/connection.dart`, `test/app/startup_gate_test.dart` | `lib/storage/platform/app_paths.dart`, `lib/storage/database/app_database.dart`, platform runner/build file |
| Existing collection says newer/unsupported schema | `lib/app/startup_gate.dart`, `lib/storage/database/app_database.dart`, `lib/storage/database/tables.dart`, `test/app/startup_gate_test.dart` | exact SQLite `user_version`; do not send the database by default |
| Migration fails only for older collections | `lib/storage/database/app_database.dart`, `lib/storage/database/tables.dart`, matching `test/storage/v*_migration_test.dart` | `row_converters.dart`, pre-migration schema/error, startup gate |
| Fresh database schema is wrong | `tables.dart`, `app_database.dart`, `test/storage/database_baseline_test.dart` | relevant contract/repository and generated code error only |
| Drift generated symbol is absent/stale | `tables.dart`, `app_database.dart`, `pubspec.yaml`, complete generator/analyzer output | `app_database.g.dart` only if source declarations look correct |
| Data correct until app restart | owning feature runner, relevant contract, matching Drift repository, `row_converters.dart` | `tables.dart`, `app_database.dart`, failing persistence test |
| Database check reports/repairs the wrong thing | `storage/contracts/database_check.dart`, `storage/drift/drift_database_check.dart`, `test/storage/database_check_test.dart` | `tables.dart`, affected repositories/converters |
| Maintenance/FTS rebuild fails | `database_maintenance.dart`, `drift_database_maintenance.dart`, `app_database.dart`, `test/storage/database_maintenance_test.dart` | search contract/repository and SQLite error |
| Backup creation/retention is wrong | `storage/files/backup_service.dart`, `storage/platform/app_paths.dart`, `test/storage/asset_backup_test.dart` | `startup_tasks.dart`, asset file store |
| Restore fails or risks replacing good data | `backup_restore_service.dart`, `backup_service.dart`, `recovery_screen.dart`, `test/storage/backup_restore_test.dart` | `startup_gate.dart`, `app_paths.dart`, workflow recovery test |
| Logs missing, rotate incorrectly, or leak content | `storage/files/rotating_log_sink.dart`, `shared/diagnostics_sink.dart`, `settings/diagnostics_settings.dart` | provider wiring, diagnostics tests/output |
| Image blob missing/corrupt/orphaned | `source_asset_file_store.dart`, appropriate asset/occlusion repository, relevant command runner, `test/storage/source_asset_file_store_test.dart` | backup service, tables, cleanup path in `main.dart` |

### Reader, Markdown, extracts, and cards

| Symptom | Initial packet | Escalate with |
| --- | --- | --- |
| Markdown splits into wrong blocks | `documents/markdown_block_parser.dart`, `document.dart`, `block.dart`, `test/documents/markdown_parsing_test.dart` | `block_content.dart`, exact synthetic Markdown input |
| Bold/link/code/image text renders wrongly | `documents/markdown_inline_parser.dart`, `inline_markup.dart`, `features/reader/widgets/block_span_builder.dart`, parsing test | `block_view.dart`, theme if styling only |
| Reader scrolling/anchor jumps | `features/reader/widgets/reader_view.dart`, `reader_view_model.dart`, `documents/reader_anchor.dart`, `test/features/reader/widgets/reader_view_test.dart` | `reader_coordinates.dart`, `block_span_builder.dart`, screen |
| Text selection/handles/toolbar wrong | `reader_selection.dart`, `selection_knobs.dart`, `selection_toolbar.dart`, `reader_coordinates.dart` | `inline_markup.dart`, `block_span_builder.dart`, relevant widget test |
| Emoji/non-ASCII offsets are wrong | `shared/utf8_offsets.dart`, `documents/reader_coordinates.dart`, `reader_anchor.dart`, `test/shared/utf8_offsets_test.dart` | parser/block model, failing edit or selection test |
| Resume marker or soft position wrong | `reader_view_model.dart`, `reader_commands.dart`, `reader_command_runner.dart`, `documents/source.dart` | content repository/Drift implementation, anchor/coordinate files |
| Block editor inserts/deletes wrong source range | `widgets/block_editor.dart`, `documents/block_edit.dart`, `text_splice.dart`, `reader_command_runner.dart`, editing regression test | `apply_source_edit.dart`, `position_migration.dart`, UTF-8 helper |
| Source edit moves marker/provenance incorrectly | `apply_source_edit.dart`, `position_migration.dart`, `text_splice.dart`, `test/documents/position_migration_test.dart`, `source_editing_test.dart` | `reader_command_runner.dart`, `drift_content_repository.dart`, `source_edit.dart` |
| Move section damages hierarchy/content | `reader_side_panel.dart`, `documents/outline.dart`, `block_edit.dart`, reader command runner, `test/documents/outline_test.dart` | parser and editing regressions |
| Undo source edit is wrong | `reader_commands.dart`, `reader_command_runner.dart`, `documents/source_edit.dart`, `apply_source_edit.dart`, source editing test | content contract/repository and source-edit table definition |
| Imported source missing blocks/search/schedule | `browser/import_sheet.dart`, `reader_commands.dart`, `reader_command_runner.dart`, `markdown_block_parser.dart` | content/learning/search contracts and Drift repositories |
| Source image import/replace/display fails | `reader_image_input.dart`, reader commands/runner, `source_asset.dart`, `source_asset_file_store.dart`, `block_span_builder.dart` | asset repository, platform plugin, reader image tests |
| Extract highlight wrong | `widgets/extract_highlights.dart`, `reader_coordinates.dart`, `documents/extract.dart`, `test/features/reader/widgets/extract_highlights_test.dart` | document/block/inline mapping |
| Extract creation rejected or captures wrong text | `extract_commands.dart`, `extract_command_runner.dart`, `reader_view_model.dart`, `reader_coordinates.dart`, extract runner test | content/learning/search repositories, source revision/edit logic |
| Extract edit or undo-create wrong | extract commands/runner/view model plus `documents/extract.dart` and extract tests | content/search Drift repositories |
| Extract context overlay wrong | `extract_context_overlay.dart`, `extract_screen.dart`, `extract_view_model.dart`, extract screen test | content repository and provenance model |
| Q&A/cloze/overlapper generated wrongly | `formulation_dialog.dart`, `formulation_commands.dart`, `formulation_command_runner.dart`, `documents/card.dart`, formulation test | card scheduler and repositories if state/persistence is wrong |
| Card parent/context navigation wrong | `documents/card.dart`, `review_screen.dart`, `browser/open_element.dart`, relevant query | content repository/Drift content repository |

### Review, scheduling, dates, and queue

| Symptom | Initial packet | Escalate with |
| --- | --- | --- |
| Review reveal/rating controls wrong | `review_screen.dart`, `review_view_model.dart`, `review_commands.dart`, review UI tests | runner if persisted result is wrong |
| Card due date/memory wrong after rating | `review_command_runner.dart`, `scheduling/cards/card_scheduler.dart`, `settings/card_settings.dart`, scheduler and runner tests | learning contract/repository, journal/history, vendored FSRS |
| Review counted twice after double tap/retry | review commands/runner, `shared/command_execution.dart`, `operation_id.dart`, review runner test | learning repository duplicate-operation methods and schema uniqueness |
| Sibling burying wrong | review command runner, card model, card scheduler, learning repository, review runner test | queue query/policy if only display is wrong |
| Card postpone counted as review | review runner, card scheduler, `history/review_log.dart`, `history/scheduling_journal.dart` | learning repository/history schema |
| Source/extract/video interval wrong after Done/Later | owning feature runner, `topics/topic_scheduler.dart`, `scheduling_context.dart`, topic scheduler test | `sm20_numeric.dart`, settings, learning repository |
| SM-20 differs from reference vectors | `sm20_numeric.dart`, `topics/topic_scheduler.dart`, collection fixture and numeric tests | `sm20_collection_state.dart`, runtime store; do not change float logic casually |
| FSRS differs from expected algorithm | app card scheduler and test first | only then `fsrs-dart/lib/src/fsrs.dart`, `algorithm.dart`, `models.dart`, selected scheduler/strategy file and vendored tests |
| Wrong study day around rollover/DST/travel | `study_day.dart`, `storage/platform/time_zones.dart`, `settings/study_day_settings.dart`, timezone and DST tests | `scheduling_context.dart`, provider wiring, exact UTC instant/zone |
| Today's queue missing/extra item | `daily_queue/queue_query.dart`, `scheduling/daily_queue/queue_policy.dart`, `queue_command_runner.dart`, queue admission test | learning/content/video repositories and settings |
| Queue order/type mix/priority wrong | queue policy/query, `priority_rank.dart`, queue settings, queue policy test | learning repository query methods and persisted runtime state |
| Daily admission repeats or skips | queue view model/commands/runner, queue policy, admission/stage tests | SM-20 collection/runtime store and learning repository |
| Outstanding/Pending/Final Drill stage wrong | queue commands/runner/view model, queue policy, stage commands test | learning repository and runtime state |
| Later-today state not retained | queue runner/query, learning repository/Drift implementation, `later_today_stage_stores_test.dart` | tables/converters/runtime store |
| Smart Postpone selects/writes wrong items | smart postpone dialog, queue commands/runner, `sm20_postpone.dart`, smart postpone settings/test | learning repository, context, priority rank |
| Advance selects/writes wrong items | priority browser commands/runner, `sm20_advance.dart`, advance test | runtime state/PRNG and learning repository |
| Mercy preview/apply/undo wrong | mercy command runner, `mercy.dart`, `mercy_workflow.dart`, mercy tests | queue candidates, card/topic schedulers, learning repository, table |
| Diagnostics metric wrong but scheduling correct | scheduler metrics query, `metrics/scheduler_metrics.dart`, metrics tests | diagnostics query and learning repository reads |
| Schedule changed “for no reason” | owning command runner, `scheduling_journal.dart`, diagnostics query, learning repository | scheduler event/review log models and concrete repo; request sanitized event rows |

### Browser, priority, video, occlusion, search, settings, UI

| Symptom | Initial packet | Escalate with |
| --- | --- | --- |
| Browser tree parent/order wrong | browser screen/view model, `browser_tree_query.dart`, `documents` element model, browser screen/sort tests | learning repository filing reads, schedules table |
| Move/nest/lift/file-under wrong | browser commands/runner, tree query, browser runner test | learning contract/repository, `priority_rank.dart` if rank changes |
| Permanent deletion removes too much/little | browser commands/runner, deletion test, content/video/learning contracts | all matching Drift repos, tables/FKs; treat as data-loss-sensitive |
| Opening an element routes to wrong screen | `browser/open_element.dart`, browser query/screen, target screen request type | element model/content query |
| Priority slider wrong | priority dialog/view model/query/commands/runner, slider test | priority rank, learning repository |
| Priority Browser sort/filter/select wrong | priority browser screen, priority query/view model, browser sort test | command runner only if writes are wrong |
| Bulk remember/forget/dismiss/done/reset/A-factor wrong | priority browser commands/runner, learning command menu, corresponding runner test | topic/card scheduler, learning repository, history journal |
| Video URL/time parsing wrong | `documents/video_link.dart`, `video_time.dart`, `video.dart`, their unit tests | import sheet/clip dialog for validation/presentation |
| Video clip/resume/note persists wrong | video screen/view model/commands/runner, video tests | video/learning/search repositories and tables |
| Occlusion rectangles/masking wrong | `documents/occlusion.dart`, occlusion canvas/view, occlusion tests | screen only for gestures/scaling |
| Occlusion create/edit loses image or cards | occlusion commands/runner, screen, asset store, occlusion repository tests | content/learning/search repos and schema |
| Search syntax/results wrong | search screen/query, search contract/Drift repository, search query test | app database FTS functions/triggers, materialization writer |
| Search stale after edit/delete | command runner that changed content, search contract/repository, app database FTS support | transaction boundary and maintenance rebuild |
| Setting control/default/validation wrong | settings screen/controls, corresponding settings group, `app_settings.dart`, settings tests | view model if saving/refresh is wrong |
| Setting saves but reverts on restart | settings view model/store, `app_settings.dart`, settings contract/Drift repository | settings table and stored key sample |
| FSRS settings change corrupts/recomputes schedules | `fsrs_settings_rescheduler.dart`, `fsrs_memory_recomputer.dart`, card settings, rescheduler tests | card scheduler, learning repository, transaction runner |
| Diagnostics panel data wrong | diagnostics screen/query/providers and scheduler metrics query | learning/content/search/video contracts and repositories |
| Shared theme/responsive behavior wrong across screens | `shared/ui/app_theme.dart`, `screen_width.dart`, affected shared widget and screen | `incremental_reader_app.dart` |
| Toast missing/duplicates | `shared/ui/toast_message.dart`, calling screen/view model | result/message lifecycle and widget test |
| Provider override/test differs from real app | feature providers, `app/providers.dart`, `test/support/app_harness.dart` | `main.dart` root container |
| Architecture test fails | `test/architecture/folder_rules_test.dart`, complete analyzer error, offending files/imports | move code to correct layer; do not widen allow-list by default |

## Exact file ownership inventory

All paths below are real hand-written project files unless explicitly marked
generated. Use this inventory when requesting a file.

### Entry point and application composition

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Resolve paths, open/classify collection, clean assets, warm settings, backup, launch normal or recovery app |
| `lib/app/incremental_reader_app.dart` | Root `MaterialApp`, theme, initial Queue screen |
| `lib/app/providers.dart` | Global concrete dependency wiring: DB, repositories, clock, IDs, timezone, diagnostics, files, settings |
| `lib/app/startup_gate.dart` | Raw pre-provider SQLite health/schema classification |
| `lib/app/startup_tasks.dart` | Settings warm-up and once-per-study-day backup |

### Shared foundation

| Path | Responsibility |
| --- | --- |
| `lib/shared/clock.dart` | `Clock`, production system clock, fake clock |
| `lib/shared/command_base.dart` | Common command fields |
| `lib/shared/command_execution.dart` | Transaction/idempotency/generation/diagnostics command boundary |
| `lib/shared/diagnostics_sink.dart` | Diagnostic model, interface, no-op and recording sinks |
| `lib/shared/fan_out_diagnostic_sink.dart` | Send one event to multiple sinks |
| `lib/shared/id_generator.dart` | UUID production IDs and predictable fake IDs |
| `lib/shared/in_memory_diagnostic_sink.dart` | Bounded diagnostics buffer |
| `lib/shared/operation_id.dart` | Typed per-user-action correlation ID |
| `lib/shared/result.dart` | `Result<T>` and failure taxonomy |
| `lib/shared/text_excerpt.dart` | Safe bounded single-line preview |
| `lib/shared/utf8_offsets.dart` | UTF-8 byte offset ↔ Dart UTF-16 conversion |
| `lib/shared/ui/app_theme.dart` | Theme, palette, Reader typography |
| `lib/shared/ui/desktop_scroll_view.dart` | Keyboard/scrollbar desktop list |
| `lib/shared/ui/element_type_badge.dart` | Shared element icon/color/label |
| `lib/shared/ui/screen_width.dart` | Compact/wide and dialog width rules |
| `lib/shared/ui/status_pill.dart` | Shared compact status label |
| `lib/shared/ui/toast_message.dart` | Self-dismissing overlay toast host |
| `lib/shared/ui/video_thumbnail.dart` | Best-effort video preview |

### Document domain

| Path | Responsibility |
| --- | --- |
| `lib/documents/source.dart` | Source, normalized Markdown, hash, word count, marker/soft position |
| `lib/documents/source_asset.dart` | Source image-reference metadata |
| `lib/documents/document.dart` | Parsed document at a content revision |
| `lib/documents/block.dart` | Block type and coordinate/mapping helpers |
| `lib/documents/block_content.dart` | Raw/content spans after syntax removal |
| `lib/documents/markdown_block_parser.dart` | Deterministic block parsing with exact offsets |
| `lib/documents/markdown_inline_parser.dart` | Inline parsing and source/render correspondence |
| `lib/documents/inline_markup.dart` | Inline segments/styles/layout mappings |
| `lib/documents/reader_anchor.dart` | Revision-stamped stored anchors/selections |
| `lib/documents/reader_coordinates.dart` | Rendered/block/document coordinate conversion |
| `lib/documents/text_splice.dart` | Validated exact source replacement |
| `lib/documents/position_migration.dart` | Move points/ranges across a splice |
| `lib/documents/apply_source_edit.dart` | Pure edit application and provenance migration |
| `lib/documents/source_edit.dart` | Append-only edit journal and undo restoration data |
| `lib/documents/block_edit.dart` | Construct splices for block/section operations |
| `lib/documents/outline.dart` | Heading hierarchy and section ranges |
| `lib/documents/extract.dart` | Extract and valid/stale/orphaned provenance |
| `lib/documents/card.dart` | Card types, cloze parsing/rendering, content parent |
| `lib/documents/occlusion.dart` | Regions, modes, JSON, question/answer masking |
| `lib/documents/video.dart` | Video/range models and uncovered ranges |
| `lib/documents/video_time.dart` | Parse/format human video times |
| `lib/documents/video_link.dart` | Platform detection and timestamped external links |

### Scheduling domain

| Path | Responsibility |
| --- | --- |
| `lib/scheduling/element.dart` | Element identity/type, lifecycle, common schedule |
| `lib/scheduling/study_day.dart` | Local named-zone day and rollover/DST boundaries |
| `lib/scheduling/priority_rank.dart` | Lexicographic relative order keys/scale |
| `lib/scheduling/scheduling_context.dart` | Current settings/calendar/scheduler/runtime construction |
| `lib/scheduling/effective_due_query.dart` | Adjustment-aware effective due answer |
| `lib/scheduling/sm20_numeric.dart` | Delphi Real48, rounding, PRNG, sort/spread compatibility |
| `lib/scheduling/sm20_collection_state.dart` | Persistable global SM-20 queues/timestamps |
| `lib/scheduling/sm20_runtime_store.dart` | Versioned settings codec for SM-20 runtime |
| `lib/scheduling/topics/topic_scheduler.dart` | SM-20 topic state machine |
| `lib/scheduling/cards/card_scheduler.dart` | FSRS adapter/state/review/reschedule/leech logic |
| `lib/scheduling/cards/fsrs_memory_recomputer.dart` | Replay genuine reviews after parameter changes |
| `lib/scheduling/daily_queue/queue_policy.dart` | Candidate scoring, caps, ordering, merge, stage plan |
| `lib/scheduling/postpone/sm20_postpone.dart` | Smart/automatic postpone selection and math |
| `lib/scheduling/postpone/sm20_advance.dart` | Advance selection and deterministic draws |
| `lib/scheduling/mercy/mercy.dart` | Mercy score/gather/order/redistribution/capacity math |
| `lib/scheduling/mercy/mercy_workflow.dart` | Durable preview/apply/undo tokens/codecs |
| `lib/scheduling/history/review_log.dart` | Universal scheduling log entries/types/snapshots |
| `lib/scheduling/history/scheduler_event.dart` | Rich append-only scheduler audit event |
| `lib/scheduling/history/scheduling_journal.dart` | Consistent history/event append construction |
| `lib/scheduling/metrics/scheduler_metrics.dart` | Pure pacing/retention/load/topic-policy metrics |

### Settings domain

| Path | Responsibility |
| --- | --- |
| `lib/settings/app_settings.dart` | Compose all groups; resilient stored map encoding/decoding |
| `lib/settings/settings_store.dart` | Cached typed facade over raw string settings |
| `lib/settings/study_day_settings.dart` | Home timezone and rollover |
| `lib/settings/queue_settings.dart` | Daily caps, ordering, stage mix |
| `lib/settings/remember_settings.dart` | Initial/re-remember topic behavior |
| `lib/settings/card_settings.dart` | FSRS parameters/retention/leech settings |
| `lib/settings/postpone_settings.dart` | Automatic postpone and named profile assignment |
| `lib/settings/smart_postpone_settings.dart` | Manual Smart Postpone profile model |
| `lib/settings/mercy_settings.dart` | Mercy configuration/matrix |
| `lib/settings/diagnostics_settings.dart` | Logging/panel bounds |
| `lib/settings/settings_list_equality.dart` | Content equality for list settings |

### Feature inventory

| Folder | Complete file set |
| --- | --- |
| `lib/features/browser/` | `add_element_flow.dart`, `browser_command_runner.dart`, `browser_commands.dart`, `browser_providers.dart`, `browser_screen.dart`, `browser_tree_query.dart`, `browser_view_model.dart`, `element_content_query.dart`, `import_sheet.dart`, `open_element.dart` |
| `lib/features/daily_queue/` | `mercy_command_runner.dart`, `queue_command_runner.dart`, `queue_commands.dart`, `queue_providers.dart`, `queue_query.dart`, `queue_screen.dart`, `queue_view_model.dart`, `smart_postpone_dialog.dart`, `study_screen_outcome.dart` |
| `lib/features/diagnostics/` | `diagnostics_providers.dart`, `diagnostics_query.dart`, `diagnostics_screen.dart`, `scheduler_metrics_query.dart` |
| `lib/features/extract/` | `extract_command_runner.dart`, `extract_commands.dart`, `extract_context_overlay.dart`, `extract_providers.dart`, `extract_screen.dart`, `extract_view_model.dart`, `formulation_command_runner.dart`, `formulation_commands.dart`, `formulation_dialog.dart` |
| `lib/features/occlusion/` | `occlusion_command_runner.dart`, `occlusion_commands.dart`, `occlusion_providers.dart`, `occlusion_screen.dart`, `widgets/occlusion_canvas.dart`, `widgets/occlusion_view.dart` |
| `lib/features/occlusion/widgets/` | `occlusion_canvas.dart`, `occlusion_view.dart` |
| `lib/features/priority/` | `learning_command_menu.dart`, `learning_commands.dart`, `priority_browser_command_runner.dart`, `priority_browser_commands.dart`, `priority_browser_screen.dart`, `priority_command_runner.dart`, `priority_commands.dart`, `priority_dialog.dart`, `priority_providers.dart`, `priority_query.dart`, `priority_view_model.dart` |
| `lib/features/reader/` | `reader_command_runner.dart`, `reader_commands.dart`, `reader_image_input.dart`, `reader_providers.dart`, `reader_screen.dart`, `reader_view_model.dart`, `typography_controller.dart` |
| `lib/features/reader/widgets/` | `block_editor.dart`, `block_span_builder.dart`, `block_view.dart`, `extract_highlights.dart`, `reader_selection.dart`, `reader_side_panel.dart`, `reader_view.dart`, `selection_knobs.dart`, `selection_toolbar.dart` |
| `lib/features/recovery/` | `recovery_screen.dart` |
| `lib/features/review/` | `review_command_runner.dart`, `review_commands.dart`, `review_providers.dart`, `review_screen.dart`, `review_view_model.dart` |
| `lib/features/search/` | `search_providers.dart`, `search_query.dart`, `search_screen.dart` |
| `lib/features/settings/` | `fsrs_settings_rescheduler.dart`, `settings_controls.dart`, `settings_screen.dart`, `settings_view_model.dart` |
| `lib/features/video/` | `import_video_sheet.dart`, `video_clip_dialog.dart`, `video_command_runner.dart`, `video_commands.dart`, `video_providers.dart`, `video_screen.dart`, `video_view_model.dart` |

### Persistence inventory

| Path | Responsibility |
| --- | --- |
| `lib/storage/contracts/content_repository.dart` | Sources, parsed documents, edits, extracts, cards |
| `lib/storage/contracts/video_repository.dart` | Videos and scheduled ranges |
| `lib/storage/contracts/learning_repository.dart` | Schedules, topic/card state, queue, priority, logs, activity, Mercy |
| `lib/storage/contracts/source_asset_repository.dart` | Source image metadata |
| `lib/storage/contracts/occlusion_repository.dart` | Card occlusion metadata |
| `lib/storage/contracts/search_repository.dart` | Materialized FTS documents/search |
| `lib/storage/contracts/settings_repository.dart` | Raw string key/value settings |
| `lib/storage/contracts/transfer_repository.dart` | Dataset identity/generation |
| `lib/storage/contracts/transaction_runner.dart` | Atomic transaction abstraction |
| `lib/storage/contracts/database_check.dart` | Integrity-check model/interface |
| `lib/storage/contracts/database_maintenance.dart` | Maintenance model/interface |
| `lib/storage/database/tables.dart` | Drift tables, columns, keys, constraints |
| `lib/storage/database/app_database.dart` | Schema version, migrations, indexes, FTS, health helpers |
| `lib/storage/database/app_database.g.dart` | **Generated** Drift code; never edit manually |
| `lib/storage/database/connection.dart` | Local-file and in-memory DB opening |
| `lib/storage/database/row_converters.dart` | Domain ↔ Drift rows and persisted JSON decoding |
| `lib/storage/dataset_lineage.dart` | Dataset ID, generation, writer epoch, owner device |
| `lib/storage/drift/drift_content_repository.dart` | Content implementation and block rebuild |
| `lib/storage/drift/drift_video_repository.dart` | Video/range implementation |
| `lib/storage/drift/drift_learning_repository.dart` | Schedule/state/history/queue/activity implementation |
| `lib/storage/drift/drift_source_asset_repository.dart` | Source asset metadata implementation |
| `lib/storage/drift/drift_occlusion_repository.dart` | Occlusion implementation |
| `lib/storage/drift/drift_search_repository.dart` | FTS implementation |
| `lib/storage/drift/drift_settings_repository.dart` | Settings implementation |
| `lib/storage/drift/drift_transfer_repository.dart` | Dataset lineage implementation |
| `lib/storage/drift/drift_transaction_runner.dart` | Drift transaction adapter |
| `lib/storage/drift/drift_database_check.dart` | Logical integrity repair |
| `lib/storage/drift/drift_database_maintenance.dart` | FTS repair/checkpoint/VACUUM/ANALYZE |
| `lib/storage/files/source_asset_file_store.dart` | Content-addressed bytes, validation, cleanup/staging |
| `lib/storage/files/backup_service.dart` | Create/validate/retain backups |
| `lib/storage/files/backup_restore_service.dart` | Cold restore with safe promotion/rollback |
| `lib/storage/files/rotating_log_sink.dart` | Bounded structured file diagnostics |
| `lib/storage/platform/app_paths.dart` | App-local DB/backup/asset/log paths |
| `lib/storage/platform/time_zones.dart` | Pinned IANA zones and Windows aliases |

## Database authority map

Do not infer a table from a similarly named screen. Use this mapping.

| Table in `tables.dart` | Domain authority | Primary concrete repository |
| --- | --- | --- |
| `Sources` | `documents/source.dart` | `drift_content_repository.dart` |
| `SourceAssets` | `documents/source_asset.dart` | `drift_source_asset_repository.dart` |
| `SourceEdits` | `documents/source_edit.dart` | `drift_content_repository.dart` |
| `Blocks` | derived parser cache; no stable external block references | `drift_content_repository.dart` |
| `Extracts` | `documents/extract.dart` | `drift_content_repository.dart` |
| `Videos`, `VideoElements` | `documents/video.dart` | `drift_video_repository.dart` |
| `Cards` | `documents/card.dart` | `drift_content_repository.dart` |
| `CardOcclusions` | `documents/occlusion.dart` | `drift_occlusion_repository.dart` |
| `ElementSchedules` | `scheduling/element.dart` | `drift_learning_repository.dart` |
| `TopicStates` | `scheduling/topics/topic_scheduler.dart` | `drift_learning_repository.dart` |
| `CardMemories` | `scheduling/cards/card_scheduler.dart` | `drift_learning_repository.dart` |
| `ReviewEvents` | genuine FSRS review replay input | `drift_learning_repository.dart` |
| `RevlogEntries` | `scheduling/history/review_log.dart` | `drift_learning_repository.dart` |
| `SchedulerEvents` | `scheduling/history/scheduler_event.dart` | `drift_learning_repository.dart` |
| `MercyBatches` | `scheduling/mercy/mercy_workflow.dart` | `drift_learning_repository.dart` |
| `SearchDocuments` plus FTS virtual table | `storage/contracts/search_repository.dart` | `drift_search_repository.dart` / `app_database.dart` |
| `ActivityEvents` | command/activity diagnostics | `drift_learning_repository.dart` |
| `Settings` | `settings/app_settings.dart` and SM-20 runtime codec | `drift_settings_repository.dart` |
| `DatasetMeta` | `storage/dataset_lineage.dart` | `drift_transfer_repository.dart` |

`Blocks` are rebuilt after a source edit. No persisted entity should use a
block ID as a durable citation; persisted positions are UTF-8 offsets into the
exact Markdown revision.

## Critical invariants by subsystem

### Documents and edits

- Persisted coordinates are UTF-8 byte offsets. Dart string indices are UTF-16.
- A selection/anchor includes the content revision used to interpret it.
- `TextSplice` replaces `[startUtf8, endUtf8)` with normalized text.
- Editing rebuilds all derived Blocks atomically.
- Child extract provenance is migrated deterministically. Overlap becomes
  stale/orphaned; matching text elsewhere is never used as a guessed repair.
- Undo appends an inverse edit at a new revision; it does not rewind history.
- Marker position is explicit progress; soft scroll position is not progress.

### Scheduling

- Sources, extracts, and video elements use SM-20 topic state. Cards use FSRS.
- `StudyDay` is a named-zone calendar day with configurable rollover, not local
  midnight or a raw 24-hour subtraction.
- SM-20 random draws use one persisted deterministic runtime state.
- `ElementType` ordinal/order and stored event names are compatibility data.
- Priority is a relative lexicographic key, not an independent numeric score.
- `dueDay`/`dueAtUtc` and `originalDue*` distinguish algorithmic due from
  postponement-adjusted due.
- Genuine review, practice, postpone, edit, dismissal, and undo are distinct
  history semantics.

### Storage and recoverability

- Schema is currently described by `AppDatabase.kSchemaVersion` in
  `app_database.dart`; verify the constant rather than relying on this document
  after future changes.
- An existing database from a newer schema must not be opened as writable.
- Pre-migration and rolling backups are deliberate safety boundaries.
- Repositories map domain values; `row_converters.dart` owns shared decoding.
- Image bytes are immutable content-addressed files; SQLite stores metadata.
- Search documents and Blocks are derived/materialized data and can be rebuilt,
  but source/card/extract/schedule/history rows are canonical user data.

### Settings compatibility

- `app_settings.dart` persists flat string keys. A field rename can be safe; a
  stored key rename silently loses the old preference unless migrated.
- Decode is resilient to malformed/out-of-range values and falls back safely.
- FSRS parameter changes may require review replay and due-date recomputation.

## Tests as executable specifications

Ask for the narrowest matching test with production files. If no test covers
the bug, request a nearby test to copy its fake-clock/repository/harness style,
then propose a regression test before the fix.

| Concern | Best tests |
| --- | --- |
| Layering | `test/architecture/folder_rules_test.dart` |
| Startup | `test/app/startup_gate_test.dart` |
| Markdown/outline/edit/offset | `test/documents/markdown_parsing_test.dart`, `outline_test.dart`, `position_migration_test.dart`, `source_editing_test.dart`, `test/shared/utf8_offsets_test.dart` |
| Reader visual/edit regression | `test/features/reader/reader_screen_test.dart`, `reader_view_model_test.dart`, `widgets/block_editor_test.dart`, `widgets/editing_regressions_test.dart`, `widgets/reader_view_test.dart` |
| Extract/formulation | `test/features/extract/extract_command_runner_test.dart`, `extract_view_model_test.dart`, `formulation_dialog_test.dart` |
| Browser/file/delete | `test/features/browser/browser_command_runner_test.dart`, `browser_deletion_test.dart`, `browser_screen_test.dart` |
| Topic/SM-20 | `test/scheduling/topics/topic_scheduler_test.dart`, `sm20_numeric_test.dart`, `sm20_collection_fixture_test.dart` |
| Card/FSRS | `test/scheduling/cards/card_scheduler_test.dart`, `fsrs_memory_recomputer_test.dart`, `test/features/review/review_command_runner_test.dart` |
| Queue/stages | `test/scheduling/daily_queue/queue_policy_test.dart`, `test/features/daily_queue/queue_admission_test.dart`, `stage_commands_test.dart`, `later_today_stage_stores_test.dart` |
| Postpone/advance/Mercy | `test/scheduling/postpone/sm20_postpone_test.dart`, `sm20_advance_test.dart`, `test/scheduling/mercy/mercy_test.dart`, `mercy_workflow_test.dart`, `test/features/daily_queue/smart_postpone_test.dart` |
| Priority | `test/scheduling/priority_rank_test.dart`, `test/features/priority/priority_command_runner_test.dart`, `priority_browser_command_runner_test.dart`, `priority_browser_sort_test.dart` |
| Video | `test/documents/video_link_test.dart`, `video_time_test.dart`, `video_test.dart`, `test/features/video/video_screen_test.dart` |
| Occlusion | `test/documents/occlusion_test.dart`, `test/features/occlusion/occlusion_canvas_test.dart`, `occlusion_command_runner_test.dart`, `test/storage/occlusion_repository_test.dart` |
| Search | `test/features/search/search_query_test.dart` |
| Settings | `test/settings/app_settings_test.dart`, `settings_store_test.dart`, `test/features/settings/fsrs_settings_rescheduler_test.dart` |
| Database/schema/migration | `test/storage/database_baseline_test.dart`, `card_schema_test.dart`, `repetition_log_schema_test.dart`, and matching `v*_migration_test.dart` |
| Integrity/backup/assets | `test/storage/database_check_test.dart`, `database_maintenance_test.dart`, `backup_restore_test.dart`, `asset_backup_test.dart`, `source_asset_file_store_test.dart` |
| End-to-end reading | `test/workflows/incremental_reading_loop_test.dart`, `integration_test/import_read_extract_undo_test.dart`, `integration_test/extract_to_card_review_loop_test.dart` |
| End-to-end video/recovery/priority | `test/workflows/incremental_video_loop_test.dart`, `daylight_saving_and_recovery_test.dart`, `integration_test/priority_caps_and_overload_valve_test.dart` |

`test/support/app_harness.dart` supplies a cross-feature test composition root.
`test/support/anchors.dart` and `sample_document_generator.dart` support document
tests. Request them when a test imports them or a reproduction needs the same
fixtures.

## Files outside `lib/`

Request these only for their specific boundary:

| Path | When needed |
| --- | --- |
| `pubspec.yaml` | Dependency/API/plugin/build-runner issue |
| `pubspec.lock` | Exact resolved package version matters |
| `analysis_options.yaml` | Analyzer/lint behavior |
| `android/app/src/main/AndroidManifest.xml` | Android permissions/intents/plugin registration issue |
| `android/app/build.gradle.kts`, `android/build.gradle.kts`, `android/settings.gradle.kts` | Android build/SDK/Gradle issue |
| `windows/runner/main.cpp`, `windows/runner/Runner.rc` | Windows runner/metadata/native startup issue |
| `windows/CMakeLists.txt`, `windows/flutter/CMakeLists.txt` | Windows linking/plugin build issue |
| `fsrs-dart/pubspec.yaml` | Vendored scheduler dependency/version issue |
| `fsrs-dart/lib/fsrs.dart` | Vendored public export surface |
| `fsrs-dart/lib/src/models.dart` | Vendored FSRS models |
| `fsrs-dart/lib/src/fsrs.dart`, `algorithm.dart`, `reschedule.dart` | Confirmed algorithm/reschedule defect inside vendor package |
| `fsrs-dart/lib/src/impl/basic_scheduler.dart`, `long_term_scheduler.dart` | Confirmed scheduler implementation defect |
| `fsrs-dart/lib/src/strategies/*.dart` | Confirmed learning-step/seed strategy defect |
| `fsrs-dart/test/*.dart` and vectors | Vendor conformance regression |

The large `anki_source_code/` directory is reference material, not the running
Flutter application. Do not request it for ordinary app bugs. Only consult a
specific Anki reference file when a confirmed FSRS/Anki-compatibility question
requires comparison.

## Diagnostic command requests

Ask the user to run only relevant commands and paste complete text output.

```powershell
dart analyze
flutter test test/path/to/focused_test.dart -r expanded
flutter test
git status --short
git diff --check
git diff -- path/to/file1.dart path/to/file2.dart
```

For a generated Drift mismatch, after inspecting source declarations:

```powershell
dart run build_runner build
```

Do not advise deleting the database, backups, generated files, lockfile, build
directories, or user asset directories as a first diagnostic step. If a clean
build is later justified, distinguish recoverable build artifacts from user
data and name the exact target.

## What evidence is safe and useful

Prefer:

- Synthetic Markdown/card/video values that preserve the failing characters,
  nesting, offsets, timestamps, or lengths.
- Sanitized diagnostic events with IDs consistently replaced but structural
  fields preserved.
- Exact UTC instant, zone ID, rollover hour, due day, and scheduler settings for
  time bugs.
- Before/after domain state JSON from scheduler diagnostics for schedule bugs.
- Schema version, table/column names, constraint message, and migration origin
  for database bugs.
- Widget size, platform, input method, and interaction sequence for UI bugs.

Avoid requesting:

- A live personal SQLite database when a minimal fixture can reproduce it.
- Backup archives, private study text, absolute personal paths, or image bytes
  unless essential and explicitly sanitized.
- API credentials; this app should not need them.
- Massive logs without the failure timestamp/operation ID.

## Response template for the LLM

When the user reports a bug, answer in this shape:

```text
Likely path: <presentation/read/command/domain/persistence/startup>.
Why: <observation tied to architecture>.

Please send these complete files first:
1. <exact path> — <what decision it owns>
2. <exact path> — <why it can produce this symptom>
3. <exact test path> — <expected invariant>

Also paste:
- exact reproduction
- full error/stack trace or focused test output
- whether it survives restart
- recent diff for those paths

I may next ask for <contract/repository/table/provider>, but only if these files
show the fault crosses that boundary.
```

After reading the packet, identify the earliest incorrect state transition,
explain the invariant being violated, propose a regression test, and then give
a minimal patch against files actually seen. Clearly label uncertainty. Never
invent a method, column, provider, or command that is absent from the attached
files or from this inventory.

## Maintenance rule for this document

Update this guide whenever any of the following changes:

- a file is added, removed, renamed, or changes ownership;
- a command/action gains a new execution path;
- a table, stored enum/string/key, migration, or backup rule changes;
- a feature begins using a new contract/repository;
- a new focused test becomes the executable authority for an invariant;
- a symptom would now require a different initial file packet.

The maintenance check is simple: every hand-written file returned by
`rg --files lib` must appear either in the exact inventory or be explicitly
documented as generated, and every suggested path must exist. The human guide
at `ARCHITECTURE/HUMAN.md` explains the system pedagogically; this file remains
the operational routing authority for a repository-blind conversation.
