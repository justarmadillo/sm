# Editable Reader Specification

Status: **normative implementation contract**

Audience: an AI coding agent, or a developer, modifying the Reader in this repository.

Purpose: define a reading surface that survives **selection**, **in-place editing of source text**, **images**, and **tables** without ever silently moving a stored position.

---

## 1. Read this before changing code

This document is the implementation authority for:

- the coordinate system every reader position is expressed in;
- how source text is mutated;
- how stored positions migrate across a mutation;
- how extract provenance is validated and marked stale;
- block re-derivation after an edit;
- image assets and table cells in the reader;
- text selection.

Precedence:

1. This file, for reader coordinates, editing, and rendering.
2. `plans/scheduler/LLM_FIX_INSTRUCTIONS.md`, for anything touching schedules. **Nothing in this document may change a schedule.** Editing text is not a repetition, is not an encounter, and never touches `ElementSchedules`, `TopicStates`, or `CardMemories`.
3. `plans/Plan.md`, for product behaviour outside the reader.
4. `plans/IR.md`, as historical context only.

Where this document and the current implementation disagree, this document describes the target. A green test suite proves compatibility with the *current* positional scheme, not conformance to this contract.

### Fidelity labels

- **[Invariant]** — must hold at all times; a violation is a bug even if tests pass.
- **[Normative]** — the required behaviour.
- **[Rationale]** — why, not what. Non-binding.
- **[Deferred]** — deliberately out of scope for this contract; listed so it is not reinvented ad hoc.

---

## 2. The defect this contract exists to remove

Every reader position is currently stored as `(blockId, utf8OffsetWithinBlock)`, and block ids are generated positionally:

```dart
String blockId(String sourceId, int index) => '$sourceId:$index';
```

The id **is** the index. Insert one paragraph near the top of a document and every block below it takes over the id of its predecessor. The resume marker and every extract's provenance then resolve, without error and without warning, to different text than the one they were recorded against.

No amount of care in the editing UI can fix this, because the defect is in the coordinate system, not in the editor. Editing must therefore be built on a coordinate that does not name a container.

**[Rationale]** Naming the container is the mistake. A position must name a *place in the text*. Text does not get renumbered; only edits move it, and an edit reports exactly how far.

---

## 3. Coordinate spaces

Four spaces exist. **[Invariant]** Exactly one of them is ever persisted.

| # | Space | Unit | Addresses | Persisted |
|---|---|---|---|---|
| 1 | **Document** | UTF-8 byte offset | `Sources.markdown` of a stated revision | **Yes — the only persisted space** |
| 2 | **Block-raw** | UTF-16 index | `Block.raw` | No |
| 3 | **Block-content** | UTF-16 index | `BlockContent.text` (per-line syntax stripped) | No |
| 4 | **Rendered** | UTF-16 index | `InlineLayout.plainText` (what the user sees) | No |

Conversions, in order:

```text
document  --(block lookup by byte range)-->      block-raw
block-raw --(BlockContent.contentIndexForRaw)--> block-content
block-content --(InlineLayout segment map)-->    rendered
```

and the exact inverse in the other direction.

**[Normative]** All four conversions are exposed by a single façade, `ReaderCoordinates`, in `lib/src/domain/content/`. No other code performs a conversion. Selection, extraction, highlighting, marker placement, and the editor all call the façade.

**[Rationale]** The chain is four links long and every link already exists somewhere in the codebase, applied by hand at each call site. Four hand-rolled conversions across five files is where the bugs will live. One façade with round-trip property tests is where they will not.

**[Invariant]** A document offset never falls inside a multi-byte UTF-8 character. Every producer of an offset — the editor, the selection layer, the migration — yields character boundaries only. `core/utf8_offsets.dart` remains the sole bridge to Dart's UTF-16 indices.

**[Invariant]** An embedded object (an image) occupies exactly one UTF-16 unit in rendered space — the object-replacement character `U+FFFC` the inline parser already emits — and maps back to the full `![alt](url)` span in block-raw space. Selection crossing an image is therefore ordinary, not special-cased.

