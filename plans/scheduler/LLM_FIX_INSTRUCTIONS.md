# Authoritative Scheduler Specification for an AI Coding Agent

Status: **normative implementation contract**

Audience: an AI coding agent modifying this repository

Purpose: provide the single complete, safe, and testable scheduler implementation target for a SuperMemo-like incremental reader that uses FSRS for cards.

---

## 1. Read this before changing code

Treat this file as the only scheduling implementation authority for:

- cards and FSRS;
- sources and extracts;
- priority ordering;
- queue construction;
- Later, auto-postpone, sibling burying, and Mercy;
- study-day boundaries;
- event history and undo;
- scheduler statistics and migration.

When another plan or existing implementation conflicts with this document, this document wins for scheduler behavior. The only companion scheduler document is `ARCHITECT_GUIDE.md`, which explains this contract in plain language but does not override it.

Precedence:

1. This file for scheduling behavior and scheduler data invariants.
2. `ARCHITECT_GUIDE.md` for rationale, calibration status, and architect-facing explanations.
3. `plans/Plan.md` for product behavior outside scheduling.
4. `plans/IR.md` as historical context only.

Do not copy pseudocode from the older documents without checking it against the invariants below.

### Current repository warning

At the time of this consolidation, the application code and tests still contain the retired `topic_afactor_v1` behavior. In particular, search the database defaults, `lib/src/domain/scheduling/topic_scheduler.dart`, generated schema code, and scheduler tests for `topic_afactor_v1`, priority-derived first intervals, “new source eligible today,” and auto-finish assumptions.

A green pre-existing suite proves compatibility with that legacy implementation, not conformance to this contract. Update schema, migrations, domain code, generated artifacts, and tests together through the migration sequence in section 17; do not simply rename the policy string or reinterpret already-stored schedules.

### Fidelity labels

Use these labels in code comments, decision records, and future plan changes:

- **[SM documented]**: directly stated in official SuperMemo documentation.
- **[SM20 observed]**: reproduced in the controlled SuperMemo 20.00.33.64 fixtures described in this document.
- **[Empirical formula]**: a formula that exactly matches the controlled fixture dataset but is not published as source code by SuperMemo.
- **[Derived]**: a straightforward implication of documented behavior, but the exact formula is not published.
- **[Product decision]**: a transparent choice made for this application.
- **[Unknown]**: proprietary or undocumented behavior that needs black-box observations before it can be reproduced.

Never present a Product decision as an exact SuperMemo algorithm.

---

## 2. Target architecture

The product has two different scheduling engines and one presentation stream.

| Element | User action | Canonical scheduler | Canonical time |
|---|---|---|---|
| Card | Grade Again, Hard, Good, or Easy | FSRS | exact UTC instant |
| Source | Done / Next repetition after an intentional encounter | priority/A-Factor topic policy | local StudyDay |
| Extract | Done / Next repetition after an intentional encounter | same topic policy as sources | local StudyDay |

An extract is a topic with a parent and provenance. It is not a card.

Cards and topics must remain separate internally even though the user sees them interleaved in one study screen.

### Non-goal

This is a behavioral SuperMemo-like hybrid, not a byte-for-byte clone:

- FSRS deliberately replaces SuperMemo's proprietary item algorithm.
- Some SuperMemo topic behavior remains private, including natural-encounter interval rounding, later A-Factor transitions, priority drift, Mercy scoring, and randomization.
- The plain-text clipboard topic A-Factor initializer and global priority-percent formula have now been recovered empirically for the tested SuperMemo build.
- Undocumented behavior must be isolated behind versioned policies so it can be calibrated later without corrupting stored schedules.

---

## 3. Resolve the current plan conflicts exactly this way

### 3.1 Topic scheduler

Use one canonical topic scheduler for new sources and extracts:

**topic_afactor_v2**

Do not mix fixed interval sequences with interval-times-A behavior on the same topic.

Existing data created with a fixed sequence may keep a scheduler kind such as **legacy_sequence**. Preserve its current due date, interval, and step. Migration to topic_afactor_v2 must be explicit, previewed, and versioned.

### 3.2 Topic creation and initial schedule

**[SM20 observed]** A newly created ordinary topic has a one-day interval and is scheduled for the next StudyDay. Creation is not a repetition and must not append a `topic_encountered` event.

- A blank topic created through the blank-note path starts with A-Factor `1.2`.
- A plain-text clipboard topic uses the recovered UTF-16 length initializer in section 8.
- Pasting or editing text after blank-topic creation does not recalculate A-Factor.
- A root concept is rankable but begins unscheduled, with no interval and ordinal `0` in the observed build.
- Until extract creation is calibrated, new extracts use the explicit product fallback in section 8; do not claim that fallback is exact SuperMemo behavior.

The imported topic may remain visible as the result of the creation command, but ordinary queue eligibility begins when its next StudyDay is due. Do not fabricate an encounter merely because creation displayed it.

### 3.3 Priority and intervals

- Card priority never changes FSRS state, stability, difficulty, desired retention, last review, or algorithmic due.
- Absolute topic placement through the priority dialog changes only the relative priority order. In the controlled fixtures it did not change A-Factor, current interval, or algorithmic due.
- SuperMemo's separate Increase/Decrease commands are documented to couple priority and topic A-Factor, but their exact transition is not yet recovered. Keep that operation behind its own versioned policy.
- Editing priority must never retroactively rewrite the current algorithmic due date or current interval.

### 3.4 Session capacity

Use count-based capacity, not a time-budget scheduler.

Durations must still be recorded and reported, but time estimates do not decide the default queue.

### 3.5 Card/topic mix

Use a default target of four card opportunities for every one topic opportunity.

Also use a configurable starvation guard: when both streams remain nonempty, do not allow more than eight ordinary card opportunities without a topic opportunity. Mandatory intraday card steps may temporarily break the ratio.

The four-to-one pattern is a target, not five reserved slots. If one stream is empty, consume the other.

### 3.6 Finishing topics

Never auto-finish a source merely because its cursor reached the end.

Require an explicit Finish action. A nonblocking suggestion is allowed. Closing, navigating back, crashing, extracting, editing, or reaching the final paragraph is not Finish.

Default to dismiss rather than destructive deletion. Deletion must preview affected descendants and review history, must never silently cascade, and must retain enough immutable provenance/reference snapshot for surviving extracts and cards to explain their origin.

### 3.7 Sibling handling

Implement sibling handling as a typed, configurable presentation adjustment. It must never alter FSRS memory state.

Keep it feature-flagged during migration if the current product contract says it is out of v1. Do not delete the model merely because the first UI release hides the setting.

### 3.8 Statistics

Operational scheduler statistics are required. They are safety instrumentation, not optional analytics.

---

## 4. Non-negotiable invariants

