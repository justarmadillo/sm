# Scheduler Architecture Guide

Audience: the project architect

Purpose: explain, in plain language, what the scheduler should do, which plan conflicts were resolved, and why the design is safe.

For the coding-agent contract, see [LLM_FIX_INSTRUCTIONS.md](./LLM_FIX_INSTRUCTIONS.md).

---

## The short version

Your central idea is right:

- use **FSRS for cards**, because cards test memory;
- use **priority plus an expanding interval for sources and extracts**, because topics allocate attention rather than test recall;
- show both in **one study stream**, because incremental reading works best when reading, extracting, formulation, and review feed one another.

The main issue in the existing plans is not the idea. It is that several documents describe different schedulers at the same time. If an AI implements pieces from each, the result can look plausible while quietly damaging schedules.

The repaired architecture has:

1. two scheduling engines;
2. separate internal queues;
3. one user-facing stream;
4. one global priority order;
5. temporary calendar adjustments that never pretend to be learning;
6. an append-only history so every decision can be explained and undone.

---

## 1. Think of it as two machines

### The memory machine: cards

A card asks, “Can I recall this?”

The learner answers Again, Hard, Good, or Easy. FSRS uses that answer and the actual time of review to estimate memory stability and choose the next review time.

This is a feedback system. A fake answer creates fake memory data.

That is why the following actions must never call FSRS:

- Later;
- automatic postponement;
- Mercy;
- changing priority;
- practice;
- burying a sibling;
- moving something to another date.

Those actions change the calendar, not the learner's memory.

### The attention machine: sources and extracts

A source or extract asks, “When should I spend attention on this again?”

There is no honest Again/Hard/Good/Easy rating because reading is not a recall test. A topic instead has:

- a current interval;
- an A-Factor that controls interval growth;
- a next topic date;
- a priority that affects how quickly it recedes.

An extract is simply a smaller topic with a parent. It becomes an independent piece of work and can later produce cards.

### Why one scheduler cannot safely do both

If topics use FSRS, the application has to invent recall grades for reading. FSRS then learns from fiction.

If cards use only topic priority, the system throws away recall outcomes and cannot estimate memory decay.

The two engines solve different problems. Combining them is simpler in the database only; it is worse for the learner.

---

## 2. One screen does not mean one internal queue

The user should feel one continuous learning session, but the scheduler should prepare several lanes:

~~~mermaid
flowchart LR
    C1["Due learning steps"] --> CP["Card plan"]
    C2["Due review cards"] --> CP
    C3["Available new cards"] --> CP
    T1["Due sources"] --> TP["Topic plan"]
    T2["Due extracts"] --> TP
    CP --> M["Weighted fair merge"]
    TP --> M
    M --> U["One study screen"]
~~~

This separation matters because the lanes have different rules:

- an intraday card step is mandatory at an exact time;
- an overdue review competes with other review cards;
- a new card must not displace an overdue review;
- a topic has a day-level date and no recall grade;
- cards and topics need different overload capacity.

The merge happens last. The default target is four card opportunities followed by one topic opportunity.

That target is flexible:

- if there are no topics, continue with cards;
- if there are no cards, continue with topics;
- if both exist, do not let topics disappear for a long run;
- an urgent intraday card step may temporarily interrupt the pattern.

This gives the SuperMemo-like feeling without forcing unlike records into one fragile query.

---

## 3. Priority, due date, and ordinal are different things

The SuperMemo screenshots are useful because they show these values side by side rather than treating them as one field.

| Coordinate | Plain meaning | What it answers |
|---|---|---|
| Due date | the scheduler's appointment | “May this appear now?” |
| Priority | relative value compared with the whole collection | “If several things can appear, which matters more?” |
| Ordinal | separate manual/pending-order metadata | “Where is it in that independent order?” |

The database ID is a fourth concept: it is identity and never changes.

### Why this separation matters

Suppose a very important card is not due for six months.

- Its priority is high.
- Its due date is six months away.
- It should not normally appear today.

