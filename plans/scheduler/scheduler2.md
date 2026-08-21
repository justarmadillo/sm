# Incremental Reading: Implementation Spec for the Remaining 40%

You already have: topics scheduled with growing intervals, a single interleaved queue, priority-driven sorting, extraction, and cloze/QA formulation. This document covers what's left, in build order, with schemas and algorithms.

**Core thesis to keep in mind while reading:** priority *sorts* the queue; it does not *shrink* it. Every failure mode below traces back to conflating those two. The subsystems in this doc are, collectively, the load valve.

---

## 0. Data model (sqlite + drift)

Topics and items are the same row type, discriminated. This is not a stylistic choice — the unified tree is what makes provenance, inheritance, and subtree operations possible.

```sql
CREATE TABLE elements (
  id              INTEGER PRIMARY KEY,
  parent_id       INTEGER REFERENCES elements(id),
  path            TEXT NOT NULL,          -- materialized path: '/1/47/203/'
  type            TEXT NOT NULL,          -- 'topic' | 'item' | 'concept'
  subtype         TEXT,                   -- 'qa' | 'cloze' | 'article' | 'extract'

  title           TEXT,
  reference_id    INTEGER REFERENCES refs(id),

  -- content
  content_json    TEXT,                   -- block array (topics) or Q/A payload (items)
  extract_anchor  TEXT,                   -- {block_id, start, end} within parent

  -- scheduling (shared)
  priority_score  REAL NOT NULL,          -- see §1
  due_date        INTEGER,                -- julian day, NULL = not scheduled
  interval        REAL,                   -- days
  last_review     INTEGER,
  status          TEXT NOT NULL,          -- 'pending' | 'dismissed' | 'finished'

  -- item-only (FSRS)
  stability       REAL,
  difficulty      REAL,
  reps            INTEGER DEFAULT 0,
  lapses          INTEGER DEFAULT 0,
  fsrs_state      TEXT,                   -- 'new'|'learning'|'review'|'relearning'

  -- topic-only
  read_block_idx  INTEGER DEFAULT 0,
  processed_spans TEXT,                   -- JSON array of consumed ranges
  a_factor        REAL DEFAULT 1.8,
  yield_ewma      REAL DEFAULT 0,         -- see §6

  postpone_count  INTEGER DEFAULT 0,
  created_at      INTEGER
);

CREATE INDEX idx_queue  ON elements(status, due_date, priority_score DESC);
CREATE INDEX idx_path   ON elements(path);

CREATE TABLE refs (
  id INTEGER PRIMARY KEY,
  title TEXT, author TEXT, published_at TEXT,
  url TEXT, source_type TEXT, imported_at INTEGER
);
```

**Why materialized path instead of pure adjacency list:** subtree queries (`WHERE path LIKE '/1/47/%'`) are your bread and butter — burden aggregation, subset review, cascade decisions. Adjacency alone forces recursive CTEs on every one. Cost: path rewrite on move, which is rare.

**The review log is the highest-priority thing in this entire document**, because it is the only data you cannot reconstruct later:

```sql
CREATE TABLE review_log (
  id INTEGER PRIMARY KEY,
  element_id      INTEGER NOT NULL,
  event_type      TEXT NOT NULL,   -- 'review'|'postpone'|'auto_postpone'
                                   -- |'manual_reschedule'|'dismiss'|'topic_read'
  reviewed_at     INTEGER NOT NULL,
  grade           INTEGER,         -- 1-4, NULL for non-review events
  elapsed_days    REAL,            -- ACTUAL days since last_review
  scheduled_days  REAL,            -- what the interval had been
  stability_before REAL,
  difficulty_before REAL,
  state_before    TEXT
);
```

Only `event_type = 'review'` feeds the scheduler optimizer. Postpones and reschedules must be logged but excluded from training, or you will teach the optimizer that your memory is worse than it is.

---

## 1. Priority: percentile, not absolute score

### The failure you're heading toward

Absolute 0–100 priority inflates. Every new import feels important; you assign 80. Twelve months in, 60% of your collection sits above 75 and the field carries no information. Priority stops sorting anything meaningfully and the auto-postpone valve (§3) has nothing to discriminate on.

| | Absolute score | Percentile rank |
|---|---|---|
| Semantics | "this is important" | "this is more important than 92% of my collection" |
| Adding a high-priority element | costs nothing | demotes everything below it |
| Scarcity | none | enforced structurally |
| Drift over time | inflation | stable by construction |