Implement tests for these before changing scheduling behavior.

1. Only a genuine graded card review changes canonical FSRS memory state.
2. Creation may initialize a topic's interval and algorithmic due exactly once; afterward, only a completed, idempotent topic encounter changes canonical topic interval or algorithmic topic due.
3. Later, auto-postpone, Mercy, sibling burying, practice, priority edits, suspend, resume, and manual rescheduling do not masquerade as reviews.
4. The algorithmic due is stored separately from presentation adjustments.
5. Exact card timestamps are UTC instants. Topic dates are local StudyDays.
6. Eligibility is evaluated before ranking.
7. A random presentation jitter never changes stored priority.
8. The same queue inputs produce the same queue plan.
9. Rebuilding a queue cannot progressively postpone elements or append duplicate events.
10. Due learning and relearning steps are mandatory and are not automatically postponed.
11. New cards never displace already-due review cards.
12. Protected high-priority work is never automatically postponed.
13. Practice does not change scheduling state or consume ordinary admission capacity.
14. Undo appends an inverse/tombstone event; it does not physically delete history.
15. Every state-changing operation has an idempotency/operation ID.
16. Every scheduler result records the scheduler and policy versions that produced it.
17. Existing schedules are never silently reinterpreted by a new formula.
18. A card cannot have both topic state and FSRS state.
19. A source or extract cannot have FSRS state.
20. A lifecycle change to a parent does not silently mutate descendants.

---

## 5. Vocabulary and independent coordinates

Do not overload one field to represent several concepts.

- **ID**: immutable database identity.
- **Priority order key**: canonical location in the global relative priority order.
- **Priority position**: one-based rank derived from the order key.
- **Priority percent**: zero at the top and one hundred at the bottom, derived from rank.
- **Ordinal**: separate, user-visible/pending-order metadata. It is not identity, priority, or due date.
- **Algorithmic due**: date/time produced by FSRS or the topic scheduler.
- **Schedule adjustment**: a presentation-only calendar constraint or override.
- **Effective due**: the date/time used to decide whether the element may be shown.
- **Eligibility**: whether lifecycle, due, adjustment, and scope rules allow an element into a candidate lane.
- **Ranking**: ordering among already-eligible candidates.
- **Admission**: selecting eligible candidates under a cap.
- **Presentation plan**: deterministic interleaving of admitted lanes.
- **StudyDay**: a local learning day using the configured home timezone and rollover, default 04:00.
- **Genuine topic encounter**: the user explicitly confirms Done/Next repetition for a source or extract.

Never use ordinal as a tie-breaking substitute for immutable ID unless that behavior is a deliberate pending-queue feature.

---

## 6. Required data model

Adapt names to the repository's language and ORM, but preserve these boundaries.

### 6.1 Common element

~~~text
Element
  id
  kind: concept | source | extract | card
  parentElementId?
  rootSourceId?
  priorityScopeId
  priorityOrderKey
  ordinal?
  lifecycle: active | suspended | dismissed | finished
  createdAtUtc
  updatedAtUtc
  revision
~~~

Rules:

- Use one parent relation.
- Do not keep separate source-parent and extract-parent foreign keys on cards.
- rootSourceId is denormalized provenance and survives source dismissal or orphaning.
- `priorityScopeId` identifies the collection/dataset whose relative order contains the element. “Global priority” means one order across all element types inside this scope, not one order spanning unrelated user collections.
- Enforce uniqueness/order-key invariants within `priorityScopeId`; every priority query and move must supply the scope explicitly.
- Concepts, including the collection root, are rankable elements even when they have no schedule.
- Only sources, extracts, and cards are normally schedulable. A concept receives topic schedule state only if the product explicitly makes that concept learnable.
- The observed priority dialog displayed A `1.2` for an unscheduled root concept. Treat that as a type/default UI value, not proof of `TopicSchedule`: without an interval and due date it has no canonical topic schedule. If the product must preserve it for round-trip import, store it as separate legacy/diagnostic metadata.
- Pure folders and UI-only tree nodes that are not elements are neither rankable nor schedulable.

### 6.2 Topic schedule

~~~text
TopicSchedule
  elementId UNIQUE
  schedulerKind: legacy_sequence | topic_afactor_v2
  schedulerVersion
  creationMode: blank_topic | clipboard_plain_text | web_import | extract | clone | legacy
  aFactorInitializerVersion
  initialTextUtf16Length?
  algorithmDueStudyDay
  currentIntervalDays?
  currentAFactor?
  encounterCount
  lastEncounterStudyDay?
  policyInputSnapshot?
  revision
~~~

### 6.3 Card schedule

Persist every canonical field required by the pinned FSRS library. Do not recreate missing state with application guesses.

~~~text
CardSchedule
  elementId UNIQUE
  fsrsState
  algorithmDueAtUtc
  lastReviewAtUtc?
  stability?
  difficulty?
  scheduledDays?
  reps
  lapses
  schedulerName
  schedulerVersion
  parameterSetId
  revision
~~~

Pin the FSRS package and parameters. The current plan target is:

- Dart fsrs package 2.0.1;
- desired retention 0.90;
- learning steps 1 minute and 10 minutes;
- relearning step 10 minutes;
- fuzzing enabled for eligible long intervals;
- maximum interval 36,500 days unless the actual library imposes a safer supported bound.

If the installed library API differs, write an adapter and reference-vector tests. Do not scatter library calls through UI code.

FSRS fuzzing must be reproducible under retry and replay. Inject a deterministic seed if the library supports it, derived from stable inputs such as element ID, genuine review operation ID, scheduler version, and parameter-set ID. If the library does not expose its RNG, persist the exact returned fuzzed due/result inside the idempotent transaction and return that stored result on retry. Run pinned mathematical reference vectors with fuzzing disabled or with an explicitly fixed seed.

### 6.4 Schedule adjustments

A simple deferral table is insufficient because Mercy and manual rescheduling can move work earlier as well as later.

~~~text
ScheduleAdjustment
  id
  elementId
  mode: lower_bound | exact_override
  reason:
    manual_later
    auto_overflow
    sibling_bury
    mercy
    manual_reschedule
  notBeforeAtUtc?
  notBeforeStudyDay?
  scheduledForAtUtc?
  scheduledForStudyDay?
  operationId
  batchId?
  policyVersion
  createdAtUtc
  createdStudyDay
  clearedAtUtc?
  clearedByOperationId?
~~~

Validation:

- lower_bound has exactly one not-before value in the correct time domain;
- exact_override has exactly one scheduled-for value in the correct time domain;
- cards cannot mix a StudyDay field with an exact-UTC field when the operation is intraday;
- topics use StudyDay fields;
- only one active exact override per element and scheduling domain;
- multiple lower bounds may coexist.