Suppose a low-priority card is overdue.

- Its priority is low.
- Its due date has passed.
- It is eligible, but it may lose admission under overload.

If priority is used as the due date, high-priority topics can repeat constantly and low-priority material can disappear without a trace. If due date is used as priority, the application loses the learner's strategic choices.

Eligibility must come first; priority ranks what is already eligible.

---

## 4. The priority queue is one relative order

SuperMemo describes priority as a global position:

- position 1 is the highest;
- 0% is the top;
- 100% is the bottom.

The application should store a stable order key, not an authoritative percentage. Position and percentage are calculated from the current order.

For N elements:

~~~text
priority percent = 100 × (position - 1) / (N - 1)
~~~

Special case: a collection with one element reports 0%.

This makes both endpoints exact and makes the screenshot's “position” and “percent” two views of one underlying order.

### A specific error in the current plan

scheduler1.md writes:

~~~text
pressure = 1 - priority_percentile_from_top
~~~

but its table and worked example use the percentile directly. The written equation is inverted.

Use:

~~~text
p = priority_percentile_from_top
~~~

where p is 0 at the top and 1 at the bottom.

Without this fix, the highest-priority topic gets the behavior intended for the lowest-priority topic.

### Who belongs in the order

Recommended decision:

- include every non-deleted source, extract, and card in one global rankable order;
- keep the order key when an element is suspended, dismissed, or finished;
- exclude folders and UI-only nodes;
- independently exclude inactive elements from today's eligible work.

Why: temporarily suspending a branch should not destroy its place in the collection or cause a giant, hard-to-explain reorder.

This is a transparent product choice. Keep the population rule versioned because SuperMemo's exact inactive-element treatment may vary.

---

## 5. How topic intervals should work

Sources and extracts use the same kind of scheduler.

When a real topic encounter finishes:

~~~text
next interval = current interval × A-Factor
~~~

The repaired implementation also guarantees that the rounded interval grows by at least one day:

~~~text
next interval = max(current interval + 1, round(current interval × A))
~~~

Why: with a one-day interval and A equal to 1.0, rounding can keep the topic at one day forever.

### Simple examples

- Current interval 5 days, A 1.2 → next interval 6 days.
- Current interval 5 days, A 1.8 → next interval 9 days.
- Current interval 20 days, A 1.2 → next interval 24 days.
- Current interval 20 days, A 1.8 → next interval 36 days.

A smaller A means the topic returns more often. A larger A lets it recede.

Therefore higher-priority topics should generally receive a smaller A than lower-priority topics.

### What is known and what is not

SuperMemo documents the broad behavior:

- topics have intervals and A-Factors;
- A-Factor affects interval growth;
- priority and the way a topic is processed matter.

SuperMemo does not publish a complete current formula for:

- priority to A-Factor;
- topic length;
- read progress;
- extraction yield;
- investment;
- manual advance or delay;
- random variation;
- Mercy sorting.

That means a claim of a “perfect clone” formula would be false without controlled observations.

The safe architecture uses a named, versioned policy. The first transparent policy can be improved later without silently rewriting old schedules.

### The provisional first policy

The repaired plan keeps the simple priority term already proposed, with the direction fixed:

~~~text
p = 0 at top, 1 at bottom
A = clamp(2.0 × (0.7 + 0.8 × p), 1.01, 6.0)
~~~

So:

- top priority starts near A 1.4;
- middle starts near A 2.2;
- bottom starts near A 3.0.

This is a product formula, not a recovered SuperMemo secret.

The completion, yield, and conversion multipliers in scheduler1.md should initially be disabled and only measured in the background. They sound sensible, but together they can compound dramatically and make material vanish. They also have cold-start problems such as a zero-word source or no historical median reading speed.

Promoting any of them should create a new policy version and require simulation.

### The provisional first interval

After the first explicit encounter, the first policy uses priority to choose a short starting interval:

~~~text
source: round(1 + 20 × p²) days
extract: round(1 + 10 × p²) days
~~~

Examples:

- top priority is about one day;
- middle priority is about six days for a source and four for an extract;
- bottom priority is about 21 days for a source and 11 for an extract.

This is another transparent starting rule, not a recovered SuperMemo formula. Extracts return sooner because they are usually smaller pieces waiting to be processed or converted.

### Creation and the first encounter

Resolve the existing plan conflict this way:

- a new source is eligible today;
- a new extract is eligible on the next StudyDay;
- the first explicit Done creates its first post-encounter interval.

Creation is not a repetition. Extracting a passage is not a repetition. Merely reaching the end of an article is not a repetition.

---

## 6. What counts as a topic encounter

Use an explicit Done or Next repetition action.

Done means the learner intentionally completed this encounter. It may include:

- reading;
- rereading;
- thinking;
- editing;
- extracting;
- formulating a card.

Zero cursor movement can still be valid for a short extract or a reread.

These do not advance the topic by themselves:

- opening it;
- closing it;
- pressing Back;
- crashing;
- extracting text;
- creating a card;
- moving the cursor;
- reaching the final paragraph.

Why: automatic advancement turns navigation accidents into months-long schedule changes. An explicit action is easy to understand, undo, and test.

Sources should never auto-finish. The interface may suggest Finish at the end, but the learner confirms it.

---

## 7. Cards belong entirely to FSRS

For a real review, FSRS receives:

- the exact stored card state;
- the actual rating;
- the actual current UTC time;
- the pinned parameter set.

The application stores the exact result, including the next algorithmic due time.

### Why actual review time matters

FSRS uses elapsed time. A review done 45 days late is not mathematically the same as a review done on time.

Passing the old due date instead of the real review time tells FSRS that the late survival never happened. Passing a postponed date as the last review tells FSRS that learning occurred when it did not.

Both errors poison future intervals and any later parameter optimization.

### The SuperMemo A-Factor screenshot does not change this choice

The Element Data screenshot shows A-Factor and forgetting index on a SuperMemo item because SuperMemo uses its own item algorithm.

In this product:

- FSRS replaces those item-scheduler controls;
- card A-Factor should not become a second competing scheduler input;
- any FSRS stability, difficulty, or retention information should be diagnostic unless there is a deliberately designed expert setting.

Copy the behavior of separating priority from scheduling state, not every legacy field name.

### New cards

A newly formulated card remains New until it is actually introduced.

If the daily review capacity is full, the card waits in the New pool. The system must not create a fake postponement or fake review.

Earlier exposure while reading is real human familiarity, but it is not reliable enough to manufacture an FSRS stability value. The learner's first honest rating provides the evidence.

### Intraday steps

Learning and relearning steps due in minutes are mandatory work for a card already in progress.

They:

- use exact times;
- may interrupt the normal card/topic rhythm;
- do not consume another unique-card admission;
- are excluded from automatic postponement and Mercy.

Otherwise the system can strand a failed card halfway through relearning.

---

## 8. Keep the scheduler's date and the calendar move separate

This is the most important data-model repair.

Think of the algorithmic due as the appointment written by the learning engine.

Think of a schedule adjustment as a transparent note placed over the calendar:

- “not before Friday”;
- “show this exactly next Tuesday”;
- “bury this sibling until tomorrow.”

The original appointment remains visible for statistics and future learning calculations.

### Two kinds of adjustment

**Lower bound**

The element cannot appear before a date, but it may already have a later algorithmic date.

Used for:

- Later;
- automatic overflow;
- sibling burying;
- a short Snooze.

**Exact override**

For presentation purposes, use a chosen date instead of the algorithmic one.

Used for:

- Mercy;
- manual rescheduling;
- deliberate advance to an earlier day.

The effective date is:

~~~text
candidate = exact override if present, otherwise algorithmic due
effective due = later of candidate and all active lower bounds
~~~

### Why a simple postponed-due field is not enough