---

## 4. The anchor

```dart
final class ReaderAnchor {
  final int utf8Offset;      // document space
  final int contentRevision; // the source revision this offset was written against
  final PositionGravity gravity;
}
```

`blockId` is removed. Which block a position lives in is **looked up when needed**, by binary search over the block byte ranges the `Blocks` table already stores, and never stored.

**[Invariant]** No persisted row outside the `Blocks` table may reference a block id. This is what makes blocks a disposable derived cache (§8).

### 4.1 Gravity

An insertion at exactly the offset of an anchor is ambiguous: does the anchor end up before or after the new text? The answer differs by role, so it is a property of the anchor.

| Anchor | Gravity | Behaviour on an insertion at its exact offset |
|---|---|---|
| Resume marker | `left` | Stays before the new text |
| Soft position | `left` | Stays before the new text |
| Provenance range **start** | `right` | Moves after the new text |
| Provenance range **end** | `left` | Stays before the new text |

**[Rationale]** Text inserted at the marker is unread, so the marker must not jump over it. A provenance range describes text already copied into the extract, so it must not silently swallow newly typed text at either boundary. Ranges therefore never grow at their edges.

### 4.2 Revision stamping

**[Normative]** An anchor carries the `contentRevision` it was written against. Code that resolves an anchor whose `contentRevision` is older than the source's current one **must** first replay the intervening splices (§6.1) to bring it forward. Resolving a stale-revision anchor directly is forbidden.

**[Rationale]** Migration is applied eagerly inside the edit transaction, so in a correct system this never triggers. It exists so that a bug, a partial restore, or an import from an older backup degrades into a correct-but-slower path instead of into silently wrong positions.

---

## 5. The splice — the only mutation primitive

```dart
final class TextSplice {
  final int startUtf8;    // inclusive
  final int endUtf8;      // exclusive; endUtf8 >= startUtf8
  final String inserted;  // normalized; may be empty

  int get removedLength => endUtf8 - startUtf8;
  int get insertedLength; // UTF-8 byte length of `inserted`
  int get shift => insertedLength - removedLength;
}
```

**[Invariant]** Source text changes **only** through a `TextSplice`. There is no code path that assigns a new whole-document string.

**[Rationale]** If the editor hands over a replacement document, the splice must be recovered by diffing. Diffing is a heuristic: for repeated text it has several equally plausible answers, and the wrong one relocates positions into the wrong paragraph. With an explicit splice the migration is arithmetic and provably exact. This single constraint is what makes the rest of the contract sound.

### 5.1 Validation

**[Normative]** A splice is rejected with `ValidationFailure` unless all of these hold:

- `0 <= startUtf8 <= endUtf8 <= markdown.utf8Length`
- both bounds fall on UTF-8 character boundaries
- `inserted` has been passed through `normalizeMarkdown` **before** its byte length is computed
- `insertedLength <= kMaxSpliceBytes` (default 8 MiB)
- the splice is not a no-op (`removedLength == 0 && insertedLength == 0`)

**[Invariant]** A no-op splice never bumps `contentRevision` and never writes an edit row.

**[Rationale]** Normalizing after measuring is the classic desync: a pasted CRLF block measured as `\r\n` and stored as `\n` shifts every downstream position by the number of lines pasted.

### 5.2 Optimistic concurrency

**[Normative]** Every edit command carries `baseContentRevision`. If it does not equal the source's current `contentRevision` at the start of the transaction, the command fails with `ConflictFailure` and nothing is written.

---

## 6. Position migration

Given a splice `(a, b, n)` where `n = insertedLength` and `shift = n - (b - a)`, every persisted document offset `p` migrates by exactly one of three rules:

| Case | Result | Stale? |
|---|---|---|
| `p < a` | `p` unchanged | no |
| `p > b` | `p + shift` | no |
| `a <= p <= b` | see below | see below |

The boundary cases:

- **`a < p < b`** — the text this position pointed at was removed. Collapse to `a`. **Mark stale.**
- **`p == a` and `p == b`** (pure insertion at `p`) — resolved by gravity: `left` yields `a`, `right` yields `a + n`. Not stale.
- **`p == a`, `b > a`** — `p` stays at `a`. Not stale.
- **`p == b`, `b > a`** — `p + shift`, which equals `a`. Not stale.

**[Invariant]** Migration has no heuristics, no text search, and no fuzzy matching. Every input has exactly one defined output.

**[Normative]** Migration is applied inside the same transaction as the splice, to:

- `Sources.markerUtf8` and `Sources.softUtf8` of the edited source;
- `Extracts.startUtf8` and `Extracts.endUtf8` for every extract whose `parentId` is the edited source, and — via §10.3 — for every extract whose parent is an edited extract;
- nothing else. **[Invariant]** No scheduling column is read or written.

### 6.1 Replay

**[Normative]** `migrateForward(anchor, edits)` applies the splices of revisions `(anchor.contentRevision, current]` in ascending order. Migration is associative under this ordering, so replaying N splices equals having applied each one eagerly.

---

## 7. Provenance staleness

An extract already stores **its own copy** of the extracted markdown (`Extracts.markdown`). **[Invariant]** An edit to the source never changes an extract's text, schedule, priority, or lifecycle. Only the *link back to where it came from* can degrade.

```dart
enum ProvenanceState { verbatim, stale, orphaned }
```

**[Normative]** After migration, for each affected extract:

1. If the migrated range is empty (`start == end`) **and** it was non-empty before → `orphaned`.
2. Else if the pre-migration range overlapped `[a, b)` → re-slice the new markdown and re-hash. Hash equals `selectedTextHash` → `verbatim`; otherwise → `stale`.
3. Else → unchanged.

**[Normative]** Only ranges overlapping `[a, b)` are re-hashed. A range entirely before `a` cannot have changed content; a range entirely after `b` shifted but its bytes are identical.

**[Normative]** `stale` and `orphaned` are never cleared automatically. The reader shows the state on the "open source" affordance — a stale extract offers *"the source text has changed"* rather than jumping to a location that may be wrong. **[Deferred]** An explicit user-driven re-link action.

**[Rationale]** Automatic re-anchoring by text search is the tempting alternative and the wrong one: in a document where a phrase appears twice it re-links to the wrong occurrence and reports success. Flagging is honest, and honest degradation is what makes the reader trustworthy over years of use.

---

## 8. Block re-derivation

**[Normative]** After a splice, all `Blocks` rows for the source are deleted and re-derived from the new markdown, in the same transaction.

**[Rationale]** Block ids carry no meaning once §4's invariant holds, so rewriting them is free. Incremental re-parsing of only the affected window looks attractive and is a trap: markdown block boundaries depend on blank lines, so deleting one merges neighbours and typing one splits them, and setext headings and list continuations extend the blast radius further up and down than a fixed window covers. A whole-document re-parse is pure, deterministic, and has no blast radius to get wrong.

**[Normative]** Windowed re-parsing may be introduced **only** behind a differential test asserting byte-identical output against a full re-parse over a large corpus, and only if a benchmark shows full re-parse of a 50k-word document exceeds 16 ms. Editing is per block-save, not per keystroke, so the budget is generous.

**[Normative]** `Sources.contentHash` and `Sources.wordCount` are recomputed in the same transaction.

---

## 9. Schema — version 8

`kSchemaVersion` moves from 7 to 8. The migration is appended as an `if (from < 8)` block, re-runs `_createIndexes`, and is re-runnable (`_addColumnIfMissing`, `_hasColumn`), per the existing conventions.

### 9.1 `Sources`

Added:

| Column | Type | Notes |
|---|---|---|
| `content_revision` | int, default 1 | Bumped **only** by a content splice |
| `marker_utf8` | int, nullable | Document space |
| `marker_revision` | int, nullable | Paired with `marker_utf8` |
| `soft_utf8` | int, nullable | |
| `soft_revision` | int, nullable | |

Retired after migration: `marker_block_id`, `marker_offset`, `soft_block_id`, `soft_offset`.