Effective due:

~~~text
candidate_due = active_exact_override.scheduled_for
                if one exists
                else algorithmic_due

effective_due = max(candidate_due, every active lower_bound.not_before)
~~~

Adjustment precedence:

- Manual Later adds a lower bound.
- Auto-postpone upserts an auto_overflow lower bound.
- Sibling burying adds a sibling_bury lower bound.
- Mercy creates/replaces an exact mercy override for selected elements.
- Mercy clears conflicting auto_overflow adjustments in its batch.
- Mercy preserves manual Later by default unless the confirmation explicitly says to override it.
- An element with an active exact manual reschedule is excluded and flagged in Mercy preview by default. Replacing it requires explicit confirmation; the batch must retain the complete prior adjustment so exact undo restores it.
- Study More clears only applicable auto_overflow adjustments.
- A genuine card review or topic encounter clears adjustments made obsolete by the new canonical schedule.

Never overwrite algorithmic due merely to make an element disappear from today's queue.

### 6.5 Append-only events

Use distinct event types for:

- card_reviewed;
- card_review_undone;
- practice_reviewed;
- topic_encountered;
- priority_changed;
- manual_later_set and cleared;
- auto_overflow_set and cleared;
- sibling_buried and cleared;
- mercy_previewed, applied, and undone;
- manual_reschedule_set and cleared;
- suspended, resumed, dismissed, restored, and finished.

Each canonical transition event must contain:

~~~text
eventId
operationId
elementId
eventType
occurredAtUtc
studyDay
schedulerName
schedulerVersion
policyVersion
stateBefore
stateAfter
algorithmicDueBefore
algorithmicDueAfter
adjustmentsBefore
adjustmentsAfter
undoesEventId?
metadata
~~~

The optimizer may consume only genuine, non-practice, non-undone card reviews.

### 6.6 Daily presentation plan

Persist or cache a plan identity containing at least:

~~~text
studyDay
policyVersion
settingsRevision
datasetGeneration
candidateRevision
deterministicSeedVersion
~~~

An identical identity must return an identical remaining plan. Completion removes entries from the active plan without reshuffling all remaining work.

---

## 7. Relative priority implementation

### 7.1 Canonical representation

Store a sortable fractional `priorityOrderKey` inside an explicit `priorityScopeId` and use immutable element ID as the final tie-breaker.

Derive rank and percent; never store percent as authoritative:

~~~text
position = one_based_rank(
  partition by priorityScopeId
  order by priorityOrderKey, elementId
)

if total <= 1:
    priority_percent = 0
else:
    priority_percent = 100 * (position - 1) / (total - 1)

p = priority_percent / 100
~~~

This guarantees:

- first position is exactly 0%;
- last position is exactly 100%;
- p equals zero at the top and one at the bottom.

Priority percent is a derived, discrete display value. For a population of `total = N`, the only representable values are:

~~~text
{ 100 * k / (N - 1) | k = 0 .. N - 1 }
~~~

For example, two topics plus a root concept produce three ranks: `0%`, `50%`, and `100%`. Three topics plus the root produce `0%`, `33.333...%`, `66.666...%`, and `100%`. Never store an arbitrary percentage as though it were independent state.

### 7.2 Rankable population

**[SM documented, SM20 observed]** Within one collection/dataset priority scope, the global rankable population contains every non-deleted element: concepts, sources, extracts, and cards. The observed root concept occupied a real queue position and changed every topic's displayed percentile even though the root itself had no initial schedule.

Inactive elements retain their order keys. Pure folders and UI-only nodes that are not elements are excluded.

Eligibility still excludes suspended, dismissed, and finished elements.

Keep the population policy in one versioned service so it can be changed through a deliberate migration if SuperMemo observations prove different.

### 7.3 Moves and insertion

- A user move is transactional.
- Treat a requested percent as a request for an insertion rank. Map it to the nearest legal integer position with one documented deterministic tie rule; keep that tie rule policy-versioned until the SuperMemo midpoint test is complete.
- Preview the element immediately above and below the proposed position. Calculate the preview after temporarily removing the moving element so it cannot appear as its own neighbor.
- Insert with a midpoint key between neighbors.
- Rebalance a bounded key range transactionally when precision becomes insufficient.
- **[SM20 observed]** New clipboard topics in a fresh collection entered at position `1` and shifted existing elements downward. Use position `1` as the SuperMemo-like default for new imported topics unless a concept/category import policy supplies another insertion target.
- Extract insertion remains versioned and unverified; do not silently assume either parent adjacency or position `1` is exact.
- Later parent moves do not automatically drag descendants.
- Never persist daily jitter into order keys.
- Do not execute one rank-count query per candidate; compute ranks in one window query or one ordered pass.

### 7.4 What priority may affect

Priority may affect:

- order within eligible card and topic lanes;
- protection from automatic overflow;
- admission when capacity is limited;
- Mercy allocation within configured criteria bounds.

The separately named Increase/Decrease Priority operation may also change a topic's stored A-Factor through a versioned coupled-nudge policy. Absolute placement by position/percent does not.

Priority may not affect:

- card FSRS memory state;
- whether a not-yet-due element is normally due;
- actual review timestamps;
- review ratings;
- stored historical outcomes.

---

## 8. Topic scheduling

### 8.1 State transition

On a genuine, idempotent topic encounter:

1. Load the topic's stored current interval and stored current A-Factor.
2. Validate that A is finite and greater than `1.0`.
3. Compute the next interval with the topic's versioned interval transition.
4. Write lastEncounterStudyDay as the actual StudyDay.
5. Write algorithmDueStudyDay as actual StudyDay plus the new interval.
6. Append the full before/after event.
7. Clear obsolete schedule adjustments.

`topic_afactor_v2` uses this transparent provisional integer transition:

~~~text
next_interval_days = max(
  current_interval_days + 1,
  round(current_interval_days * A)
)
~~~

This transition is a **[Product decision] pending calibration**. The multiplication is documented; exact SuperMemo integer rounding, dispersion, anti-cramming, and internal A precision are not yet recovered. The plus-one guard prevents a rounded one-day interval from remaining one day forever. Replace it only through a new policy version after the retained three-collection natural-repetition fixtures establish the actual rule.

Require A to be finite and greater than 1.0. A safe technical floor is 1.01. Allow a manual exact reschedule when the user intentionally wants an earlier revisit.

An ordinary Done/Next repetition does not recompute A from priority or current text. It preserves stored A unless a separately logged, versioned topic-processing transition explicitly changes it.

### 8.2 Creation-time A-Factor initialization

#### Blank topic

**[SM20 observed]** A topic created blank starts with:

~~~text
current_interval_days = 1
current_A = 1.2
algorithm_due = creation_StudyDay + 1
~~~