If the application overwrites the FSRS due date:

- it loses what FSRS actually predicted;
- lateness becomes impossible to measure correctly;
- undo cannot restore the truth reliably;
- parameter optimization may learn from a calendar operation;
- repeated queue building can push the same card farther every time.

If every adjustment is only “not before,” Mercy cannot move a future repetition earlier. SuperMemo's recovery tools can redistribute work in both directions, so an exact override is also necessary.

### Precedence in ordinary language

- Later is respected by default.
- Auto-overflow can be cleared by Study More.
- Mercy replaces conflicting automatic overflow for the elements it redistributes.
- Mercy keeps manual Later unless the user explicitly chooses otherwise.
- A real review or topic encounter writes a new algorithmic date and clears adjustments that the new result makes obsolete.

---

## 9. Four different workload tools

The current plans risk using “postpone” for several different intentions. Keep the names and events separate.

### Later

“I do not want this one now.”

- affects one element;
- quick, manual action;
- adds a minimum next date;
- does not learn anything about memory.

### Smart Postpone

“Find a sensible later slot for this one.”

- affects one element;
- looks at priority and future capacity;
- previews or explains the proposed destination;
- still does not change memory state.

### Automatic overflow

“The collection has more outstanding work than today's capacity.”

- system policy;
- sacrifices lower-priority backlog first;
- protects the top of the priority queue;
- spreads displaced work into real residual future capacity;
- is reversible through Study More.

### Mercy

“I have an exceptional backlog, holiday, exam, or deadline and need a controlled bulk redistribution.”

- explicit tool;
- works on a collection, branch, or subset;
- previews before applying;
- may move work earlier or later;
- supports exact batch undo;
- is not a normal daily habit.

Keeping the four separate makes history explainable. It also lets the architect later tune or remove one behavior without changing the others.

---

## 10. The two honest choices for auto-postpone

There are two defensible product modes.

### Recommended default: SuperMemo-like

At the beginning of a new StudyDay:

- inspect work that was already outstanding before today;
- postpone lower-priority old backlog if necessary;
- leave repetitions that become due today untouched;
- do this before sorting and building the presentation plan.

Why: this is closest to documented SuperMemo auto-postpone behavior and keeps “what became due today” honest.

Tradeoff: today's visible queue can still exceed the configured cap after a bad run of new dues.

### Optional modern mode: bounded load

After mandatory and protected work is selected:

- also spread today's excess across future residual capacity.

Why: it gives a more reliable daily workload.

Tradeoff: it departs from strict SuperMemo-like semantics and more aggressively hides outstanding work.

The UI should name the mode. Do not silently blend them.

### Capacity awareness is mandatory in both modes

Moving 180 cards from today to tomorrow is not workload management. It is hiding a problem for one day.

The planner must examine:

- future card dues;
- future topic dues;
- existing adjustments;
- the separate card/topic caps;
- reserved headroom for unpredictable relearning.

Then it assigns overflow to days with residual capacity, giving earlier capacity to higher-priority work.

---

## 11. Protecting important work

The plans mention both top one percent and top five percent protection. Choose one explicit default rather than letting two modules disagree.

Recommended default:

**the top one percent is immune to automatic postponement**

Make it configurable and record it with the policy version.

Protection is calculated before lateness correction or random jitter. Otherwise an element can lose its guarantee because of presentation decoration.

Protected work may cause a soft cap to be exceeded. That is an honest signal: the learner has declared more material critically important than the nominal daily workload can hold.

Manual Later remains allowed even for protected material because it is the learner's explicit choice.

---

## 12. Priority should dominate, but not make lateness invisible

Among due candidates, priority should be the main ordering signal.

However, two close-priority cards should not remain in a rigid order forever while one becomes severely late. A bounded lateness correction can move an element by at most about five percentage points of the priority range.

This means:

- an extremely low-priority card cannot leap above the collection's top material merely because it is late;
- within a nearby band, memory risk can matter;
- the system remains recognizable as priority-driven.

