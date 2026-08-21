# Scheduling: The Complete Model

FSRS handles items only. Items are maybe 40% of your elements. This document covers the other 60% — and the part almost nobody explains: **what an extract actually is, from the scheduler's point of view.**

---

## The single most important idea

**An extract is a topic.**

Not a separate kind of thing. Not a card-in-waiting. Not a special case. An extract is a topic that happens to be short, with a parent.

```
Article (topic)
   │
   ├── Extract (topic)
   │      │
   │      ├── Extract (topic)          ← still a topic. Refine further.
   │      │      │
   │      │      └── Cloze (item)      ← FSRS starts HERE
   │      │
   │      ├── Cloze (item)
   │      └── Q&A (item)
   │
   └── Extract (topic)
```

One table. One queue. One scheduler for everything above the item line, a different one below it. The boundary is not "article vs highlight" — it's **"is this graded or not."**

| | Not graded | Graded |
|---|---|---|
| What it is | Articles, extracts, extracts-of-extracts | Q&A cards, clozes |
| Algorithm | Interval × A-factor | FSRS |
| Can you fail it? | **No such concept** | Yes — lapse, relearn |
| What a repetition means | "Show me this again so I can read/refine/convert it" | "Test whether I remember" |

That "no such concept" row trips up everyone coming from Anki. There is no Again/Hard/Good/Easy on an article. You don't fail a paragraph. You just see it again and do more work on it.

---

## Part 1 — Topics (articles and extracts)

### The core formula

```
next_interval = current_interval × A
```

That's it. `A` is the A-factor. Everything below is about calculating a good `A` and a good starting interval.

### First interval — driven by priority

When a topic is created, when should it first appear?

**Priority decides.** High priority means you want it in front of you soon; low priority means it can wait weeks.

```
pressure = 1 − priority_percentile_from_top     (0 = top of collection, 1 = bottom)

first_interval = clamp(round(1 + 20 × pressure²), 1, 30) days
```

| Priority | pressure | First appears in |
|---|---|---|
| Top 2% | 0.02 | 1 day |
| Top 25% | 0.25 | ~2 days |
| Middle | 0.50 | ~6 days |
| Bottom 25% | 0.75 | ~12 days |
| Bottom 2% | 0.98 | ~21 days |

The squaring matters. It keeps the top of your collection tight and lets the bottom spread out fast, rather than treating priority as a straight line.

**Extracts start shorter than articles.** An unprocessed extract is a debt — material you've committed to but haven't converted into anything durable. Use half the base:

```
extract_first_interval = clamp(round(1 + 10 × pressure²), 1, 14) days
```

### The A-factor — three things modulate it

Start from a base and adjust:

```
A_base = 2.0
```

**1. Priority.** High-priority topics should return faster, not just sort earlier.

```
A × (0.7 + 0.8 × pressure)
```

Top priority: ×0.7, so intervals grow slowly and you see it often. Bottom: ×1.5, it recedes fast.

> Note the compounding: low-priority material is both pushed further by auto-postpone *and* grows its intervals faster. That's double-penalising. I think it's correct — low-value material should disappear quickly — but it's a knob to watch if things vanish faster than you want.

**2. Completion — how much is left to read.**

```
completion = read_position / total_length
A × (0.7 + 0.6 × completion)
```

Barely started: comes back sooner, there's a lot left. Nearly finished: recedes.

For extracts, "completion" doesn't apply the same way. Use conversion status instead:

```
Extract with no child items yet:  A × 0.75    ← you still owe a conversion
Extract with child items:         A × 1.25    ← its job is mostly done
```

This is one of the most useful rules here. An extract you've turned into three clozes has served its purpose and should quietly recede. An extract sitting unconverted for two months should keep nagging you.