Pasting short or long text into that existing topic leaves A at `1.2`. Root concepts also showed A `1.2`, but an untouched root had no interval and was not scheduled.

#### Plain-text clipboard topic

**[Empirical formula, SuperMemo 20.00.33.64]** For a topic created atomically from plain clipboard text:

~~~text
L = number of UTF-16 code units in the imported plain text
raw_A = 1.25 + 150 / (L + 200)
display_A = round(raw_A, 3)

current_interval_days = 1
algorithm_due = creation_StudyDay + 1
~~~

In JavaScript/Dart-style UTF-16 strings, use the UTF-16 code-unit count, not UTF-8 bytes or Unicode scalar values. The controlled fixtures produced identical A `1.625` for 200 ASCII code units, 200 precomposed `é` code units, and 100 emoji represented by 200 UTF-16 code units.

The exact three-decimal midpoint/tie rule is untested. Keep display rounding behind the initializer version rather than relying on a language's implicit rounding mode.

The formula matched every tested ASCII fixture after three-decimal display rounding:

| UTF-16 length | Displayed A |
|---:|---:|
| 15 | 1.948 |
| 71 | 1.804 |
| 263 | 1.574 |
| 1,031 | 1.372 |
| 8,000 | 1.268 |
| 16,391 | 1.259 |

Word boundaries did not matter: one 8,000-character word, thousands of one-letter words, and 1,000 ordinary words at the same total length all produced A `1.268`.

Persist `raw_A` with adequate precision and round only for display until natural-repetition fixtures establish whether SuperMemo itself stores the raw or displayed value. Never recalculate A merely because content is later edited.

An empty clipboard import was not tested. **[Product decision]** Reject the atomic clipboard-import command when normalized plain text is empty and route the user to blank-topic creation, which uses A `1.2`; do not apply the recovered formula to `L = 0` and claim it is observed behavior.

#### Other creation modes

Exact initializers for formatted HTML/web import, extract creation, split, and clone are still **[Unknown]**. Put each behind a distinct creation-mode policy. Until calibrated, use the following explicit **[Product decision]**:

- web/plain-text source: apply the UTF-16 formula to normalized visible plain text;
- extract: apply the same formula to extracted visible plain text and schedule it for the next StudyDay;
- formatted HTML: use normalized visible plain text and record both visible UTF-16 length and raw payload size;
- clone: copy A only when the user explicitly requests schedule cloning; otherwise reinitialize from the clone's visible text;
- never inherit the first sibling's A or silently derive A from the parent's current priority.

Changing any fallback requires a new initializer version and must not reinterpret existing topics.

### 8.3 Later A-Factor transitions

**[SM documented]**

- Topics are not graded like items.
- A topic's next interval grows from its previous interval using an A-Factor.
- Long imported texts start with lower A-Factors than short imported texts.
- Manual notes are initialized differently from clipboard imports.
- Increase/Decrease Priority, advance/delay, extraction, and other incremental-reading operations may modify a topic's A-Factor or priority.

**[Unknown]**

- the exact A transition for Increase/Decrease Priority;
- exact extraction, investment, manual-advance, manual-delay, and completion transitions;
- exact clamping, smoothing, and jitter;
- natural-encounter interval rounding and whether stored A has hidden precision;
- how the terms changed across SuperMemo versions.

Therefore:

- implement creation initialization and later A transitions as separate versioned interfaces;
- store policy version and enough input/output data for replay;
- keep constants in policy configuration, not scattered in UI or repositories;
- do not silently recalculate existing topic schedules after policy changes;
- provide an offline replay/simulation command before promoting a new version.

Do not implement the retired priority-derived formula `2.0 * (0.7 + 0.8 * percentile)`. Absolute Alt+P movements across the entire priority range left A unchanged in the controlled fixtures.

Completion, word-count yield, and extract-conversion multipliers from earlier designs are experimental:

- default them off;
- calculate and shadow-log them if the data is available;
- add zero-length and cold-start guards;
- promote them only after simulations and real telemetry show that they improve attention allocation without starving material;
- if promoted, create a new scheduler policy version.

### 8.4 Topic actions

| Action | Canonical schedule effect |
|---|---|
| Done / Next repetition | advance once |
| Later | lower-bound adjustment only |
| Custom reschedule | exact override only |
| Extract text | no topic advance |
| Formulate card | no topic advance |
| Edit or add context | no topic advance |
| Back, close, crash | no topic advance |
| Reach end of text | no topic advance |
| Finish | remove topic from eligibility; keep content and descendants |
| Dismiss | reversible removal; retain canonical interval |
| Suspend | temporary removal; retain canonical interval |
| Resume | restore eligibility according to explicit resume policy; do not fake an encounter |

Zero cursor movement does not invalidate an explicit encounter. The user may have reread, edited, extracted, or thought about a short topic.

---

## 9. FSRS card scheduling

### 9.1 Adapter boundary

All FSRS calls go through one adapter that:

- accepts the exact stored pre-state;
- accepts Again, Hard, Good, or Easy;
- receives actual now in UTC;
- uses pinned parameters and library version;
- returns the exact post-state and due instant;
- produces serializable reference-vector output for tests.

Atomically persist the state and event.

### 9.2 Genuine card review

On a grade:

1. Lock or compare-and-swap the card revision.
2. Load canonical FSRS state.
3. Pass the actual review instant, not original due or effective due, to FSRS.
4. Persist the exact returned state and algorithmic due.
5. Set lastReviewAtUtc to the actual review instant.
6. Append a complete before/after review event.
7. Clear obsolete adjustments.
8. Commit once.

Hard is a successful but difficult recall, not a disguised failure. Again is failure.

### 9.3 Operations that must not call FSRS

- Later;
- automatic overflow;
- Mercy;
- sibling burying;
- manual calendar reschedule;
- practice;
- suspend or resume;
- priority editing;
- queue rebuilding;
- undo preview;
- merely displaying a card.

For each operation above, acceptance tests must compare serialized FSRS state, lastReviewAtUtc, and algorithmic due byte-for-byte before and after.

### 9.4 New cards

- New cards enter a priority-ordered new pool.
- Admit them only after due review capacity is satisfied.
- Apply the daily new-card cap and remaining unique-card capacity.
- An unadmitted card remains New. Do not create a fake review or fake postponement.
- Do not seed stability from earlier source reading.
- Let the learner give an honest first grade.

### 9.5 Learning and relearning

- Due intraday steps are mandatory.
- They use exact UTC timestamps.
- They bypass unique-card admission caps after the card has been admitted.
- They appear at the next card opportunity when due.
- Auto-postpone and Mercy exclude them.
- An optional short Snooze is an exact-UTC lower bound, not a review.

### 9.6 Practice

Practice creates a practice event only. It does not alter FSRS, algorithmic due, last review, admission state, or optimizer data.

