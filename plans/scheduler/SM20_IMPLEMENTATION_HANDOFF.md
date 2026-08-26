# SM20 AIO scheduler implementation handoff

## Status

- Estimated overall progress: **~97% complete**.
- Updated: 2026-08-26, Europe/Berlin.
- Workspace: `D:\claude\Incremental Reader`.
- Git branch: `main`. Starting HEAD: `122a600`.
- Nothing has been committed. The worktree is intentionally dirty and holds the
  whole implementation. **Do not reset, checkout, clean, or discard it.**

Verification as of this update:

```text
flutter analyze          No issues found!   (whole project, not just lib)
flutter test             429 tests, all passing
git diff --check         no whitespace errors (CRLF notices only)
```

## What "97%" means

Sections 3 through 15 of `SM20_AIO_SCHEDULER.md` — the entire algorithm — are
implemented and covered. What remains is section 16 item 12, the copied-
collection byte comparison, which needs a live SM20 run and has been
deliberately deferred: this app stores its data in SQLite and does not import
SM20 collections, so a byte-for-byte file diff would validate a file format
nothing here reads. Every other conformance item is reachable from the
specification's own vectors and is covered.

## Non-negotiable user constraints

1. Fully implement `plans/scheduler/SM20_AIO_SCHEDULER.md` in the main app,
   including all scheduler options and settings.
2. Scheduler evidence is limited to `SM20_AIO_SCHEDULER.md`,
   `plans/sm20_binary/sm20.exe`, and the two collections under
   `plans/sm20_binary/systems`.
3. Do not use internet information for scheduler behavior.
4. Do not preserve the old scheduler or add compatibility shims.
5. `plans/Plan.md` predates the recovered algorithm. Where it disagrees with
   `SM20_AIO_SCHEDULER.md`, the specification wins and the Plan.md idea is
   removed rather than kept alongside.
6. The user asked for a progress percentage in every work update.

## Evidence recovered from the binary and collections

Two collections created independently by the executable ship a byte-identical
`info/sm8opt.dat`. Its first 800 bytes are the 20 by 20 interval-factor matrix
Mercy needs, which makes the starting table a property of the program rather
than of one collection. Outside column zero every cell satisfies
`round_even(1000 * (1.2 + 0.3 * row / column))` evaluated in float64. This is
now `Sm20MercyMatrix.sm20Default`, and Mercy falls back to it instead of
refusing to run. Section 12.1 of the specification was updated to record it.

Parsing `info/ElementInfo.dat` with the port's own Real48 reader confirmed
every section 4.1 offset on real records, established the 118-byte record
stride, and showed type `4` on the collection root. `info/priority.sub` lists
the dismissed root among the ranked elements, confirming that dismissed
elements keep their rank. Sections 4.1 and 16 were updated with all of this.

`test/domain/scheduling/sm20_collection_fixture_test.dart` reads those files
directly, so the port is checked against the executable's own bytes.

## Production bug found and fixed

`ReaderHandlers.completeEncounter` ran under the idempotency kind
`topic.encounter_completed` but wrote its activity row under the domain event's
own kind, `topic.repetition_committed`. The guard therefore never matched and
**every retried Done committed a second repetition**, drawing from the shared
PRNG again and advancing the schedule twice. Both sides now use
`kTopicEncounterCompletedKind`, and the event name moved into the row's
metadata. `m4_time_and_recovery_test.dart` covers it.

## Completed implementation

Everything below is implemented, analyzed clean, and covered by tests.

- **Numerics** (`sm20_numeric.dart`): nearest-even rounding, exact Real48
  encode/decode, the global Delphi PRNG including seed-zero and `Random(N)`,
  the two-draw interval spread, and the executable's heap/tie behavior.
- **Topic scheduler** (`topic_scheduler.dart`): the full executable-visible
  record, blank-topic and text-length A, ordinary and forced interval
  selection, A adaptation, priority drift, Remember, forced repetition,
  low-level reschedule, Delay Element, Jump/Reschedule, Later Today, Forget,
  Dismiss, Undismiss, Done, Reset History, Set A and Modify A.
- **Priority** (`priority_rank.dart`): the shared intact population, exact
  remove/reinsert Set Priority, nearest-even position conversion, review drift
  with forced one-rank movement, the current-element `±0.1` shortcut, and all
  four browser batch operations.