**[Normative]** `revision` keeps its existing "bumped on every write" meaning and is **not** reused. Conflating a row-touch counter with a content-version counter would make replay (§6.1) skip or repeat splices.

New constraints:

```sql
CHECK ((marker_utf8 IS NULL) = (marker_revision IS NULL))
CHECK ((soft_utf8   IS NULL) = (soft_revision   IS NULL))
CHECK (marker_utf8 IS NULL OR marker_utf8 >= 0)
CHECK (soft_utf8   IS NULL OR soft_utf8   >= 0)
```

### 9.2 `Extracts`

Added: `start_utf8`, `end_utf8`, `anchor_revision`, `provenance_state` (0 verbatim, 1 stale, 2 orphaned).

Retired after migration: `start_block_id`, `end_block_id`, `start_offset`, `end_offset`.

```sql
CHECK (start_utf8 >= 0 AND end_utf8 >= start_utf8)
CHECK (provenance_state BETWEEN 0 AND 2)
```

### 9.3 `SourceEdits` (new)

Append-only journal, one row per applied splice.

| Column | Notes |
|---|---|
| `id` | |
| `source_id` | FK → `Sources`, `ON DELETE CASCADE` |
| `content_revision` | the revision this splice **produced** |
| `start_utf8`, `end_utf8` | the splice bounds |
| `removed_text` | exact bytes removed — enables exact undo |
| `inserted_text` | exact bytes inserted |
| `applied_at_utc` | |
| `operation_id` | idempotency key |

```sql
UNIQUE (source_id, content_revision)
UNIQUE (operation_id)
```

**[Invariant]** Append-only. Undo appends an **inverse splice** at a new revision; it never deletes a row. This matches the scheduler's history rule and is what makes replay total.

### 9.4 `SourceAssets` (new)

| Column | Notes |
|---|---|
| `id` | |
| `source_id` | FK → `Sources`, `ON DELETE CASCADE` |
| `src_ref` | the `![alt](src)` target as written in the markdown |
| `sha256` | content address; the file lives at `assets/<sha256>` |
| `mime` | |
| `width_px`, `height_px` | intrinsic size, captured at import |
| `byte_size` | |
| `state` | 0 ok, 1 missing, 2 failed |
| `imported_at_utc` | |

```sql
UNIQUE (source_id, src_ref)
CHECK (state BETWEEN 0 AND 2)
CHECK (state != 0 OR (width_px > 0 AND height_px > 0))
```

**[Normative]** Files are content-addressed and shared: two sources referencing identical bytes store one file. Deleting a source deletes its rows; the file is removed only when no row references its hash.

### 9.5 `Blocks`

Added: `table_cells` TEXT nullable — a JSON array of rows, each row an array of `[start, end]` UTF-16 pairs relative to `raw`. Null for every non-table block.

### 9.6 Data migration (v7 → v8)

**[Normative]** In order:

1. Add every new column; set `content_revision = 1`.
2. For each source, for the marker and the soft position: look up the named block row and set `utf8 = block.start_utf8 + offset`, `revision = 1`.
3. For each extract: the same conversion for both ends; `anchor_revision = 1`.
4. Re-hash each extract's range against the source markdown; set `provenance_state` to `verbatim` on a match, `stale` otherwise.
5. **Any anchor whose block id is not found is set to `orphaned` (extracts) or NULL (marker, soft). It is never guessed at.**
6. Clear the retired columns.
7. Re-run `_createIndexes`.

**[Rationale]** Step 5 follows the precedent set by the v6 scheduler migration, which flagged a contradictory legacy due date as `legacy_due_unknown` rather than inventing one. An invented position is worse than an absent one, because the user cannot tell it is wrong.

---

## 10. Application layer

### 10.1 Commands

```dart
final class EditSourceBlock extends AppCommand    // block-scoped edit; the common path
final class ApplySourceSplice extends AppCommand  // explicit range edit
final class DeleteSourceBlock extends AppCommand  // sugar over a delete splice
final class UndoSourceEdit extends AppCommand     // appends the inverse splice
final class EditExtractText extends AppCommand    // same machinery, extract parent
```