### 9.7 Siblings and new clozes

Multiple clozes from the same passage share a sibling group/provenance.

For review siblings:

- a same-day sibling bury is a sibling_bury lower bound to the next StudyDay;
- it does not change any sibling's FSRS due.

For multiple new siblings:

- limit same-day introduction according to a configurable policy;
- keep unintroduced siblings New;
- do not manufacture review history.

---

## 10. Queue construction

Build separate candidate lanes and merge only after eligibility, ranking, protection, and admission.

### 10.1 Candidate lanes

At minimum:

1. due learning/relearning steps;
2. protected due review cards;
3. regular due review cards;
4. available new cards;
5. protected due topics;
6. regular due topics.

Do not use one wide nullable query with one shared due field and one shared last-review field.

### 10.2 Eligibility

For every candidate:

1. verify lifecycle and selected scope;
2. compute effective due from canonical due plus active adjustments;
3. compare in the correct time domain;
4. exclude completed elements in the active plan;
5. only then calculate ranking.

### 10.3 Protection

Determine protected status from canonical priority before lateness correction or randomization.

Use a configurable protected cutoff. Resolve the current one-percent versus five-percent plan conflict by setting one explicit default:

**default protected top one percent**

Expose the setting and record it in the policy version. Never let random jitter push a protected element into the postponable set.

### 10.4 Ranking

Priority is dominant. Lateness may make an overdue element somewhat earlier inside a bounded priority neighborhood, but cannot invert the collection globally.

A safe shape is:

~~~text
rank_score = priority_fraction
             - bounded_lateness_shift
             + deterministic_jitter

bounded_lateness_shift is in [0, 0.05]
deterministic_jitter is in [-jitter/2, +jitter/2]
~~~

Sort `rank_score` ascending: smaller values appear earlier. Keep card and topic jitter/randomization as separate settings and include the lane plus its randomization-policy version in the seed. A fully randomized diagnostic/subset session, if later added, is presentation-only: it must use a replayable seed and must never rewrite priority, canonical due, or review history.

Use card retrievability/lateness for cards and days-late relative to interval for topics.

Seed jitter with stable inputs such as:

~~~text
datasetId, StudyDay, elementId, lane, policyVersion
~~~

Do not use fresh random values on each rebuild.

### 10.5 Admission

Recommended defaults are settings, not hard-coded truths:

- unique cards per StudyDay: 200;
- new cards per StudyDay: 20;
- topics per StudyDay: 50.

Rules:

- mandatory intraday steps bypass the unique admission cap;
- protected due work bypasses soft capacity if required to honor protection;
- regular due reviews fill remaining card capacity first;
- new cards enter only if no due review was excluded by the ordinary card cap;
- cards and topics have separate capacity ledgers;
- caps are maxima, not quotas.

### 10.6 Merge

Merge admitted ordinary lanes using a weighted fair pattern:

~~~text
C C C C T
~~~

Requirements:

- track opportunities, not total screen renders;
- dynamically inject currently due intraday steps at the next card opportunity;
- use a maximum ordinary-card gap of eight while topics remain;
- if one lane empties, continue with the other;
- persist the active pattern cursor so a restart does not reshuffle remaining work.

---

## 11. Later, Smart Postpone, auto-postpone, and Study More

These are distinct features. Do not use one ambiguous Postpone operation.

### 11.1 Later

Later is a manual, local choice for one element.

- It creates a manual_later lower bound.
- It never changes algorithmic due, interval, FSRS state, or last review.
- For a review-state card or topic, a transparent default may be twenty percent of the current scheduled interval, clamped to at least one StudyDay.
- For a New card, default to the next StudyDay.
- For learning/relearning, offer a short exact-UTC Snooze instead.
- A user-selected date replaces or extends the relevant manual lower bound.

### 11.2 Smart Postpone

Smart Postpone is an explicit command that chooses a later destination from future capacity and priority.

- Show the proposed date before applying.
- Create a typed adjustment.
- Do not call FSRS or the topic encounter transition.
- Keep it separate from the quick Later action in events and UI copy.

### 11.3 Automatic overflow policy

Provide versioned overload profiles.

**supermemo_like default [SM documented/Derived]**

- Run at StudyDay rollover.
- Consider backlog that was already outstanding before the new StudyDay.
- Do not automatically postpone material that becomes due today.
- Exclude learning/relearning steps and protected elements.
- Run before daily sorting/presentation planning.

**bounded_load optional [Product decision]**

- May also spread today's overflow after protected and mandatory work is admitted.
- Must be clearly labeled as a modern workload-control mode.

For either mode:

- forecast future load separately for cards and topics;
- include existing algorithmic dues and active adjustments;
- reserve headroom for unpredictable intraday steps;
- allocate higher-priority overflow to earlier available capacity;
- upsert one auto_overflow lower bound rather than stacking a new delay on every rebuild;
- persist the operation and policy version;
- never change canonical scheduler state.

Do not pick independent random future dates without a capacity ledger. That creates tomorrow's overload while hiding today's.

### 11.4 Study More

Study More may clear current applicable auto_overflow adjustments and rebuild the plan with a higher temporary cap.

It must preserve:

- manual Later;
- sibling burying;
- Mercy overrides;
- manual reschedules;
- FSRS and topic canonical state.

---

## 12. Mercy

Mercy is an exceptional, previewed bulk calendar redistribution. It is not the normal daily overload mechanism.

### 12.1 Workflow

1. Select scope: collection, branch, or subset.
2. Select collecting period.
3. Choose whether to include future repetitions.
4. Select daily capacity or a destination horizon.
5. Select criteria and protection rules.
6. Compute a dry-run preview.
7. Show counts, exclusions, and before/after load.
8. Require confirmation.
9. Apply one transactional batch with a batch ID.
10. Support exact batch undo.

### 12.2 Candidate rules

- Exclude due learning/relearning steps.
- Exclude unintroduced New cards and pending topics from Mercy in v1. A future exam/introduction-spread feature must use a separate typed planned-introduction date; it is not a review, cannot create FSRS state, and cannot bypass due-review admission protection.
- Exclude protected elements by default.
- Respect branch/subset boundaries.
- Include future repetitions only when selected.
- Keep cards and topics in separate capacity calculations.
- Preserve manual Later by default.
- Warn if applying Mercy repeatedly would hide chronic overload.

### 12.3 Assignment

Mercy may move a presentation earlier or later, so use exact mercy overrides rather than lower-bound deferrals.

Allocate higher-priority candidates to earlier slots. Inside a bounded priority band, criteria may include:

- repetition lateness;
- card retrievability;
- investment/repetition count;
- difficulty;
- recency of introduction;
- stable deterministic randomization.