- **Queues** (`queue_policy.dart`): Outstanding stores, the exact priority key
  and heap order, the item and topic randomization curves and draw counts, the
  attempted-counter merge ratio, once-per-day automatic sort, the separate
  Outstanding, Final Drill and Pending stages, and fixed-range Final Drill
  randomization.
- **Smart and automatic postponement** (`sm20_postpone.dart`): the exact pure
  engines, both entry points sharing one candidate projection, write-free
  simulation, and the automatic gates. Wired to the queue and to the priority
  browser for global and branch scopes.
- **Mercy** (`mercy.dart`): the interval-factor matrix, fixed FI-bin
  investment, the five-part score, all four ordering modes, item-then-topic
  gathering, reverse-within-day assignment, and both capacity solvers.
- **Browser learning commands** (`browser_handlers.dart`): Learn, Review all,
  Review topics, Remember, Forget, Dismiss, Undismiss, Done, Add to Final
  Drill, Add to Outstanding and Add all with their spacing and `0.9` priority
  target, Reset History, Set A, Modify A, and Advance.
- **Settings**: study day, queue, Remember, cards, automatic postpone plus
  every Default Smart Postpone field, named profiles with branch assignments,
  Mercy, reader and diagnostics.
- **Database**: schema version 9. The retired adjustment and presentation-plan
  tables are dropped, deferral columns are gone, and lifecycle indices were
  renumbered for the three remaining states.

## Removed, not deprecated

The capacity valve, Study More, the deferral/effective-due overlay, the
presentation plan, the schedule-adjustment service and codec, the scheduler
simulation gate (`tool/`), `overload.dart`, `deterministic_random.dart`,
`interval_profile.dart`, and the Suspend and Finish lifecycle commands.

Suspend and Finish already funnelled to `Sm20ElementStatus.dismissed`, so
removing them changed vocabulary rather than behavior: `ReactivateElement`
became `UndismissSource`, and `ElementLifecycle` is now active, dismissed and
deleted only.

## Test suite

All ten obsolete files are resolved. `a_factor_scheduler_test.dart` was deleted
outright — it tested `topic_afactor_v1`, which no longer exists.
`topic_scheduler_test.dart` and `queue_policy_test.dart` were rewritten around
sections 5, 9 and 16. The valve and Study More groups of
`m4_queue_admission_test.dart` were removed as tests of a scheduler this app no
longer has. The rest were migrated to canonical-due semantics.

Two recurring causes of failure are worth knowing, because they will catch the
next person too:

- A freshly imported source or formulated card is **Pending** in SM20 and never
  joins Outstanding. Queue and Mercy fixtures must study their elements first.
- Mercy gathers from the collection learning-start day, which is stamped the
  first time the queue is opened. A fixture that never opens the queue gathers
  nothing.

## Remaining work

1. **Section 16 item 12** (deferred by decision): byte-compare a copied
   collection after one operation in SM20. Needs a live SM20 run and a
   collection with real repetition history; both shipped collections are
   effectively unstudied.
2. **A live Mercy matrix.** The default is SM20's fresh-collection table. A
   real collection refines those numbers as it is used; this app does not yet.
   Mercy's investment term is therefore a starting estimate — one of five
   weighted inputs, not a precision quantity.
3. **Manual verification.** Start the app and walk Settings, the Priority
   Browser, the Study Queue, Smart Postpone simulation and real run, and Mercy
   preview/apply/undo, then restart and confirm the PRNG seed, queues and
   profiles survive.

## Important implementation cautions

- One persisted Delphi PRNG stream is shared by topic intervals, extraction,
  queue randomization, Smart Postpone, Advance, Final Drill randomization, and
  Mercy mode 3. Never create feature-specific seeds.
- Real48-round at every specified store and intermediate boundary.
- Smart/Auto Postpone and Mercy are low-level reschedules, not reviews. Never
  change A, priority, repetitions, lapses, or train FSRS from them.
- Pending and Final Drill are fallback phases, never injected into the mixed
  Outstanding queue.
- Priority is one intact collection-wide rank population that includes
  dismissed elements. Batch operations are sequential remove/reinsert
  algorithms, not frozen vector transforms.
- Smart Postpone modifier checkboxes are intentionally inert where the binary
  does not read them.
- Do not resurrect a capacity ledger, overload valve, Study More adjustment,
  presentation plan, or effective-due overlay.