Cards can use FSRS retrievability as part of lateness. Topics can use days late relative to their interval.

This is a modern, transparent choice. The exact SuperMemo sorting formula is not public.

---

## 13. Randomization must be repeatable

Some randomization is useful. A completely predictable sequence creates:

- context cues;
- same-source clusters;
- fatigue patterns;
- fragile memorization of order.

But fresh randomness on every refresh is bad:

- the next item jumps around;
- debugging becomes nearly impossible;
- undo and restart change the future;
- repeated queue building can produce different overload victims.

Use deterministic randomization derived from stable inputs such as:

- collection ID;
- StudyDay;
- element ID;
- queue lane;
- policy version.

The order can feel varied from day to day while being perfectly reproducible for one day and one state.

Card and topic randomization should be independently configurable, matching the idea in SuperMemo's priority queue.

---

## 14. Sibling clozes need presentation protection

Several clozes from one sentence can give one another away. Showing them together measures short-term context more than durable recall.

Recommended design:

- cards share a sibling/provenance group;
- after a genuine review, same-day due siblings can be buried until the next StudyDay;
- only a presentation adjustment is written;
- each sibling's FSRS due and memory state remain unchanged;
- multiple New siblings can be introduced on separate days without fake review history.

This is a modern quality feature. If v1 must stay narrower, keep it behind a flag rather than designing a schema that cannot support it.

---

## 15. History should be append-only

Every important change should be explainable:

- what happened;
- which rule made it happen;
- what state existed before;
- what state exists after;
- which policy version was active;
- whether it was later undone.

Undo should add an inverse record and restore the exact previous state. It should not erase the original event.

Why:

- audit and debugging remain possible;
- a crash can be recovered;
- duplicate taps can be detected by operation ID;
- FSRS optimization can exclude undone and practice events;
- Mercy can be reversed as one batch;
- future scheduler changes can be replayed against historical facts.

A scheduler without trustworthy history is difficult to improve because every surprising result becomes guesswork.

---

## 16. Statistics are part of correctness

The earlier plan says some statistics can wait. Basic product analytics can wait; scheduler safety metrics cannot.

At minimum, the architect needs to see:

- algorithmic due versus effectively due work;
- how much was moved by Later, auto-overflow, and Mercy;
- future card and topic load;
- automatic postponement percentage;
- protected violations;
- lateness by priority band;
- card retention by priority band;
- actual card/topic mix;
- time spent on cards versus topics;
- topic interval and A-Factor distributions.

### Why these metrics matter

A scheduler can pass unit tests and still fail slowly:

- low-priority topics vanish;
- automatic overflow becomes permanent;
- the top priority band receives worse retention;
- a four-to-one count ratio consumes ninety percent of time in topics;
- tomorrow's queue grows while today's appears clean.

Metrics reveal policy failures before the learner loses months of trust.

Warn when automatic postponement is about thirty percent or more of due work for three consecutive weeks. At that point the collection's demand and the learner's capacity are structurally mismatched.

---

## 17. Concrete failure modes this design prevents

### Priority used as a due date

Result: top topics repeat too often; low topics never become eligible; the scheduler cannot explain whether something was late.

### Postpone recorded as a review

Result: FSRS believes memory changed without evidence; last-review timestamps become false; future intervals and optimization degrade.

### One shared due field

Result: exact intraday card steps and day-level topics fight over semantics; DST and rollover bugs multiply.

### Fresh random sorting

Result: refresh changes the queue, restart changes the queue, and the same overload can postpone different elements repeatedly.

### Independent random future delays

Result: today's backlog is merely moved into future spikes.

### Automatic topic advancement

Result: opening, closing, or extracting from a topic can send it away for weeks without the learner's consent.

### Deleting review history on undo

Result: audits and optimizer filtering become unreliable; duplicate operations are hard to identify.

### Silent formula migration

Result: the same stored interval suddenly means something different after an app update.

---