The exact SuperMemo multi-criteria formula is **[Unknown]**. Keep weights visible, versioned, and testable. Do not claim equivalence.

### 12.4 Apply and undo

Apply:

- verify the preview's candidate revisions;
- exclude active exact manual reschedules unless the preview and confirmation explicitly authorize their replacement;
- clear conflicting auto_overflow adjustments for selected elements;
- create or replace one exact mercy override per selected element;
- retain each complete prior adjustment set in the batch audit snapshot so undo can restore it exactly;
- append one batch event plus item-level audit records;
- do not change FSRS or topic algorithmic state.

Undo:

- append a mercy_undone batch event;
- restore the exact prior adjustment set;
- do not delete the original batch history.

Preview and apply must produce identical assignments when candidate revisions have not changed.

---

## 13. StudyDay and time

- Store card scheduler timestamps in UTC.
- Store the user's home timezone as an IANA/Windows-mapped zone, not a fixed numeric offset.
- Default StudyDay rollover is 04:00 local time.
- Derive StudyDay through a single time service.
- Topics and day-based adjustments use StudyDay values.
- Intraday card steps and short snoozes use exact UTC instants.
- Test both daylight-saving transitions, travel, clock rollback, and restart near rollover.
- Do not let a timezone change reinterpret historical event StudyDays.

---

## 14. Undo and concurrency

### 14.1 Undo

For a card review:

- append card_review_undone referencing the original event;
- restore the exact stateBefore snapshot with optimistic concurrency;
- restore the prior algorithmic due and prior adjustments;
- exclude both the undone outcome and the undo marker from FSRS optimization input.

For a topic encounter:

- append topic_encounter_undone;
- restore its exact before snapshot.

For adjustments and Mercy:

- restore the exact prior adjustment set;
- keep all history.

Do not physically delete events even if older plans say undo deletes the event.

### 14.2 Concurrency and idempotency

- Every command receives an operation ID.
- A repeated operation ID returns the original result without applying twice.
- Use optimistic revision checks or transactional locks on canonical schedule rows.
- A stale Mercy preview must fail and ask for regeneration.
- Queue-plan generation must not append mutation events unless it is applying an explicitly authorized auto-overflow policy.

---

## 15. Required metrics

Provide at least:

- algorithmic due cards and topics for the next 30 days;
- effective due cards and topics for the next 30 days;
- deferred/overridden load by adjustment reason;
- automatic overflow count and percentage of due work;
- manual Later count;
- Mercy count and batch size;
- new cards introduced;
- actual reviews and topics completed;
- card/topic opportunity ratio;
- card/topic foreground-time ratio;
- median and p95 lateness by priority decile;
- measured card retention by priority decile;
- protected-element violations, which must remain zero;
- estimated future workload by branch;
- topic encounter interval and A distributions by policy version.

Warn when automatic overflow is approximately thirty percent or more of due volume for three consecutive weeks. This is a workload-design warning, not a reason to forge reviews.

Log durations for architectural feedback, but do not let duration silently replace the count-based admission model.

---

## 16. Migration requirements

1. Audit the current schema and every write path before editing migrations.
2. Create a recoverable pre-migration backup.
3. Add typed schedule and adjustment structures without deleting legacy data.
4. Backfill cards from the currently canonical FSRS state.
5. Never infer lastReviewAtUtc from a postponed due date.
6. Preserve every current topic due date, interval, and legacy step.
7. Mark old topics as legacy_sequence unless their provenance proves otherwise.
8. Convert current priority ordering to stable order keys using element ID as tie-breaker.
9. Backfill a typed adjustment only when history proves the reason.
10. If prior code destroyed the original due date, preserve the visible current date and mark provenance as legacy_due_unknown. Do not invent history.
11. Import historical reviews as append-only events; mark incomplete snapshots explicitly.
12. Validate referential integrity and reference-vector tests before commit.
13. Roll back the whole migration on any failure.
14. Offer an explicit, previewed topic-policy migration later.

---

## 17. Implementation sequence

Do this in order. Do not begin with UI tuning.

1. Inventory current schema, repositories, scheduler calls, queue queries, event writes, and tests.
2. Write a short migration and compatibility report.
3. Add invariant tests and pinned FSRS reference vectors.
4. Add typed element/card/topic repositories and scheduler-version fields.
5. Add append-only review/activity events and operation IDs.
6. Add schedule adjustments and one effective-due service.
7. Replace stored priority percentages with stable order keys and derived ranks.
8. Add separate versioned boundaries for topic creation-time A-Factor initialization and later A-Factor transitions.
9. Implement `topic_afactor_v2`: the observed creation initializers plus the explicitly provisional monotonic interval transition in section 8.
10. Build separate eligible lanes and deterministic ranking.
11. Implement card/topic admission and the four-to-one weighted merge.
12. Add protected and mandatory-step guarantees.
13. Add supermemo_like automatic overflow with an idempotent capacity ledger.
14. Add Study More and distinct Later/Smart Postpone commands.
15. Add operational metrics and alerts.
16. Add Mercy preview, apply, and exact batch undo.
17. Add optional sibling handling behind the chosen release flag.
18. Run migrations on copies of old databases.
19. Run long-horizon seeded simulations.
20. Only then expose policy tuning in the UI.

After each step, run the narrow tests plus all scheduler invariant tests. Do not bundle data migration, formula changes, and UI redesign into one unreviewable change.

---

## 18. Acceptance tests

### 18.1 FSRS integrity

- Pinned reference vectors pass for every rating and state.
- Reference vectors run with fuzz disabled or a fixed seed; retrying one fuzz-enabled review operation returns the exact stored result and due time.
- Reviewing identical pre-state on time and 45 days late produces the library's exact distinct outputs.
- Actual review time becomes lastReviewAtUtc.
- Every non-review action preserves serialized FSRS state, last review, and algorithmic due byte-for-byte.
- Undo restores the exact prior snapshot and appends a tombstone.
- Practice changes no canonical card state.
- Optimizer input excludes practice, undone events, topic events, and calendar adjustments.

### 18.2 Topic transitions

- A blank-created topic starts at interval `1`, A `1.2`, and due next StudyDay without a forged encounter event.
- A plain-text clipboard topic starts at interval `1`, due next StudyDay, and the length-derived A specified in section 8.2.
- Pasting into or editing an existing blank-created topic does not recalculate its A.
- Done advances exactly once.
- Reusing the same operation ID is a no-op.
- Later leaves interval and algorithmic due unchanged.
- Absolute priority placement leaves A, current interval, and algorithmic due unchanged.
- A one-day interval always grows after Done.
- Back, close, crash, edit, extract, and formulate do not advance.
- Finish/dismiss/suspend do not alter descendants.
- Destructive delete requires an impact preview, never silently cascades, and preserves provenance for surviving descendants.
- A policy version change does not reinterpret stored schedules.