### Implementation: hybrid

Storing a true rank index and rewriting it on every insert is expensive. Store an absolute float but make the **UI operate exclusively in percentile terms.**

```python
def score_at_percentile(db, p):  # p in [0,1], 0 = highest priority
    n = db.scalar("SELECT COUNT(*) FROM elements WHERE status='pending'")
    offset = max(0, min(n - 1, int(p * n)))
    return db.scalar("""
        SELECT priority_score FROM elements
        WHERE status='pending'
        ORDER BY priority_score DESC
        LIMIT 1 OFFSET ?""", offset)

def set_priority_percentile(db, element, p):
    lo = score_at_percentile(db, min(1.0, p + 0.005))
    hi = score_at_percentile(db, max(0.0, p - 0.005))
    element.priority_score = (lo + hi) / 2 + random.uniform(-1e-6, 1e-6)
```

The jitter prevents ties from collapsing sort order. Display priority as `rank/N` computed on read.

**Inheritance rule.** A new extract inherits the parent's `priority_score`. Two schools:

- **Exact inheritance** (SuperMemo's default). Simple, predictable.
- **Slight decay** — `child = parent * 0.98`. Rationale: an extract is more granular and less likely to be the thing you most need. Prevents a single high-priority source from flooding the top percentiles with 200 descendants.

My take: exact inheritance, plus a hard rule that **any single subtree may occupy at most X% of the top decile** (enforce at queue-build time by capping how many elements from one root can appear in a session). Decay is a blunt instrument that quietly demotes material you deliberately marked as critical.

---

## 2. Queue construction

```python
def build_queue(db, today, cap):
    due = db.query("""
      SELECT * FROM elements
      WHERE status='pending' AND due_date <= ?
      ORDER BY priority_score DESC""", today)

    due = apply_overload_valve(due, cap, today)   # §3
    return sort_session(due)
```

### Sorting inside the session

Pure priority ordering is rigid and produces a demoralizing "grind the top, never reach the bottom" pattern. Blend three signals:

```python
def sort_key(e, today, n_pending):
    p_norm    = 1.0 - (rank_of(e) / n_pending)         # 1.0 = top priority
    overdue   = (today - e.due_date) / max(e.interval, 1)
    overdue_n = min(overdue, 1.0)
    jitter    = random.uniform(-0.03, 0.03)
    return 0.75 * p_norm + 0.20 * overdue_n + 0.05 + jitter
```

Rationale for the overdue term: an element 40 days late at the 55th percentile deserves to surface before a fresh element at the 60th. Without it, mid-priority material accumulates staleness invisibly.

### Topic starvation guard

Items outnumber topics 20:1 within months. Pure priority sorting will front-load items and reading stops — which kills the whole system, since reading is what generates future items. Enforce an interleave floor:

```python
MIN_TOPIC_EVERY = 8   # at least one topic per 8 elements, if topics are due
```

Implement as a merge pass over the sorted list, promoting the highest-priority unplaced topic whenever the gap exceeds the threshold.

---

## 3. The overload valve (postpone machinery)

Three distinct mechanisms, routinely conflated. Build all three.

### 3a. Manual "Later"

A fixed +1 day is useless — the element returns tomorrow into an equally full queue. Delay must scale with the element's interval:

```python
def later(e, today):
    delay = max(1, round(e.interval * random.uniform(0.10, 0.30)))
    e.due_date = today + min(delay, 365)
    e.postpone_count += 1
    log(e, 'postpone')          # NO grade, NO stability change
```

**Critical:** a postpone is not a review. Do not touch `stability`, `difficulty`, `reps`, or `last_review`. The next actual review will compute `elapsed_days` from the true `last_review` and FSRS will handle the long gap correctly (§4). If you update `last_review` on postpone, you destroy the retention signal.

### 3b. Dismiss

`status = 'dismissed'`. Removed from queue, retained in the tree with full memory state. Reversible. Distinct from delete — deleting an item with 40 reps of history is destroying data.

### 3c. Auto-postpone (the daily valve)

Runs at queue build. This is the mechanism that makes the whole system survivable.

```python
def apply_overload_valve(due, cap, today, tolerance=1.2, n_pending=None):
    if len(due) <= cap * tolerance:
        return due

    keep     = due[:cap]
    overflow = due[cap:]

    for e in overflow:
        p_norm   = 1.0 - (rank_of(e) / n_pending)   # 1.0 = top priority
        pressure = 1.0 - p_norm                     # 0 = top, 1 = bottom
        base     = max(1.0, e.interval * 0.10)
        delay    = base * (1 + 4 * pressure) * random.uniform(0.8, 1.2)
        delay    = int(max(1, min(delay, 1095)))
        e.due_date = today + delay
        e.postpone_count += 1
        log(e, 'auto_postpone')

    return keep
```

Three properties that matter:

| Property | Mechanism | Consequence |
|---|---|---|
| Proportional | `delay ∝ interval` | Young elements aren't lost to the void; mature ones recede far |
| Priority-graded | `× (1 + 4·pressure)` | Bottom-decile material gets pushed ~5× further than top |
| Dispersed | `× uniform(0.8, 1.2)` | Prevents re-clumping on a single future day |

**Mandatory guardrail — the priority floor:**

```python
PROTECTED_PERCENTILE = 0.05   # top 5% never auto-postponed
```

Elements above the floor stay due even when the queue overflows. They force a decision: do it, or manually demote it. Without this guardrail, auto-postpone eventually pushes *everything* out and you have a system that schedules nothing — the postpone death spiral.

### 3d. Mercy (backlog redistribution)

Auto-postpone handles daily drift. It handles a 3-week absence badly, because it chews the backlog one day at a time. Mercy is a one-shot spread across a horizon:

```python
def mercy(db, today, horizon_days, daily_cap):
    backlog = db.query("""SELECT * FROM elements
                          WHERE status='pending' AND due_date < ?
                          ORDER BY priority_score DESC""", today)
    day, count = 0, 0
    for e in backlog:
        if count >= daily_cap:
            day += 1
            count = 0
        if day <= horizon_days:
            e.due_date = today + day
        else:
            # tail: push beyond horizon, worst priority furthest
            overflow_rank = (index_of(e) - horizon_days * daily_cap)
            e.due_date = today + horizon_days + int(overflow_rank / daily_cap * 3)
        count += 1
        log(e, 'auto_postpone')
```

Result: top-priority backlog lands in the next 2–3 days, the tail lands months out. That distribution *is* the correct outcome, not damage control.

---
## 8. Provenance navigation

You have `parent_id`. What's missing is the interaction.

**Reference resolution.** Store the `reference_id` on the root topic and **denormalize it onto every descendant at creation time**. Walking up the tree on every card render is a needless join, and denormalizing means a card survives deletion of its source with its citation intact.

**Failed-card escape hatch.** During review, one keystroke on a lapsed item opens its parent extract in the source context, with the extract highlighted in situ. This is the single highest-value navigation affordance in the entire system: the reason a card fails is usually that it was formulated without enough context, and this is where you fix it.

**Deletion policy.** Never silently cascade. Deleting a source topic offers:

| Option | Behavior |
|---|---|
| Delete subtree | Removes descendants and their memory state. Confirm with rep count. |
| Orphan and keep | Children retain a snapshot of the reference; `parent_id` → NULL |
| Dismiss instead | Status change only. Default suggestion. |

---


## 11. Failure modes to instrument now

| Failure | Symptom | Countermeasure |
|---|---|---|
| Priority inflation | 60% of collection above 75 | Percentile UI (§1) |
| Postpone death spiral | Daily queue trends to zero, nothing learned | Protected top percentile (§3c) |
| Extract explosion | Burden growing 3%+/week | Surface per-session extract count + subtree burden (§5) |
| Backlog clumping | Postponed material lands on one future day | Randomized dispersal in delay formula (§3c) |
| Optimizer poisoning | FSRS weights drift toward pessimism | Exclude non-`review` events from training data (§0) |
| Topic starvation | Reading stops, item count plateaus | Interleave floor (§2) |
| Orphaned items | Cards with no recoverable context | Denormalized reference + explicit deletion policy (§8) |

Add a weekly stats page showing: total burden, burden delta, auto-postpone count, extracts created, median priority percentile of completed reviews. If auto-postpone count exceeds ~30% of due volume for three consecutive weeks, the system should tell the user their collection is oversubscribed and offer bulk demotion of the lowest-burden-value subtrees.