## 18. An example StudyDay

Assume:

- 240 due review cards;
- 5 due intraday steps;
- 15 available New cards;
- 40 due topics;
- ordinary unique-card cap 200;
- topic cap 50;
- top one percent protected.

The scheduler:

1. admits the five mandatory intraday steps;
2. protects any top-priority due cards and topics;
3. fills remaining card capacity with due reviews;
4. does not admit New cards if regular due reviews were excluded by the cap;
5. admits the due topics because they fit their separate cap;
6. builds a deterministic four-card/one-topic presentation stream;
7. handles excess review backlog according to the selected auto-postpone mode;
8. preserves every FSRS due time even when an excess card receives a calendar adjustment.

If the learner chooses Study More, the app may clear automatic overflow and raise the temporary capacity. It must not undo the learner's manual Later choices or a Mercy plan.

---

## 19. Decisions for the architect to approve

The recommendations below are already used in the coding-agent instructions. Change them deliberately, not implicitly.

### 1. Canonical topic policy

Recommended: new topics use versioned topic_afactor_v1; old fixed-sequence topics remain legacy until explicit migration.

Why: mixing both state transitions is impossible to reason about.

### 2. Provisional A-Factor

Recommended: use the corrected transparent priority term first; keep completion/yield/conversion modifiers disabled but shadow-logged.

Why: it is implementable now and easy to calibrate without pretending to know SuperMemo's private formula.

### 3. Auto-postpone default

Recommended: SuperMemo-like old-backlog-only behavior as default; offer bounded-load behavior as a clearly named modern profile.

Why: fidelity and predictable daily caps are different goals.

### 4. Protected band

Recommended: top one percent.

Why: it resolves the one-versus-five-percent conflict conservatively while keeping the value configurable.

### 5. Card/topic mix

Recommended: four card opportunities per topic, with a maximum ordinary-card gap of eight.

Why: four-to-one matches the plan; the gap guard prevents starvation when mandatory steps or restarts disrupt the pattern.

### 6. Topic completion

Recommended: explicit Finish only.

Why: reaching the end of text does not prove the topic has no remaining value.

### 7. Siblings

Recommended: typed sibling burying enabled by default after migration validation, with a setting to turn it off.

Why: it improves review quality without corrupting FSRS.

### 8. Global priority population

Recommended: all non-deleted learning elements retain a place; lifecycle controls eligibility separately.

Why: suspend/dismiss should not destroy strategic order.

### 9. Mercy and manual Later

Recommended: Mercy removes conflicting automatic overflow but preserves manual Later unless the confirmation explicitly overrides it.

Why: an exceptional bulk tool should not silently cancel an intentional local choice.

### 10. Count versus time

Recommended: count-based admission; record time for diagnostics.

Why: this is closer to the chosen SuperMemo behavior and much easier to make deterministic. Time data can inform a later, separately named policy.

---

## 20. What “near-perfect SuperMemo” can realistically mean

There are three layers of fidelity.

### Layer 1: structural fidelity

We can reproduce this confidently:

- cards versus topics;
- extracts becoming independent topics;
- global relative priority;
- priority-dominated learning;
- topic interval growth;
- separate item/topic randomization;
- mixed study stream;
- protected high-priority material;
- overload sacrifice;
- Mercy-style bulk rescheduling.

### Layer 2: behavioral fidelity

We can get close through controlled observations:

- how A-Factor responds to priority and topic type;
- first topic intervals;
- cloze introduction dispersion;
- amount and distribution of auto-postpone;
- Mercy criteria and ordering;
- topic/card mixing under different settings.

### Layer 3: formula identity

This may be impossible without source code or a large black-box dataset:

- exact A-Factor formula;
- exact priority drift;
- exact multi-criteria Mercy weights;
- exact randomization transforms;
- version-specific hidden heuristics.

The architecture should therefore optimize for **behavioral compatibility plus transparent modern safety**, not make an unverifiable “identical formula” claim.