### 18.3 Priority

- First element reports 0%; last reports 100%.
- One element reports 0% without division by zero.
- A three-element rankable population exposes exactly `0%`, `50%`, and `100%`; a four-element population exposes `0%`, `33.333...%`, `66.666...%`, and `100%`.
- A rankable root concept changes positions and derived percents even when it is not schedulable.
- Moving one element gives a stable total order after restart.
- Moving an element in one `priorityScopeId` changes no rank or percent in another scope.
- A move preview reports the correct immediate higher and lower neighbors after excluding the moving element from the provisional order.
- Moving an ordinary topic from top to bottom and back does not change its stored A, current interval, or algorithmic due.
- Jitter never persists into priority data.
- Suspending an element does not delete or rewrite its order key.

### 18.4 Creation A-Factor reference vectors

For `clipboard_plain_text_v1`, assert the exact three-decimal display values below:

| UTF-16 code units | Expected displayed A |
|---:|---:|
| 15 | 1.948 |
| 23 | 1.923 |
| 39 | 1.878 |
| 71 | 1.804 |
| 135 | 1.698 |
| 263 | 1.574 |
| 519 | 1.459 |
| 1,031 | 1.372 |
| 2,055 | 1.317 |
| 4,103 | 1.285 |
| 8,199 | 1.268 |
| 16,391 | 1.259 |

Also assert:

- 200 ASCII `a` characters produce displayed A `1.625`;
- 200 precomposed `é` characters produce displayed A `1.625`;
- 100 `😀` characters, which occupy 200 UTF-16 code units, produce displayed A `1.625`;
- word segmentation does not affect A when UTF-16 length is unchanged;
- an empty clipboard payload is rejected as an atomic import and the explicit blank-topic path initializes A `1.2`;
- an unsupported payload takes its explicitly configured creation-mode fallback and never masquerades as a calibrated plain-text import.

### 18.5 Queue

- Due learning/relearning steps always appear.
- Protected due elements are never automatically postponed under massive overload.
- New cards do not appear when regular due reviews were excluded by the ordinary card cap.
- With both ordinary streams nonempty, the four-card/one-topic target is maintained.
- No topic waits more than eight ordinary card opportunities while both streams remain nonempty.
- Identical inputs produce byte-identical plans.
- Restart preserves the remaining plan and merge cursor.
- Empty-stream fallback does not waste capacity.
- Building a queue for thousands of topics does not execute one rank query per candidate.

### 18.6 Adjustments

- Later changes only effective due.
- Auto-overflow changes only effective due.
- Sibling bury changes only effective due.
- An exact manual/Mercy override may advance or delay presentation without changing canonical state.
- Lower bounds still constrain an exact override according to precedence.
- Study More clears automatic overflow only.
- Rebuilding cannot extend the same automatic overflow repeatedly.
- A genuine review/encounter clears obsolete adjustments and writes a new canonical due.

### 18.7 Automatic overflow

- In supermemo_like mode, today's newly due work is untouched.
- Old outstanding backlog is spread across residual future capacity.
- Higher-priority overflow receives earlier capacity than lower-priority overflow.
- Future canonical dues remain unchanged.
- Existing future load counts toward destination capacity.
- Card and topic capacity ledgers are separate.
- Protected and intraday-step candidates are excluded.
- A three-week absence does not produce one large future clump.

### 18.8 Mercy

- Preview and apply match when revisions are unchanged.
- A stale preview writes nothing.
- Cancel writes nothing.
- Branch scope touches nothing outside the branch.
- Protected and learning/relearning elements are excluded by default.
- Future repetitions are included only when explicitly selected.
- Earlier and later exact overrides both work.
- Manual Later survives by default.
- An active exact manual reschedule is excluded and flagged by default; an explicitly confirmed replacement is restored exactly by batch undo.
- Conflicting auto-overflow adjustments are cleared.
- Unintroduced New/pending elements are excluded and do not gain forged review state.
- Batch undo restores the exact prior adjustment set.
- No card FSRS or topic algorithmic state changes.

### 18.9 Time

- StudyDay rollover works at 04:00 local time.
- Tests pass across spring-forward and fall-back DST changes.
- Exact intraday steps are ordered correctly around rollover.
- Historical event StudyDays do not change after timezone setting changes.

### 18.10 Migration

- Every supported old schema migrates or rolls back completely.
- Card FSRS state is byte-equivalent before and after migration.
- Existing topic due dates remain unchanged.
- Unknown legacy due provenance is flagged, not fabricated.
- Priority order survives restart.
- Restoring the backup reproduces pre-migration state.

---

## 19. Simulation gate

Before enabling automatic overflow or a new topic formula by default, run a seeded 365-day simulation with at least:

- 10,000 cards;
- 2,000 sources/extracts;
- several priority distributions;
- realistic card and topic duration samples;
- a fixed reproducible random seed.

Scenarios:

- steady daily use;
- a three-week absence;
- a large import;
- a burst of card formulation;
- repeated Later;
- top-priority overload;
- cap increases and decreases;
- repeated queue rebuilds;
- Mercy recovery;
- DST and rollover transitions.

Reject the policy if it produces:

- any protected automatic postponement;
- any automatic learning/relearning-step postponement;
- nondeterministic rebuilds;
- future load spikes caused by the overflow planner;
- new-card admission while due-review capacity is exhausted;
- topic or card starvation;
- optimizer contamination;
- worsening higher-priority retention caused by lower-priority work receiving earlier capacity.

---

## 20. Explicit prohibitions

Do not:

- invert normalized rank (`1 - percentile`) and then treat it as a hidden A-Factor input; normalized rank is only an ordering/admission coordinate unless a separately calibrated policy explicitly uses it;
- derive ordinary topic A-Factor from its absolute priority position;
- infer A-Factor from the first topic, a sibling, a parent, or the collection root;
- recalculate creation-time A-Factor when an existing topic is edited or receives pasted text;
- count UTF-8 bytes or Unicode scalar values for the recovered plain-text initializer; count UTF-16 code units;
- persist a user-entered priority percentage as independent truth when the collection only has discrete ranks;
- combine legacy fixed sequences and A-Factor transitions in one unversioned state;
- use one shared due or last-review column for all element types;
- use priority as a substitute for due date;
- call FSRS for a non-review action;
- overwrite canonical due to implement Later, auto-postpone, sibling burying, Mercy, or manual rescheduling;
- treat Mercy as only a lower-bound deferral;
- use fresh randomness on each queue rebuild;
- persist random jitter as priority;
- auto-finish topics;
- admit New cards ahead of excluded due reviews;
- automatically postpone intraday learning/relearning steps;
- physically delete review events during undo;
- train/optimize FSRS from practice or undone events;
- silently migrate existing topic schedules to a new formula;
- claim undocumented SuperMemo constants are exact;
- tune completion/yield multipliers before cold-start guards, telemetry, and simulation exist;
- let daily queue construction perform quadratic rank queries.