All carry `operationId` and `baseContentRevision`.

**[Normative]** Idempotency follows the existing rule: a resent command with a known `operationId` **replays the recorded outcome** rather than applying the splice twice. The `SourceEdits` row is the record.

### 10.2 Transaction order

**[Normative]** One transaction, in this order:

1. Load the markdown and `content_revision`; compare against `baseContentRevision`.
2. Validate the splice (§5.1).
3. Compute the new markdown.
4. Insert the `SourceEdits` row.
5. Bump `content_revision`.
6. Migrate the marker and the soft position.
7. Migrate extract ranges; re-hash the overlapping ones; set `provenance_state`.
8. Delete and re-derive `Blocks`.
9. Recompute `content_hash` and `word_count`.
10. Append the activity event; `advanceGeneration()` on the transfer repository.

**[Invariant]** Steps 4–9 are atomic. A crash leaves the previous revision wholly intact, never a half-migrated one.

### 10.3 Extracts of extracts

An extract's provenance may name another extract as parent, and extract text is editable. **[Normative]** `EditExtractText` produces a splice against the parent extract's markdown and runs §6 and §7 over its **children**, with `Extracts.markdown` playing the role `Sources.markdown` plays for a source.

**[Deferred]** A per-extract edit journal. Extract edits record only the resulting state plus the migration outcome; extract undo is out of scope for this contract.

---

## 11. Editing surface

**[Normative]** Editing is **block-scoped**. Activating a block replaces it with a plain text field containing that block's `raw` markdown. Committing produces a splice of exactly `[block.startUtf8, block.endUtf8)`.

**[Rationale]** Three properties fall out at once. The splice is exact and free — no diffing, because the bounds are known before the user types a character. The virtualized list is untouched, so a 50k-word document does not have to be materialized to edit one paragraph. And a full rich-text editor — the component that consumes most of the budget of projects like this, and produces most of their position bugs — is never built.

**[Normative]** While a block is in edit mode, its rendered form is replaced by raw markdown, and *only* that block's. Every other block on screen keeps rendering images and tables normally.

**[Normative]** Extraction is disabled inside a block being edited. A selection made before entering edit mode is discarded on entry, not carried across.

**[Normative]** After a commit, the reader restores scroll from the **migrated soft position**, not from the block index. Re-derivation may change the block count, so an index-based restore lands in the wrong place exactly when the edit was large.

**[Invariant]** Editing never touches a schedule. It does not count as an encounter, does not advance an interval, does not move a due date, and does not write a `RevlogEntry` or a `SchedulerEvent`.

---

## 12. Images

**[Normative]** Assets are resolved **at import**, never during reading: relative paths are read from disk and remote references are fetched once. A failure records `state = missing` or `failed` and import proceeds.

**[Rationale]** A read-time fetch makes reading depend on the network, stalls a virtualized list mid-scroll, and breaks the local-first guarantee the whole app is built on.

**[Normative]** An inline image renders as a `WidgetSpan` sized from the stored intrinsic dimensions, scaled to the column measure, preserving aspect ratio.

**[Invariant]** The space an image occupies on screen is known **before** its bytes are decoded. A missing or failed asset renders a placeholder of the **same** dimensions.

**[Rationale]** The reader mounts only the blocks currently on screen. A block whose height changes after mount makes `scrollable_positioned_list` mis-estimate, and the page jumps under the user's cursor — the single most common way a reader with images comes to feel broken.

**[Normative]** A block whose content is a single image renders centred, with the alt text as a caption. Extraction over a range containing an image yields markdown containing the `![alt](src)` text verbatim; the extract records the asset ids it references so the asset survives deletion of the source.

**[Deferred]** Image occlusion. The `SourceAssets` shape is chosen so that occlusion cards need only a rectangle list on the card, not a new asset model.

### 12.1 Bounds

**[Normative]** `kMaxAssetBytes` (default 32 MiB) and `kMaxAssetsPerSource` (default 2000). Exceeding either records `state = failed` for the offending asset; it never fails the import.