FSRS for cards is already an intentional departure, and a good one.

---

## 21. The most useful SuperMemo evidence to collect next

More random screenshots will help less than small controlled before/after experiments.

For every experiment, record:

- exact SuperMemo version;
- collection settings;
- home date/time and day boundary;
- element type;
- priority position and percent;
- interval, next repetition, A-Factor, ordinal;
- the exact action taken;
- the same fields afterward.

Highest-value experiments:

1. Move the same topic through top, middle, and bottom priority positions, then perform a normal encounter at each position in cloned collections.
2. Compare a long source and a short extract at the same priority.
3. Extract without confirming a repetition, then inspect whether the parent or child schedule changed.
4. Reach the end of a source and close it without Finish.
5. Create several extracts and clozes from one passage and record their first dates.
6. Carry a small known backlog across midnight/rollover and compare old backlog with work newly due today.
7. Run Mercy on a ten-element subset with each criterion setting, saving the preview and final dates.
8. Repeat the same queue build to see which randomization is stable within a day.

Store the results as fixtures, not only images. A compact table or JSON/CSV export will let a future policy be replayed and tested.

---

## 22. Delivery roadmap

### Phase 1: make state trustworthy

- separate card and topic schedules;
- preserve canonical due dates;
- add typed schedule adjustments;
- add append-only events and exact undo;
- pin and test the FSRS adapter.

Why first: formula tuning is meaningless if calendar actions can corrupt memory state.

### Phase 2: make priority and queues deterministic

- one global order;
- derived percent;
- separate eligible lanes;
- protected admission;
- four-to-one merge;
- repeatable randomization.

Why second: the learner must see stable, explainable behavior before overload automation is added.

### Phase 3: make overload safe

- future capacity ledger;
- SuperMemo-like auto-postpone;
- Study More;
- Smart Postpone;
- safety metrics.

Why third: automatic sacrifice is high-risk and needs trustworthy state plus visibility.

### Phase 4: recovery and refinement

- Mercy preview/apply/undo;
- sibling controls;
- long-horizon simulations;
- controlled SuperMemo calibration;
- experimental topic modifiers.

Why last: these features depend on all earlier boundaries and are easier to validate once history and metrics exist.

---

## 23. How to judge success

The design is working when:

- a calendar move can never be mistaken for learning;
- the learner can explain why an element appeared;
- high-priority material is protected under overload;
- low-priority material recedes without silently vanishing;
- topics remain present in a card-heavy session;
- New cards do not worsen an existing review backlog;
- refresh and restart do not reshuffle the day;
- a three-week absence is spread into capacity rather than a new spike;
- every bulk operation previews and undoes exactly;
- a future topic formula can be tested and versioned without rewriting history;
- the metrics make overload and priority protection visible.

That is the foundation needed before chasing the last few percent of SuperMemo fidelity.

---

## Research references

- Priority queue: https://www.super-memory.org/archive/help/priority.htm
- Incremental reading: https://www.super-memory.org/archive/help/read.htm
- Element data: https://help.supermemo.org/wiki/Element_data
- Element parameters: https://www.super-memory.org/archive/help/elparam.htm
- Element types: https://www.super-memory.org/archive/help/eltypes.htm
- Forgetting index: https://www.super-memory.org/archive/help/fi.htm
- Postpone: https://www.super-memory.org/archive/help/postpone.htm
- Mercy: https://www.super-memory.org/archive/help/mercy.htm
- Mercy criteria: https://www.super-memory.org/archive/archive/help16/mercycrit.htm
- Cloze interval: https://supermemo.guru/wiki/Cloze_interval
- Learn menu and sorting: https://www.super-memory.org/archive/help/learnmenu.htm
- Subset operations: https://www.super-memory.org/archive/help/subsetop.htm
- FSRS tutorial: https://github.com/open-spaced-repetition/fsrs4anki/blob/main/docs/tutorial.md
- Dart fsrs releases: https://pub.dev/packages/fsrs/versions