---

## 21. Calibration evidence and the next controlled experiment

### 21.1 Findings already locked down

The following observations were reproduced in SuperMemo `20.00.33.64` dated August 7, 2026:

- priority percent is derived from integer position in one global order, with `0%` at the first position and `100%` at the last;
- the collection root concept occupies a priority position even when it has no repetition date;
- the dialog exposes only percents achievable by the current rank count and previews the immediate higher/current/lower elements;
- ordinal is independent of priority (`0` for the observed root; imported topics began at `10001`, `10002`, and so on);
- absolute priority moves did not modify A-Factor, interval, or next repetition;
- blank creation followed by paste stayed at A `1.2`, regardless of pasted length;
- atomic plain-text clipboard creation used the UTF-16 formula in section 8.2, independent of words and UTF-8 byte count;
- imported topics began at interval `1` and next repetition on the next StudyDay;
- the first-topic inheritance hypothesis was falsified.

Do not spend more calibration time repeating those tests unless a different SuperMemo build, element type, or creation command is under test.

### 21.2 Preserve these three baseline collections

Keep every element in each collection. Deleting an unmeasured element changes the rank denominator and invalidates priority comparisons.

1. `SM20_CALIBRATION`: five equal neutral topics with observed A `1.671` at several priority ranks. Track `CAL-P000`, `CAL-P040`, and `CAL-P100` in detail.
2. `afactor test`: ten topics created through the blank-topic path with A `1.2`. Track the highest-, middle-, and lowest-priority topic, excluding the root concept.
3. `AF_LENGTH_CURVE`: the retained clipboard-length series. Track `LEN0001`, `LEN0008`, `LEN0032`, `LEN0128`, and `LEN2048` in detail.

Treat these collections as read-only calibration fixtures except for normal, due topic repetitions. Do not add, delete, rename, edit, extract, formulate, move priority, change settings, postpone, use Mercy, or reschedule inside them. Never advance the Windows clock to make an element due.

### 21.3 Exact natural-repetition protocol

For each tracked topic, collect three genuine due repetitions:

1. Before its due repetition, record SuperMemo build, collection name, local date/time, Home date/day-boundary setting, element ID/title, type, position/total, displayed percent, displayed A-Factor, interval, next repetition, ordinal, and the collection's learning/randomization settings.
2. On the displayed due StudyDay, start ordinary learning with `Ctrl+L`. If SuperMemo says “Nothing more to learn,” do nothing: the topic is not yet due, so wait for its displayed date.
3. Record the complete presentation order in that small collection. Do not select a special subset or force an early repetition.
4. Process every due topic in the collection with the normal **Next repetition** action exactly once, in the order SuperMemo presents it. For a tracked topic, capture its pre-action fields immediately before that action. Do not use Execute Repetition, Reschedule, Advance, Delay, Later, Postpone, or Mercy.
5. Immediately after processing a tracked topic, reopen it only to inspect and record the same fields as the post-action row. Do not apply another repetition while inspecting it.
6. Repeat on each topic's next displayed due date until every tracked topic has three before/after pairs. Different A-Factors may make later dates diverge; follow each topic's own date.
7. Keep screenshots as evidence, but also transcribe the values into CSV or Markdown so calculations can be replayed.

Use one row per pre/post snapshot with these columns:

~~~text
build, collection, cycle, phase, local_timestamp, study_day,
element_id, title, type, position, total, percent,
a_factor_display, interval_days, next_repetition, ordinal,
presentation_index, action, notes
~~~

This experiment is designed to recover natural interval multiplication, integer rounding and minimum-growth behavior, possible hidden A precision, automatic A changes, priority drift, and presentation ordering without contaminating the fixtures.

### 21.4 Later experiments—only in copies

After the three natural repetitions are captured, clone a baseline collection and run one-variable experiments on the copy for:

- Increase Priority and Decrease Priority, because the observed tiny-collection subset command produced a range-check error and the coupled A transition remains unknown;
- midpoint/tie mapping from a typed percent to an integer rank;
- formatted HTML/web import, extract, split, and clone A initialization;
- extracting without Next repetition, manual advance/delay, and reaching the end then closing;
- automatic postpone across StudyDay rollover;
- Mercy criteria and earlier-versus-later allocation;
- cloze sibling timing and queue randomization.

Never use the three baseline collections for destructive or mixed-variable experiments.

---

## 22. Authoritative research links

- Priority queue: https://www.super-memory.org/archive/help/priority.htm
- Incremental reading: https://www.super-memory.org/archive/help/read.htm
- Element data: https://help.supermemo.org/wiki/Element_data
- Keyboard shortcuts: https://help.supermemo.org/wiki/Keyboard_shortcuts
- Element parameters: https://www.super-memory.org/archive/help/elparam.htm
- Element types: https://www.super-memory.org/archive/help/eltypes.htm
- Forgetting index: https://www.super-memory.org/archive/help/fi.htm
- Postpone: https://www.super-memory.org/archive/help/postpone.htm
- Mercy: https://www.super-memory.org/archive/help/mercy.htm
- Mercy criteria: https://www.super-memory.org/archive/archive/help16/mercycrit.htm
- Cloze interval: https://supermemo.guru/wiki/Cloze_interval
- Learn menu and sorting: https://www.super-memory.org/archive/help/learnmenu.htm
- Subset operations: https://www.super-memory.org/archive/help/subsetop.htm
- SuperMemo 12 topic A-Factor notes: https://www.super-memory.org/archive/articles/soft/sm12.htm
- FSRS tutorial: https://github.com/open-spaced-repetition/fsrs4anki/blob/main/docs/tutorial.md
- Dart fsrs releases: https://pub.dev/packages/fsrs/versions

---

## 23. Definition of done

The scheduler fix is complete only when:

- all invariants and acceptance tests pass;
- legacy data migrates without silent reinterpretation;
- card non-review operations are proven not to mutate FSRS;
- topic scheduling and creation initialization are versioned, the recovered UTF-16 reference vectors pass, and unsupported creation modes are explicitly labeled as product fallbacks;
- priority is stored as a stable total order, concepts participate in its rankable population, and percent is derived rather than stored as arbitrary truth;
- effective due is derived from canonical due plus typed adjustments;
- the queue is deterministic, idempotent, protected, and starvation-safe;
- automatic overflow is capacity-aware and policy-labeled;
- Mercy has preview, transactional apply, and exact batch undo;
- required metrics expose overload and priority-protection behavior;
- the chosen defaults and every deliberate divergence from SuperMemo are documented.