---

## 13. Tables

**[Normative]** A table block stores a cell map (§9.5): each cell is a UTF-16 span into the block's `raw`. Cells are content; pipes, alignment rows, and padding are not.

**[Normative]** Read mode renders a real grid, one `Text.rich` per cell, each built through the same span builder as a paragraph, so inline emphasis, links, and images work inside cells.

**[Normative]** Selection within a cell behaves normally. A selection spanning cells **snaps outward to whole cells**, and extraction of such a range yields the covered rows as valid markdown.

**[Normative]** Edit mode for a table block is the raw pipe markdown, unchanged from §11. **[Deferred]** A structured table editor.

**[Normative]** A ragged table — rows with differing cell counts, escaped pipes (`\|`), or a missing alignment row — renders with the missing cells empty and **never** throws. Parsing a malformed table degrades to a paragraph rather than failing the document.

---

## 14. Selection

**[Normative]** The hand-written selection machinery in `reader_selection.dart` is replaced by Flutter's `SelectionArea`, with a `SelectionContainer` per block reporting the rendered-space range it covers. Rendered offsets are converted to document offsets through `ReaderCoordinates` (§3).

**[Rationale]** Word-, paragraph-, and keyboard-selection, drag auto-scroll, and cross-widget selection are all required for a reader with tables and images, and all already implemented, correctly, in the framework. The current code carries a widened drag threshold specifically to work around ordinary hand tremor producing stray one-character highlights — a symptom of hand-rolling gesture arithmetic that the framework does not have.

**[Invariant]** A selection that spans blocks, crosses an image, or covers whole table cells produces a **contiguous document byte range**. Selection never yields a range the extraction path cannot slice.

---

## 15. Conditions the reader must survive

**[Normative]** Each of the following has a named test. This list is the acceptance surface of this contract.

**Splice geometry**

1. Insert at offset 0; insert at end of document.
2. Delete-only; insert-only; replace.
3. Splice wholly inside one block; splice spanning many blocks.
4. Splice that empties the document; edit of an already-empty document.
5. Splice that deletes the blank line between two blocks (merge); splice that adds one (split).
6. Document with no trailing newline; document that is only whitespace.
7. No-op splice — rejected, revision unchanged.
8. Splice at `kMaxSpliceBytes`, and one byte over.

**Encoding**

9. Emoji, CJK, and combining marks immediately either side of both splice bounds.
10. A surrogate pair straddling a block boundary.
11. Inserted text containing CRLF — normalized before measurement.
12. An offset landing mid-character is rejected, never rounded.

**Positions**

13. Marker before, inside, and after the splice — the three §6 rules.
14. Insertion exactly at the marker offset — the marker does not jump it (`left` gravity).
15. Insertion exactly at a provenance start, and at a provenance end — the range does not grow.
16. Deleting the block containing the marker.
17. Deleting text five extracts came from — all five go `stale` or `orphaned`; none loses its text, schedule, or priority.
18. An anchor stamped with an older revision resolves correctly via replay.

**Structure**

19. Editing one block in a 900-block document leaves every other position byte-correct.
20. An edit that changes the block count, followed by a scroll restore.
21. An extract of an extract, whose parent extract is then edited.

**Assets and tables**

22. Missing image file at read time — placeholder of identical size, no layout shift.
23. Identical image bytes referenced by two sources — one file, two rows; deleting one source keeps the file.
24. Ragged table, escaped pipes, missing alignment row.
25. An image inside a table cell.

**Failure and concurrency**

26. Crash mid-edit — the previous revision is wholly intact.
27. Two windows editing the same source — the second fails with `ConflictFailure`, nothing written.
28. Undo of an edit restores byte-identical markdown and byte-identical positions.
29. A re-sent edit command with a known `operationId` — applied exactly once.

---

## 16. Invariants

Consolidated. A violation is a bug regardless of test status.