**3. Yield — extraction density.** *(My addition, not SuperMemo's — build it behind a setting.)*

```
density = extracts_this_session / words_read_this_session × 1000
smoothed = 0.7 × previous + 0.3 × density
normalised = min(smoothed / collection_median, 2.0) / 2.0

A × (1 − 0.6 × normalised)
```

Productive source shrinks A toward returning soon. Barren source lets it grow.

**Final clamp:**

```
A = clamp(A, 1.0, 6.0)
```

Floor of 1.0 means a repetition never *shortens* an interval. You could allow 0.8 for very rich sources — a genuinely dense article arguably should come back sooner each time — but the completion term is the only thing stopping runaway, so start at 1.0 and only lower it once you have data.

### Worked example

A pulmonology review article. Priority top 15%, so pressure = 0.15.

| Session | Interval before | Read | Extracts | Completion | A | Next interval |
|---|---|---|---|---|---|---|
| Created | — | — | — | 0 | — | 1 day |
| 1 | 1 | 900 words | 7 | 0.12 | 2.0 × 0.82 × 0.77 × 0.63 = **0.82 → 1.0** | 1 day |
| 2 | 1 | 1100 words | 5 | 0.27 | ≈1.1 | 1 day |
| 3 | 1 | 800 words | 1 | 0.38 | ≈1.6 | 2 days |
| 4 | 2 | 1400 words | 0 | 0.57 | ≈2.2 | 4 days |
| 5 | 4 | 2000 words | 0 | 0.84 | ≈2.7 | 11 days |
| 6 | 11 | remainder | 0 | 1.0 | — | **finished** |

The article gripped you while it was productive and let go once it wasn't. That's the behaviour you want, and a flat ×1.8 gives you none of it.

---

## Part 2 — What actually happens during a topic repetition

The topic appears in your queue. Four ways the encounter can end, and **they are not the same:**

| Action | Interval | Read-point | Logged as | Meaning |
|---|---|---|---|---|
| **Next repetition** | grows by A | advances | `topic_read` | Real repetition. Did some work. |
| **Later** | **unchanged** | unchanged | `postpone` | Didn't engage at all. |
| **Finish** | — | — | `finish` | Nothing left to mine. |
| **Dismiss** | — | — | `dismiss` | Not interested anymore. |

**The trap:** if "Later" grows the interval, skipping an article five times pushes it to a two-year interval. You'd have silently deleted it by not engaging with it. Later must never touch the interval — only the due date.

### Auto-finish

*(My refinement — SuperMemo makes you dismiss manually, which means dead articles linger in queues forever.)*

```
if read_position >= end AND no unextracted text remains:
    status = 'finished'
```

Out of the queue, still in the tree as the provenance root for its extracts. Resurrectable.

For extracts, the equivalent nudge:

```
if extract has ≥1 child item AND has appeared 3+ times since the last
   item was created:
       prompt: "You've made 3 cards from this and nothing since. Finish it?"
```

Without something like this, your collection fills with extracts you mentally finished months ago but never formally closed.

---

## Part 3 — Items (FSRS)

### The handoff

When you create a cloze from an extract, a new item is born. FSRS treats it as a new card.

**But you've already read that extract four times over three weeks.** You're not learning it cold — you half-know it. Does FSRS need to be told?

**No.** The mechanism already exists: grade it Easy on first presentation and you get a long first interval. That's exactly what the Easy button is for. Don't build custom seeding logic — you'd be guessing at initial stability values with no data to validate against.

> This passive familiarity is not a side effect. It's one of the real advantages of incremental reading over bulk card-making: by the time you formulate the question, you've had several unpressured exposures to the material. Cards made this way start easier and lapse less.

### Sibling burying

Multiple clozes from one sentence are siblings. Showing three of them in the same session is near-useless — the first one gives away the other two.

```
When an item is answered, push any sibling due the same day to tomorrow.
```

Log it as `auto_postpone`, not as a review. Cheap to build, noticeably improves review quality.

### Leeches

An item that keeps failing. Standard handling is to suspend it. **Do something better, because you have provenance:**

```
if lapses >= 8:
    flag it, and offer: "This has failed 8 times. Open the source
    passage?" → jumps straight to the parent extract in context.
```

Most repeated failures aren't hard facts — they're badly written cards. You can't diagnose that from the card alone. This is the single best use of the tree you've built.

---

## Part 4 — The three schedulers side by side

| | Article | Extract | Item |
|---|---|---|---|
| Graded | No | No | Yes, 1–4 |
| Engine | interval × A | interval × A | FSRS |
| First interval | 1–30d by priority | 1–14d by priority | FSRS new card |
| A modulated by | priority, completion, yield | priority, conversion status | n/a |
| Interval can shrink | only manually | only manually | yes, on lapse |
| Repetition means | read + extract | refine or convert | recall test |
| Exits queue when | fully read | mined out | never (or suspended leech) |
| Failure exists | no | no | yes |

---

## Part 5 — The work order

Add this to your instruction pack, between Order 3 and Order 4.

```
Build the topic scheduler. This is separate from FSRS — topics and
extracts are never graded and never go through FSRS.

TERMINOLOGY: a topic is any non-graded element. Articles and extracts are
both topics. Extracts are simply topics with a parent and less text.
They share one table, one queue, and one scheduler.

FIRST INTERVAL, set when the element is created:
  pressure = 1 - priority_percentile_from_top
  articles: clamp(round(1 + 20 * pressure^2), 1, 30) days
  extracts: clamp(round(1 + 10 * pressure^2), 1, 14) days

ON A REAL REPETITION ("next repetition"):
  next_interval = current_interval * A

  A starts at 2.0, then multiply by each of:
    priority:    (0.7 + 0.8 * pressure)
    articles — completion: (0.7 + 0.6 * fraction_read)
    extracts — conversion: 0.75 if it has no child items yet,
                           1.25 if it has at least one
  then clamp A between 1.0 and 6.0

  Advance the read-point. Log event_type = topic_read.

FOUR DISTINCT END-OF-ENCOUNTER ACTIONS — these must behave differently:
  "Next repetition": interval grows by A, read-point advances,
                     logged as topic_read
  "Later":           interval UNCHANGED, read-point unchanged, only the
                     due date moves, logged as postpone
  "Finish":          leaves the queue, stays in the tree, resurrectable
  "Dismiss":         leaves the queue, stays in the tree, resurrectable

  Critical: "Later" must never modify the interval. If it did, skipping
  an article a few times would silently push it years into the future.

AUTO-FINISH:
  When an article's read-point reaches the end and no unextracted text
  remains, set status to finished automatically.
  When an extract has at least one child item and has appeared 3 or more
  times since the last item was created from it, prompt me to finish it.

SIBLING BURYING for items:
  When I answer an item, push any sibling item (same parent extract) due
  the same day to the next day. Log as auto_postpone, not as a review.

LEECHES:
  At 8 lapses, flag the item and offer a one-key jump to its parent
  extract in the original source context. Do not auto-suspend.

VERIFY: give me steps to (a) confirm pressing "Later" on an article
leaves its interval unchanged while "next repetition" grows it;
(b) confirm a high-priority new article first appears in about a day
while a low-priority one appears in about three weeks; (c) confirm an
extract that has produced clozes grows its interval faster than one
that has produced none.
```

---

## What's SuperMemo and what's mine

Worth knowing which parts are battle-tested and which are my design.

| Component | Source |
|---|---|
| Extracts are topics; one tree, one queue | SuperMemo |
| interval × A-factor for topics | SuperMemo |
| Priority shortening topic intervals | SuperMemo |
| No grading, no failure for topics | SuperMemo |
| FSRS for items | Modern replacement for SM-2, well validated |
| Sibling burying | Anki, standard practice |
| Completion factor in A | Mine |
| Extract A-factor by conversion status | Mine — but the one I'm most confident in |
| Yield-based A modulation | Mine — experimental, build behind a setting |
| Auto-finish | Mine — a fix for a real SuperMemo annoyance |
| Leech → jump to source instead of suspend | Mine |

The constants throughout — 2.0, 0.7, 0.8, 0.6, the clamps — are reasonable starting points, not derived values. Log the inputs and the resulting A on every repetition so that in six months you can look at real data and tune them instead of trusting my arithmetic.