1. Document space is the only persisted coordinate space.
2. No persisted row outside `Blocks` references a block id.
3. Source text changes only through a validated `TextSplice`.
4. Position migration is total, deterministic, and heuristic-free.
5. Every persisted offset lies on a UTF-8 character boundary.
6. An edit never changes an extract's text, schedule, priority, or lifecycle.
7. An edit never reads or writes a scheduling column, a revlog entry, or a scheduler event.
8. `SourceEdits` is append-only; undo appends an inverse splice.
9. Block rows are a disposable derived cache, rebuilt wholesale after every splice.
10. An image's on-screen size is known before decode.
11. A malformed table or a missing asset degrades; it never throws and never fails the document.
12. Selection always yields a contiguous document byte range.
13. Steps 4–9 of §10.2 are atomic.

---

## 17. Tests

Layered to match the existing suite.

### 17.1 `test/domain` — pure

**[Normative]** The load-bearing property test:

> Generate a random document (mixed block types, multi-byte characters, images, tables). Generate a random sequence of random splices. After each splice, assert that every tracked position still points at the **same characters** it pointed at before — except positions strictly inside a removed region, which must be marked stale and must **never** be silently relocated.

**[Normative]** A round-trip property test over `ReaderCoordinates`: for every index in every space, converting down the chain and back is the identity; every `WidgetSpan` consumes exactly one rendered index.

Plus unit tests for each row of the §6 table, each gravity case in §4.1, and each validation rule in §5.1.

### 17.2 `test/application`

`AppHarness` against an in-memory database: transaction ordering, idempotency replay, `ConflictFailure`, undo round-trip, extract-of-extract migration.

**[Normative]** One test asserts that a serialized snapshot of every scheduling row is **byte-identical** before and after a source edit. This is the mechanical guard on invariants 6 and 7.

### 17.3 `test/data`

The v7 → v8 migration, seeding the **v7 schema explicitly** — `Migrator.createAll` builds current tables, so stamping `user_version = 7` over them tests a schema that never existed. Cover the orphan path of §9.6 step 5.

### 17.4 `test/widget`

Goldens per block type in both themes; image placeholder sizing; ragged table; block edit enter, commit, and cancel; selection across a block boundary, an image, and table cells.

### 17.5 `integration_test`

One native Windows workflow: import a document with images and tables → extract → edit the source above the extract → confirm the marker, extract text, schedule, and priority all survive → undo → confirm byte-identical.

---

## 18. Delivery phases

Each phase ends with the app fully working. No phase leaves a half-migrated coordinate system.

| # | Phase | Gate |
|---|---|---|
| 1 | `ReaderCoordinates` façade over the existing scheme; every call site routed through it | Round-trip property test green; no behaviour change |
| 2 | Document-space anchors, schema v8, data migration; blocks become a cache | Migration tests green; §15 items 13–19 green with no editor yet |
| 3 | `TextSplice`, `SourceEdits`, migration, staleness, undo | §15 splice, encoding, and failure items green |
| 4 | Block-scoped editing UI | Widget and integration tests green |
| 5 | Images: assets, import resolution, `WidgetSpan` rendering | §15 items 22, 23, 25 green |
| 6 | Tables: cell map, grid rendering, cell-snapped selection | §15 items 24, 25 green |
| 7 | `SelectionArea` migration; delete the hand-rolled selection code | Full §15 green |

**[Normative]** Phases 1 and 2 ship before any editing UI exists. The coordinate rewrite is the correctness work; the editor is the feature. Building the editor first means shipping the §2 defect to a user who is now typing.

---

## 19. Out of scope

**[Deferred]**, deliberately, so they are not improvised:

- Syntax highlighting for code blocks, and math rendering. Excluded by the product owner.
- A rich-text (WYSIWYG) editor.
- A structured table editor.
- Automatic re-anchoring of stale provenance.
- Image occlusion cards.
- Per-extract edit journalling and extract undo.
- Formats other than Markdown (EPUB, HTML, PDF). When added, they convert **at import**; the reader continues to read Markdown only, and this contract does not change.
- Multi-block extraction and the knowledge tree — those remain M5 scope in `plans/Plan.md`.
