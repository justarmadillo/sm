# SuperMemo 20 topic/extract scheduler: executable-derived clone specification

## 1. Identity, scope, and fidelity boundary

This document describes the scheduling behavior recovered from this exact local
executable:

```text
File:    sm20.exe (found in /plans/sm20_binary)
SHA-256: 72A9D5FA6AD7D05D0478B7F8C77007B2001DE93D26F963DF4923E0BAA462A9AE
Image base: 0x00400000
```

No web page, article, published SuperMemo formula, or older SuperMemo version is
used as algorithmic evidence. Routine addresses are virtual addresses in the
hashed executable. Names in this document are descriptive names assigned from
the code unless an embedded Delphi name made the meaning explicit.

The target is the complete topic/extract scheduling path and every identified
queue, priority, postponement, and Mercy interaction that can affect it. The
item/card memory model is not reconstructed, but cards still matter wherever
SM20 includes them in a shared priority population, daily queue, postponement
tool, or Mercy calculation.

“Identical” has two parts:

1. **Algorithm identity:** implement the operation order, rounding, Real48
   writes, rank quantization, sort ties, and PRNG consumption specified here.
2. **State identity:** migrate the collection records, all-element priority
   order, queues/settings, internal O-Factor optimization state, and current
   PRNG seed. These values are not constants inside `sm20.exe`.

With only the formulas but not that live state, a port can reproduce SM20's
rules but cannot continue the same future random sequence or the same rank- and
collection-dependent results.

SuperMemo 20 has one scheduler, **Algorithm SM-20**. Names like SM-2, SM-15,
SM-19 and FSRS that appear below are its internal component models, each with
its own state and its own predicted interval, combined into the weighted
interval SM20 actually schedules. They are not alternative schedulers a user or
a clone chooses between.

**Deliberate departures in this repository.** Everything below describes
`sm20.exe`. Where this repository knowingly does something else, it is stated
at the point it applies. There is one such departure today: Mercy's investment
estimate uses a card's measured FSRS stability instead of the §12.1 O-Factor
matrix product, because the two are the same quantity and this repository
measures it. Topics keep the matrix product. See §13.8.

## 2. The central result

Topics and text extracts use the same repetition scheduler. A topic's next
automatic interval is based only on its previous interval, stored A, review
mode, and two values from the global Delphi PRNG. Priority is not an input.

At a committed repetition, SM20 performs two independent adaptations:

- it updates A from the relationship between the old and selected intervals;
- it moves the element in the collection-wide priority ranking from that same
  interval relationship.

No priority-only command reads or writes A. There are, however, two different
commands with the same Increase/Decrease labels:

- the current-element shortcuts move by numerical targets `-0.1` and `+0.1`
  percentage point;
- the browser/subset commands scale each live rank-derived percentage, with
  defaults of `50%` for Increase and `150%` for Decrease.

The current-element UI first runs a separate pre-command/commit check at
`0xF2BBF0`; if that commits an unfinished repetition, A changes because of the
repetition, not because of the priority command. The browser operations do not
run that current-element pre-commit.

Most overload tools are not repetitions. They rewrite the due date and stored
interval through the low-level rescheduler and therefore normally leave A,
priority, repetition count, and last-review day unchanged.

## 3. Numeric contract

### 3.1 Types and constants

Use these constants exactly:

```text
A_MIN                 = 1.01
A_SCHEDULING_MAX      = 3.0
A_STORAGE_MAX         = 6.0
MAX_STORED_INTERVAL   = 44,530 days
UINT16_MAX            = 65,535
```

Scheduling intervals and collection-relative days are predominantly 16-bit
fields. The last-review field used by the identified record path is signed;
the scheduled due-day domain is unsigned. A and the last-interval ratio are
six-byte Delphi `Real48` values.

Unless a section says otherwise, conversion from floating point to integer is
nearest integer with ties to even (`round_even`). In the executable this is the
default SSE conversion behavior. `trunc` means truncation toward zero.

Do not algebraically rearrange formulas in a strict clone. Preserve the shown
operation order, because a last-bit difference can cross an integer-rounding
boundary.

### 3.2 Delphi Real48 storage

Routines: decode `0x410400`; encode `0x410490`.

Decode six little-endian bytes as follows:

```text
payload  = little_endian_uint48(bytes)
exp48    = payload & 0xFF
if exp48 == 0: return 0.0

mantissa = (payload >> 8) & ((1 << 39) - 1)
sign     = (payload >> 47) & 1
exp64    = exp48 + 0x37E
bits64   = (sign << 63) | (exp64 << 52) | (mantissa << 13)
return IEEE754_double_from_bits(bits64)
```

Encode a finite IEEE-754 double as follows:

```text
exp64      = (bits64 >> 52) & 0x7FF
exp48      = exp64 - 0x37E
sign       = bits64 >> 63
fraction   = bits64 & ((1 << 52) - 1)
mantissa   = fraction >> 13
discarded  = fraction & 0x1FFF

if discarded > 0x0FFF:          # includes the exact half-way value
    mantissa += 1
    if mantissa > (1 << 39) - 1:
        mantissa = 0
        exp48 += 1

if exp48 < 0: exp48 = 0
if exp48 > 255: overflow

payload = exp48 | (mantissa << 8) | (sign << 47)
return uint48_little_endian(payload)
```

This Real48 conversion's half-way behavior is not banker's rounding. Every
algorithm below that says “store A” or “store ratio” must encode and later
decode through Real48; retaining an unquantized double will drift.

Useful byte vectors:

```text
0.0  -> 000000000000
1.0  -> 810000000000
1.01 -> 817b14ae4701
1.2  -> 819a99999919
2.0  -> 820000000000
3.0  -> 820000000040
6.0  -> 830000000040
```

### 3.3 Global Delphi PRNG

Routines: core `0x40A350`; wrappers `0x40A390`; startup randomization
`0x40A310`.

The state is one unsigned 32-bit integer shared by the application:

```text
advance():
    seed = (seed * 0x08088405 + 1) mod 2^32
    return seed

Random():
    return advance() * 2^-32

Random(N):
    return high_uint32(advance() * uint32(N))
```

Starting from seed zero, the first six advanced states are:

```text
1, 134775814, 3698175007, 870078620, 1172187917, 2884733762
```

At program randomization, SM20 first consumes `Random(0x7FFFFFFF)`, XORs that
value into the high half of `QueryPerformanceCounter` (or the tick fallback),
then XOR-folds the resulting high and low halves into a new 32-bit seed. This
does not reconstruct the state of an already-running session. Exact
continuation requires exporting the live seed after every earlier random
consumer, not merely deriving the startup seed.

### 3.4 Random interval dispersion

Routine: `0xCF9E20`.

```text
spread(center, width):
    # Apply these four assignments in this exact order.
    width = max(width, 4)
    width = min(width, center + 4)
    width = max(width, 0)
    width = min(width, 100)

    u1 = Random()
    z  = -10.857763300760043
         * ln(1 - (u1 / 2) * 1.979793637145314)

    u2 = Random()
    if u2 > 0.5:
        z = -z

    return max(1, center + (z / 50) * width)
```

Every call consumes exactly two PRNG values. The caller normally applies
`round_even` to the returned value.

## 4. State that an exact port must preserve

### 4.1 Per element

At minimum retain:

- stable element ID and type;
- deleted/intact and memorized/pending/dismissed state;
- repetition count and lapse count;
- current interval;
- collection-relative last-review day and scheduled due day;
- raw six bytes of A for topics/extracts;
- raw six bytes of the last-interval ratio;
- recent and total postponement counters;
- membership/order in Outstanding, Pending, Final Drill, and relevant subset
  queues.

Identified scheduling-record offsets in the record used by these paths are:

```text
+0x00  element type                UInt8
+0x01  status                      UInt8: 0 pending, 1 memorized,
                                          2 dismissed, 3 deleted
+0x0C  repetition count            UInt16
+0x0E  lapse count                 UInt16
+0x10  interval                    UInt16
+0x12  last-review collection day signed 16-bit
+0x1C  A                           Real48
+0x22  last interval ratio         Real48
+0x28  repetition-history block ID UInt32
+0x31  recent postponement count   UInt32
+0x35  total postponement count    UInt32
+0x6D  learning-control byte       UInt8; Forget writes 8
```

Records are a flat array of stride `118` (`0x76`) bytes with no file header,
so record `n` begins at `n * 118` in `info/ElementInfo.dat`. Confirmed against
two collections written by the executable: a 118-byte file holding one record
and a 472-byte file holding four, with A landing on `+0x1C` in every one.

The type byte at `+0x00` is not fully enumerated by the paths above. Type `0`
is a topic, `1` an item, and `2` an extract, as section 10.3 assumes. Type `4`
is observed on the collection root, which the executable creates with status
`2` and never schedules; section 10.3 already treats `4` as topic-family. That
last mapping rests on a single observed record rather than on an identified
routine.

The due date is represented by the collection's repetition schedule as well
as by the invariant `last_review + interval` after ordinary scheduling. Queue
membership is separate from the due schedule.

### 4.2 Collection-wide state

Retain all of the following for behavioral identity:

- the priority order of **every intact element**, including cards/items,
  topics, extracts, pending elements, and dismissed elements. Confirmed
  against a collection written by the executable: `info/priority.sub` lists
  every element id, and the collection root — status `2`, dismissed — is one
  of them. Dropping dismissed elements would change `N` and therefore every
  rank-derived percentage in the collection;
- the current global 32-bit PRNG seed;
- collection learning-start day and today's collection-relative day;
- the combined Outstanding order plus its item and topic membership lists;
- Pending and Final Drill queues and the current learning mode;
- daily queue settings: topic percentage, both randomization sliders,
  auto-sort enabled state, and last automatic-sort day;
- Smart Postpone profiles, branch profile assignments, last automatic-run day,
  and last collection-use time;
- Mercy settings and the internal per-collection O-Factor optimization record
  whose live 20 by 20 matrix is used by its investment estimate;
- the branch tree and any selected subset queues.

Cards cannot simply be removed from the shared priority order when cards are
scheduled by FSRS. Doing so changes `N`, all rank-derived percentages,
reinsertions, queue keys, extraction priorities, and Smart Postpone decisions.

## 5. Topic/extract repetition scheduler

### 5.1 Default blank-topic A and the text-length override

Ordinary element creation follows:

```text
AddNewElement (0xD7E9B0)
    -> allocate/initialize record (0xD72070)
    -> initialize 0x76-byte element data (0xD72C40)
```

The initializer clears the record, stores the element type, and writes the
six-byte field at offset `+0x1C`. For every non-item type—including a normal
blank topic—it writes:

```text
81 9A 99 99 99 19    # Real48; decoded 1.2000000000007276, displayed 1.2
```

For item type 1 it instead writes `82 00 00 00 00 60` (`3.5`) to the same
type-dependent field. Thus **an ordinary blank topic starts with A displayed
as 1.2**. Initial memorization at interval one does not alter it.

Routine `0xCF73F0` is a separate **text-length A override**, not the generic
blank-topic initializer. Its direct callers are specialized import, paste,
content-processing, and extraction paths. Let `N` be the length of SM20's
processed internal text in Delphi UTF-16 code units, not source-file bytes,
Unicode scalar values, DOM nodes, or original HTML length:

```text
if N == 0:
    override_A = 2.0
else:
    x = 10000 / N
    override_A = 1.25 + (0.75 * x) / (50 + x)
```

For `N > 0`, the equivalent mathematical expression is
`1.25 + 150/(N+200)`, but the first operation order is the clone contract.
When a caller invokes this override, store its result as Real48.

The important distinction is:

```text
ordinary blank topic allocation                -> A = Real48(1.2)
an explicit call TextLengthAF(0) at 0xCF73F0   -> A = 2.0
```

Paste Into New Topic (`0xF2DF80`) only reaches its text-length write when it
obtains a nonempty internal text string; an empty paste retains the record
default. The identified HTML/content import path around `0xF0A2A0` can
explicitly overwrite the default using the processed length. Neither path
inherits A from another scheduled topic.

### 5.2 Next automatic topic interval

Routine: `0xE145A0`.

For ordinary review, let `I` be the old stored interval and `A` the decoded
stored A:

```text
As = clamp(A, 1.01, 3.0)

if I == 0:
    raw = As * As * As
else:
    raw = I * As

raw       = min(raw, 44530)
center    = round_even(raw)
width     = center - I
candidate = round_even(spread(center, width))

if candidate <= I:
    candidate = I + 1

return candidate
```

Consequences:

- one automatic interval consumes exactly two global PRNG values;
- stored A can reach `6.0`, but interval generation never uses more than
  `3.0`;
- the automatic interval is forced to be strictly larger than the previous
  stored interval;
- dispersion width is capped at 100 after the unusual ordered clamps in
  section 3.4.

Seed-zero vectors before Real48 state changes:

```text
A=2.0, I=0   -> 8
A=2.0, I=1   -> 2
A=2.0, I=10  -> 20
A=3.0, I=100 -> 300
A=6.0, I=100 -> 300    # scheduler clamp to 3.0
A=1.01,I=100 -> 101
```

### 5.3 A update after an interval choice

Routine: `0xCF7800`.

```text
adjust_A(A, old_interval, new_interval, bulk):
    old = max(old_interval, 1)
    new = max(new_interval, 1)

    if old == new:
        return A unchanged

    r = max(new / old, old / new)
    K = 80 if bulk else 15
    d = max((A - 1.01) * r / (r + K), 0.001)

    if new > old:
        result = A + d
    else:
        result = A - d

    result = clamp(result, 1.01, 6.0)
    return Real48_round_trip(result)
```

The interval is selected from old A first. This update affects the next
repetition. “Bulk” is the flag passed by the relevant bulk/forced operation;
it makes adaptation much smaller by changing `K` from 15 to 80.

### 5.4 Independent priority drift after an interval choice

Routine: `0xC99B30`.

This routine normalizes only the old interval. It deliberately leaves a new
interval of zero as zero:

```text
adjust_priority(element, old_interval, new_interval, bulk):
    old = max(old_interval, 1)
    new = new_interval

    if old == new:
        return

    c = 80 * (1 - min(old, new) / max(old, new))
    if bulk:
        c = c / 3
    s = (100 - c) / 100

    P = current rank-derived percentage
    if new < old:
        target = P * s
    else:
        target = P / s

    old_position    = current position
    target_position = position_for_percentage(target)

    if target_position == old_position:
        if new < old: target_position -= 1
        else:         target_position += 1
        target_position = clamp(target_position, 1, population_size)
        target = percentage_for_position(target_position)

    SetPriority(element, target)
```

A shorter interval moves toward numerically lower priority (higher importance);
a longer interval moves toward numerically higher priority (lower importance).
When quantization would hide the change, SM20 forces one rank. A new interval
of zero yields `c=80` and a shorter-interval target of `0.2*P`.

### 5.5 Commit of an ordinary repetition

Main routines: commit `0xD7CA60`; scheduling path `0xD8AFF0`; memorization
entry points `0xD8AFB0` and `0xD8EDD0`.

For a later automatic repetition:

```text
oldI = stored interval
oldA = decoded stored A
J    = next_topic_interval(oldA, oldI)

repetitions += 1
last_review  = Today
A            = adjust_A(oldA, oldI, J, bulk)
adjust_priority(element, oldI, J, bulk)

if this is the first repetition or oldI == 0:
    ratio = J
else:
    ratio = J / oldI
ratio = max(ratio, 1)
store ratio as Real48

stored_interval = min(J, 44530)
due_day         = last_review + stored_interval
```

An explicitly supplied interval can be as large as `65,535`. When it exceeds
`44,530`, the uncapped explicit value is used for A and priority adaptation;
only the stored interval is capped afterward.

With the ordinary default first-interval settings, memorizing a new
topic/extract supplies interval `1`:

```text
repetitions = 1
last_review = Today
interval    = 1
due_day     = Today + 1
```

Old zero and new one both normalize to one in A adaptation, and old is
normalized to one in priority adaptation, so initial memorization leaves both
A and priority unchanged. It consumes no random number because the interval is
explicit.

The browser **Remember** command reaches the same commit through `0xD62E20`
and exposes the collection's two first-interval words at settings offsets
`+0x2D` (`lo`) and `+0x2F` (`hi`):

```text
if hi == 0:
    J = next generated interval          # -1 sentinel to the commit path
elif hi == lo:
    J = hi                               # explicit, no PRNG
else:
    J = round_even(lo + Random() * (hi - lo))
    J = clamp(J, 1, 365)                 # one PRNG value
```

For a topic and `hi == 0`, the generated path is section 5.2 and consumes two
PRNG values. If the chosen first interval is not one, the normal old-zero to
new-`J` A and priority adaptations do run; “initial memorization leaves A and
priority unchanged” is therefore specifically the explicit interval-one
case.

### 5.6 Forced-topic modes and anti-cramming rules

In review modes 5 and 6, `0xE145A0` replaces the ordinary A branch with:

```text
center    = max(floor(old_interval / 2), 1)
width     = max(center / 2, 1)
candidate = round_even(spread(center, width))
if candidate <= old_interval:
    candidate = old_interval + 1
```

These modes still consume two PRNG values and still enforce strict interval
growth. The force-topic commit path at `0xD66670` exits without recording a
repetition when `last_review >= Today`. Otherwise it records a normal topic
repetition with the selected forced interval, including repetition count,
last-review day, A update, priority drift, ratio, and new due date.

The identified anti-cramming behavior is therefore concrete rather than a
separate hidden formula:

- an automatic result may not be less than or equal to the old interval;
- a forced topic cannot be committed twice on the same collection day;
- Later Today also refuses a non-outstanding element already reviewed today.

## 6. A-factor transitions outside ordinary review

### 6.1 Text extraction

Routines: A blend `0xCF6130`; extract creation `0xF25670`.

Let `S` be the source's decoded stored A and `N` the processed child text
length:

```text
textA = initial_text_A(N)       # calculate without an intermediate store
x     = max(S - 1.01, 0)
q     = 0.9 * x / (0.29 + x)

child_A       = (1 - q) * S + q * textA
source_A_next = 1.01 + 0.95 * (S - 1.01)
```

Store child and source results separately as Real48. The child's calculation
uses the source A from before the source reduction.

The general Modify A operation at `0xD5C960` is:

```text
A_next = 1.01 + multiplier * (A - 1.01)
```

and also stores through Real48.

### 6.2 Extraction priority and complete child initialization

Before either text or media extraction:

```text
source_priority_target = current_source_priority * 0.995
SetPriority(source, source_priority_target)
```

The unquantized local target, not the percentage read back after rank
insertion, is used in the child formula.

For a text extract, routine `0xC99A00` computes:

```text
P    = source_priority_target
low  = 0.7 * P

if P > 0:
    high = exp(1.7 * exp(0.2 * ln(P)))
else:
    high = 0

if low > high:
    low  = high
    high = 1.3 * high

high = clamp(high, 0, 100)
span = (high - low) * N / (N + 100)
child_priority_target = clamp(low + Random() * span, 0, 100)
```

For a media/play extract:

```text
child_A = 3.0
child_priority_target = 3 + P * (0.5 + 0.3 * Random())
```

Each child path consumes one PRNG value for priority. The target is assigned,
the child is memorized at interval one, and the same child target is assigned
again. A text child receives the blend from section 6.1; a media child does not
apply the text source-A reduction.

### 6.3 Split, duplicate, HTML import, paste, and clone

The transitions are:

| Operation | A behavior | Scheduling behavior |
|---|---|---|
| Split (`0xF213C0` -> `0xF3E430`) | Repeatedly invokes text extract generation. Each child sees the source A left by the preceding child. | Each child is independently prioritized and memorized at interval one. |
| Ordinary blank topic (`0xD7E9B0` -> `0xD72070` -> `0xD72C40`) | Writes raw Real48 `819a99999919`, displayed as `1.2`. | Subsequent memorization at interval one leaves A unchanged. |
| HTML/content import (`0xF0A2A0`) | Explicitly overrides the record default from processed imported text length. | Subsequent memorization follows the interval-one path. |
| Paste Into New Topic (`0xF2DF80`) | Nonempty internal text invokes the text-length override; an empty string retains default `1.2`. | Subsequent memorization follows the interval-one path. |
| Duplicate scheduled element (`0xF4B9B0`, copy `0xD7E150`) | If source and destination types match, copies the six A bytes bit-for-bit; no A formula runs. | Copies scheduling state, then a memorized duplicate is rescheduled to `Today+1` through `0xD82AA0`. Its stored interval becomes target minus copied last-review day, so it is not necessarily one. Pending/dismissed status is copied. |
| UI “clone” at `0xF0A720` | No scheduled-element A transition was found. | This path clones a component, not a scheduled element. |
| Current-element Increase Priority | No A read or write. | Calls numerical priority delta `-0.1`, after the independent UI pre-commit check. |
| Current-element Decrease Priority | No A read or write. | Calls numerical priority delta `+0.1`, after the independent UI pre-commit check. |

For a split into `k` text children, the idealized source distance from 1.01 is
multiplied by `0.95^k`, but an exact implementation must Real48-round after
every child rather than use that closed form. Priority likewise undergoes a
separate rank insertion on every child, so repeated multiplication alone is
not equivalent.

### 6.4 Browser Set A and Modify A

Handlers `0xC70C80` and `0xC70D20` dispatch subset operations `0x15` and
`0x16`. They apply only to normal type-zero topics/extracts; deleted records
are skipped by the outer dispatcher, while pending, memorized, and dismissed
type-zero records are all eligible.

**Set A** starts the dialog at `1.10`, accepts `1.01..3.00`, and directly
stores the selected Double through Real48 (`0xD5C790`). **Modify A** starts at
`1.00`, accepts `0.20..2.00`, and for every eligible topic executes:

```text
A = Real48(1.01 + multiplier * (decode(A) - 1.01))
```

Neither command changes interval, due date, priority, repetitions,
last-review day, or any queue. The primitive Set A store can represent the
wider storage domain, but this browser dialog deliberately limits direct
input to `3.00`.

## 7. Collection priority model

Routines: percentage `0xC99450`; position conversion `0xC99880`; insertion
`0xC9A680`; set operation `0xC9B210`.

Priority is a position in one collection-wide ordered population, not a
floating field owned independently by each topic. Position one is highest
importance and displays `0%`; the last position displays `100%`.

For a population of `N` and one-based position `pos`:

```text
percentage(pos, N):
    if pos < 2: return 0
    return 100 * (pos - 1) / (N - 1)

position(P, N):
    return round_even((P / 100) * (N - 1)) + 1
```

Setting priority removes the element first. Let `M` be the count remaining:

```text
P = clamp(P, 0, 100)

if P == 100:
    insertion_position = M + 1
else:
    insertion_position = round_even((P / 100) * M) + 1
```

The inserted element's displayed percentage is then recomputed from its new
rank. Every intact rankable collection element participates, not just the
topics selected for this port. Deleted elements are not rankable; when a
deleted ID is encountered by daily queue sorting it is treated as priority
`100`.

All midpoint conversions use nearest-even. This is also the tie rule that
determines whether `±0.1` changes a rank. Manual priority drift only changes
the ordered population. Review-time priority drift uses section 5.4 and forces
one rank when its calculated target quantizes back to the old rank.

### 7.1 Browser/subset priority operations

Handlers `0xC70A10`, `0xC6F5E0`, `0xC70EB0`, and `0xC6F420` select operation
codes `0x0A..0x0D`; worker `0xD45E30` applies them in the subset's stored queue
order. These are different from the current-element `±0.1` shortcuts.

The dialog normalizes its three numerical outputs as follows. For
Increase/Decrease with **Limit changes** unchecked, it first forces `lo=0`,
`hi=100`. For Spread/Adjust only, it forces `change=0` and expands an exactly
equal requested range:

```text
if lo == hi:
    lo -= 0.1
    hi += 0.1
```

The equal-range expansion does not run for Increase/Decrease when limits are
enabled. All four modes then apply:

```text
lo     = clamp(lo,     0,      99)
hi     = clamp(hi,     0.0001, 100)
change = clamp(change, 0,      1000)
if lo > hi: swap(lo, hi)
```

Before applying any operation, it requires:

```text
selected_count <= position(hi) - position(lo) + 1
```

or cancels with an insufficient-priority-slots message. Increase initializes
`change=50`, with a track range `0..100`. Decrease initializes `change=150`,
with a track range `100..1000`.

For each eligible element, let `P` be the percentage read from the **current**
live rank order at that iteration:

```text
Increase:
    x = clamp(P * change / 100, lo, hi)
    if x > P: x = P
    target = min(x, hi)

Decrease:
    x = clamp(P * change / 100, lo, hi)
    if x < P: x = P
    target = min(x, hi)

Adjust:
    if oldMax == oldMin:
        target = lo
    else:
        target = lo + (hi - lo) * (P - oldMin) / (oldMax - oldMin)
    target = min(target, hi)
```

For Adjust, the preparatory scan initializes `oldMin=100`, `oldMax=0` and
updates that range from **memorized status-1 elements only**. Application then
includes both status 0 and status 1. This distinction, including the unchanged
`100/0` sentinels when no memorized element is present, is executable behavior.

Spread computes one step before mutation:

```text
if selected_count == 1:
    step = 0
else:
    step = (hi - lo) / (selected_count - 1)

step = max(step, 100 / all_priority_population_count)
target(k) = min(hi, lo + (k - 1) * step)       # k is one-based
```

The worker skips deleted status 3 before incrementing `k`. Dismissed status 2
increments `k` but is not moved, so a selected dismissed record creates a gap
in Spread. All four priority operations move only status-0 and status-1
records and never touch A.

Every target is immediately passed to Set Priority, removing and reinserting
the element. Consequently this is a sequential rank algorithm: an earlier
move can shift the percentage read for a later Increase, Decrease, or Adjust
element. A clone must not calculate all targets from one frozen percentage
snapshot.

## 8. Low-level rescheduling and “Later” behavior

### 8.1 General due-date rescheduler

Wrapper `0xD62F00` calls `0xD82AA0` with an element and an absolute target
collection day.

For an already memorized element:

```text
remove old scheduled repetition
oldI     = max(stored_interval, 1)
oldRatio = decoded stored last-interval ratio

if target_day > last_review:
    actualNewI = target_day - last_review
    newRatio   = max(1, (actualNewI / oldI) * oldRatio)
else:
    actualNewI = 1
    newRatio   = 1
    last_review = target_day - 1

store actualNewI
store Real48(newRatio)
if actualNewI > oldI:
    recent_postponements += 1
    total_postponements  += 1
schedule target_day
```

This path does not update A or priority and does not increment repetitions.
For a nonmemorized element it instead computes
`max(target_day-Today, 0)` and enters the memorization path. This edge case is
important when Smart Postpone is explicitly allowed to process
non-outstanding pending elements: it can admit/memorize them rather than merely
move an existing repetition.

### 8.2 Delay Element

Routine: `0xD5C9C0`.

```text
age  = max(Today - last_review, stored_interval)
newI = round_even(age * factor)
if newI <= age:
    newI = age + 1
newI   = min(newI, 44530)
target = last_review + newI
RescheduleElement(target)
```

For a memorized element this changes due date, stored interval, ratio, and—if
the interval grew—postponement counters. It does not change A, priority,
repetitions, or last-review day.

### 8.3 Manual Reschedule / Jump Interval

`ScheduleInInterval` at `0xF0E7F0` sets
`target_day = Today + entered_remaining_interval`. `JumpIntervalExt` at
`0xF0E660` caches the old stored interval, invokes that low-level reschedule,
then, for normal topic type zero, performs:

```text
A = adjust_A(A, old_stored_interval, entered_remaining_interval, bulk=false)
if modify_priority:
    adjust_priority(element, old_stored_interval,
                    entered_remaining_interval, bulk=false)
```

The standard Reschedule UI (`0xCE8D10`) passes `modify_priority=true`.

This subtlety must be cloned exactly: the rescheduler stores an interval equal
to `target_day-last_review`, but A and priority compare the old stored interval
with the user-entered **remaining** interval.

### 8.4 Later Today

Routine: `0xF0E4C0`.

- If the element is already Outstanding, no due date, interval, A, priority, or
  repetition field changes. The user is asked for a target position in the
  Outstanding queue and the entry is moved there; inside a browser review the
  element is additionally dropped from the review subset. See “The shift” and
  “The mode gate” below.
- If it is not Outstanding and `last_review == Today`, the command warns and
  does nothing. The exact message names the alternative:

  ```text
  Element has been reviewed already
  Use Ctrl+Shift+D instead (Add to Drill)
  ```
- Otherwise it calls `JumpIntervalExt(0, modify_priority=false)` and then
  shifts the queue entry. The target due day becomes Today; the stored interval
  becomes `Today-last_review` through the low-level rescheduler. For a normal
  topic, A is adapted from `(old_stored_interval, 0)`, where the A routine
  normalizes zero to one. Priority is not changed.

There is no separate “Later adjustment” field in these paths. The operation is
either a queue-only shift or an actual due-date/interval rewrite.

The executable's embedded menu resources name the command twice, once on the
element menu and once on the repetition popup:

| Menu item | Caption | Embedded hint |
|---|---|---|
| `MILaterToday` | `Later today` | Schedule the element for review later today |
| `MILaterToday` | `Later today` | Move the repetition to later today (as if it never happened) |

“As if it never happened” is the operative phrase, and it is independent
confirmation of the first branch above: a Later Today is not a repetition and
must not be counted as one, neither in statistics nor in a session counter.

The surrounding items on those menus are the commands that *do* carry a
duration, which is what makes Later Today's absence of one deliberate rather
than an omission:

| Menu item | Caption | Embedded hint |
|---|---|---|
| `MIJumpInterval` | `&Reschedule` | Schedule the next repetition on a given day |
| `MIReschedule` | `Reschedule` | Skip that repetition and schedule it on another day |
| `MIExecuteRepetition` | `Execute repetition` | Execute repetition and manually set the interval |

#### The shift: the user chooses the position

The already-queued branch is not an automatic reordering. `0xF0E870` prompts:

```text
if element not in collection.outstanding:
    "Element not in the outstanding queue"
    "Cannot shift its outstanding position"        # 0xFA5470, refuses
    return

default = UInt32 at outstanding_queue + 9
if InputNumber("Shift to which position in the outstanding queue?", default):
    0xD64480(collection, element_id, position)
```

So Later Today has **no duration and no fixed distance**. It asks for a target
position in today's Outstanding queue, pre-filled from the queue structure, and
`0xD64480` moves the entry there. This is the same numeric-input pattern as
`Every which element?` on batch Add to Outstanding, and it means the distance
is user input rather than a constant to recover.

The pre-filled default is the `UInt32` at offset `9` of the outstanding-queue
record. That field is not otherwise identified here; the reading consistent
with the dialog is the queue's element count, which offers the end of the queue
as the default answer.

#### The mode gate: leaving a browser review

`0xF0E4C0` runs the prompt above first, then guards a second step on a mode
byte at `+0x23F0` of the calling form:

```text
0xF0E870(form, element_id)                     # the prompt and the shift

v3 = form[+0x23F0]
gate = v3 <= 7 and ((1 << v3) & 0xE0) != 0     # true only for v3 in 5, 6, 7

if gate:
    type = 0xD59F10(collection, element_id)
           0xD57A80(collection, element_id, type)
           0xF4E400(form, form[+0x23F1])
```

`(1 << v3) & 0xE0` selects bits 5, 6 and 7, so this runs only while the
learning mode is one of the browser review modes of section 9.7, never in the
ordinary Outstanding stage.

`0xD59F10` reads the element's type byte, defaulting to `3` when the id is
zero:

```text
type = 3
if element_id != 0:
    0xD73490(collection, &saved)              # save current position
    0xD71680(collection, &type, element_id)   # read the type byte
    0xD626C0(collection, saved)               # restore
return type
```

`0xD57A80` then drops the element from the two queues held on the global at
`off_1164810` and decrements the matching counter:

```text
if 0xD58A10(collection):
    if global[+68] != 0:
        remove element from global[+68]
    if global[+60] != 0 and element in global[+60]:
        remove element from global[+60]
        if type == 1:  global[+11] -= 1        # item counter
        else:          global[+12] -= 1        # topic-family counter
```

Those are not the collection's Outstanding queue — that one lives at
`collection + 237` and is what `0xF0E870` shifts. They are the current review
session's queues, so the second step means: inside a browser review, Later
Today shifts the element's Outstanding position **and** removes it from the
review subset, advancing the review past it. The `type == 1` split is the item
versus topic-family distinction of section 10.3.

**Deliberate divergence in this port.** SM20 prompts; this app does not. It
moves the element to the end of the combined Outstanding queue without asking,
which is the dialog's own default answer, so the common case is identical and
only the ability to choose a nearer position is missing. That was a considered
product decision rather than an unimplemented detail: a dialog on every Later
buys one rarely-wanted choice at the cost of a keypress on every use.

Anything that needs exact SM20 parity — a migration comparison, or a
conformance run against the executable — has to account for this, because a
user who answers the prompt with anything other than the default produces a
different queue order from this port.

### 8.5 Advance Topics, Items, and All elements

Entry handlers `0xC72FB0`, `0xC72FD0`, and `0xC72FF0` pass type masks `3`,
`2`, and `1`, respectively, to worker `0xB24F00`. Thus **All elements** means
only normal topics/type 0 plus items/type 1; other record types are not selected
by this command. The dialog default is 30 days, maximum 500, and minimum 1 for
Topics or 2 whenever Items are included.

For every source-queue record, in order:

```text
if (1 << type) & typeMask == 0: continue
if status != 1:                         continue
if last_review == Today:                continue
if old_interval <= D:                   continue

r = round_even(Random() * D) + 1        # exactly one PRNG value

if type == 1:                           # item/card branch
    target = Today + r
    r = max(target - last_review, 2)

if r >= old_interval:                   continue

if type == 0:
    ForceTopicRepetition(interval=r, bulk=true)
else:
    RescheduleElement(last_review + r)
```

The nearest-even conversion is intentional: `r` has domain `1..D+1`, not
`1..D`, and its two endpoint bins have half the interior width. The draw is
already consumed when the `r >= old_interval` test rejects the element.

For a topic/extract, Advance is a real forced bulk repetition. The stronger
callee guard also refuses `last_review >= Today`; a future/corrupt
last-review value can therefore consume the draw and still produce no write.
On success it increments repetitions, sets last review to Today, updates A
with the bulk denominator 80, updates priority with bulk correction divided by
three, stores the new ratio/interval/due day, and consumes no additional PRNG
values. It is not a due-date-only overload operation.

The item branch is a low-level reschedule to approximately `Today+r`; it does
not commit a card repetition and therefore does not run topic A or
interval-driven priority adaptation.

## 9. Daily Outstanding queue

### 9.1 Queue stores

Queue creation at `0xD65EA0` identifies these collection database members:

```text
+0xE5  repetitions.dat
+0xCD  intact.dat / Pending
+0xD5  drill.dat / Final Drill
+0xDD  priority
+0xED  Outstanding.sub (combined queue)
+0xF5  OutstandingItems
+0xFD  OutstandingTopics
```

Daily automatic sorting (`0xD65D30`) runs only when enabled, Today differs
from the stored last-auto-sort day, and the combined Outstanding queue is not
empty. It does not reseed the PRNG.

### 9.2 Priority key and exact sort ties

Main daily routine: `0xB28180`. For each combined Outstanding ID, membership
in `OutstandingItems` determines the item list; all remaining IDs go to the
topic list. This classification is queue-membership based, not a fresh element
type test.

```text
P   = 100 if deleted else rank-derived priority
key = round_even((100 - P) * 10000)
```

Each type list is sorted by descending key: highest-importance, numerically
lowest-priority elements first.

The common sorter (`0xE235B0` -> heap routine `0xB030D0`) is an in-place,
one-based min-heap followed by extraction to produce descending keys. Exact
ties require these rules:

```text
build heap for i = floor(N/2) down to 1
extract end = N down to 2

during down-heap:
    missing-child key = INT_MAX
    choose right child only if right_key < left_key
    otherwise choose left child
    swap only if chosen_child_key < parent_key
```

All comparisons are strict. Equal children select the left child, and equal
parent/child keys do not swap. Do not replace this with a stable library sort
if byte-identical order matters.

If the combined queue has fewer than two elements, the daily routine returns
without sorting or saving new type/combined orders.

### 9.3 Randomization curve

Routine: `0xB27280`. Convert each item/topic randomization slider `s` to its
own curve:

```text
if s == 0:   curve = 0.001
elif s == 100: curve = 1000
else:
    x = sqrt(s / 100)
    if x > 0.5:
        curve = (x - 0.5) * 38 + 1
    else:
        curve = x + 0.5
```

After priority sorting, stochastically extract each type independently. Let
`Q` be the shrinking sorted list and `N` its original fixed count:

```text
for i = 1 .. N:
    x    = (i - 1) / N
    gate = pow(x, 1 / curve)
    u    = Random()                    # always consumed

    if gate > u:
        depth = pow(Random(), 1 / curve)
        index = trunc(Random() * depth * len(Q)) + 1
    else:
        index = 1

    output.append(Q[index])
    remove Q[index]
```

Thus every element consumes one draw, and each taken random-depth branch
consumes two additional draws. Item extraction is completed before topic
extraction. The priority-sorted type lists are saved to `OutstandingItems` and
`OutstandingTopics`; the stochastic outputs are then merged and saved as the
combined Outstanding queue.

### 9.4 Item/topic merge ratio

The merge consumes no PRNG values. Let `topicFraction=topicPercent/100`, with
`ni=0` and `nt=0`:

```text
repeat for the total number of item plus topic slots:
    chooseItem = (1 - topicFraction) > ni / (ni + nt + 1)

    if chooseItem:
        ni += 1
        if item output is exhausted:
            chooseItem = false
            nt += 1                    # do not undo ni
    else:
        nt += 1
        if topic output is exhausted:
            chooseItem = true
            ni += 1                    # do not undo nt

    append the next element from the chosen output
```

The comparison is strictly `>`. The counters record attempted choices as well
as fallback choices, which matters after one type runs out.

### 9.5 Learning stages and mandatory steps

`AnythingOutstanding` (`0xD8A250`) is true when any of these exists:

- combined Outstanding elements;
- Final Drill elements;
- Pending elements;
- neural queue work.

In normal mode, `GetFirstToRepeat` (`0xF3F000`) pops the first nonzero combined
Outstanding ID. Final Drill (`0xF33150`) is considered only after that queue is
exhausted, and Pending (`0xF32F00`) only after Final Drill. They are separate
fallback phases, not elements injected into the daily card/topic merge.

When the common stage-confirmation flag is active and the collection has more
than 100 elements, entering Final Drill or Pending prompts the user; otherwise
the transition is implicitly accepted. Optional Final Drill randomization uses
the fixed-size swap routine in section 9.6.

#### Manual stage and queue commands

The fallback ordering above is the default route, not the only one. The Learn
menu enters both fallback stages directly and can reorder or empty the stored
queues, so a clone that implements only the automatic chain has no way to reach
a drill while Outstanding still holds work. The executable's embedded menu
resources identify them:

`Learn -> Stages` (`MILearnStages`, hint `Choose a learning stage to execute`)
lists all three stages explicitly and numbered, and greys out the ones whose
queue is empty:

| Menu item | Caption | Embedded hint | Shortcut |
|---|---|---|---|
| `MILearnOutstanding` | `1. &Outstanding material` | Repeat items that are scheduled for today's repetitions | — |
| `MILearnNew` | `2. &New material` | Learn new material (i.e. commit it to your memory) | — |
| `MILearnDrill` | `3. Final &drill` | Go through the final revision of the material repeated recently (final drill stage) | Ctrl+F4 |

Stage 1 is the way back. Without it a user who entered a fallback stage would
be held there until its queue emptied, so a clone that offers only the two
fallback entries is not merely incomplete, it is a trap.

The `Drill` and `Random` submenus carry the remaining commands:

| Menu item | Caption | Embedded hint |
|---|---|---|
| `MIFinalDrill2` | `Final &drill` | Go through the final revision of the material repeated recently (with a keyboard shortcut) |
| `MICutDrills` | `&Cut drills` | Eliminate items scheduled for final drill |
| `MIRandomLearning` | `Ran&dom learning` | Learn new elements by randomly reviewing pending elements in the collection |
| `MIRandomizeRepetitions` | `Randomi&ze repetitions` | Randomize the sequence of outstanding items |
| `MIRandomizeDrill` | `&Drill` | Mix randomly the queue of elements scheduled for final drill |
| `MIRandomizePending` | `&Pending` | Mix randomly the queue of pending elements |

`MIFinalDrill2` duplicates stage 3 under the Drill submenu; both carry Ctrl+F4.

`Random learning` is **not** stage 2. `MILearnNew` presents the pending queue
in its stored order, while `MIRandomLearning` reviews the same elements in
randomized order, so the second is the first preceded by a randomization of the
pending queue. Treating them as one command loses the stored order that stage 2
is specifically for.

Entering a stage writes only the learning mode: nothing is created, scheduled,
or graded. An empty target stage is refused rather than entered — the
executable greys the item out, and answers `Nothing more to learn` when no
stage has work.

`Cut drills` clears Final Drill membership only. Due date, interval, A,
priority, and both repetition counters are untouched, because drill membership
never contributed to any of them; the command is confirmed with
`Delete Final Drill?`.

The three randomizations all use the section 9.6 fixed-size swap on one stored
queue and therefore consume one PRNG draw per element from the single shared
stream. A manual reshuffle consequently shifts every later stochastic decision,
which is the executable's behavior rather than a defect.

No Anki-like mandatory learning/relearning step array or step-injection rule
was found in the topic daily merge. Pending is not admitted according to a
time-capacity budget. It becomes a separate stage after Outstanding and Final
Drill. The subset scheduler (`0xD80240`, `0xD899C0`) has its own item and topic
queues and consumes items first, then topics; it does not use the normal merge
ratio.

### 9.6 Fixed-size queue randomization

Routine: `0xE23490`.

Used by randomized Final Drill and Mercy mode 3:

```text
for i = 1 .. N:
    j = Random(N) + 1
    swap(queue[i], queue[j])
```

It consumes exactly `N` PRNG values and is not Fisher-Yates: every `j` is
drawn from the full fixed range `1..N`.

### 9.7 Browser Learning commands and exact state transitions

The executable's embedded Delphi form maps the visible commands to the subset
dispatcher without relying on translated captions:

| Visible command | Operation/mode | Main routine |
|---|---:|---:|
| Learn | review mode 4 | `0xC7ABF0`, `0xF32680` |
| Review all | review mode 5 | `0xC7ABF0`, `0xF32680` |
| Review topics | review mode 6 | `0xC7ABF0`, `0xF32680` |
| Remember | `0x08` | `0xD62E20`, `0xD8EDD0` |
| Forget | `0x03` | `0xD540A0`, `0xD7C050` |
| Dismiss | `0x01` | `0xD7C560` |
| Undismiss | `0x07` | `0xD559D0`, `0xD52E10` |
| Done | `0x02` | `0xD71D10` |
| Add to drill | `0x21` | queue append at `0xE239B0` |
| Add to outstanding / Add all | `0x22` | `0xD663D0` |
| Reset history | `0x09` | `0xD86F50` |

Modes 4, 5, and 6 first construct a review source and set the global learning
mode; they do not mutate A merely by opening the review. A topic committed in
mode 4 uses the ordinary interval branch. Modes 5 and 6 use the forced-topic
interval branch in section 5.6. Mode 5 includes all eligible element types;
mode 6 is the topic-only review source.

The state-changing commands behave as follows:

- **Remember** effectively accepts status 0 and dismissed status 2, rejects an
  already memorized status-1 record, selects the first interval by section 5.5,
  and executes the normal memorization/repetition commit. For topics, all A and
  priority consequences therefore come from `(old_interval, chosen_interval)`.
- **Forget**, for status 1, removes the due repetition, changes status to 0,
  clears repetition and lapse counts, interval, Real48 ratio, history block,
  and both postponement counters, sets `last_review=Today`, writes control byte
  `+0x6D=8`, removes Final Drill membership, and restores the record to the
  intact/pending store. Topic A and priority are unchanged; type-1 item
  difficulty at `+0x1C` is reset to Real48 `3.0`. On an already status-0
  record, Forget only removes it from the intact/pending store. Status 2 is a
  no-op.
- **Dismiss** accepts status 0 or 1, removes due/learning and drill membership,
  changes status to 2, clears repetition/lapse counts, interval, ratio,
  history block, and both postponement counters, and sets
  `last_review=Today`. It preserves topic A but calls Set Priority with exactly
  `100.0`.
- **Undismiss** accepts only status 2, changes only the status byte to 0, and
  reinserts the element in the intact/pending store. It does not restore the
  former schedule or priority: the cleared fields and priority 100 left by
  Dismiss remain.
- **Done** invokes the collection/tree deletion transaction. Its
  scheduler-visible result is removal of the element from scheduling stores,
  queues, and the rankable population; descendant/tree placement belongs to
  the content model rather than an interval formula.
- **Add to drill** appends every selected nondeleted ID to Final Drill iff it
  is absent. It changes no record field, A, priority, or due date.
- **Reset history** acts only when the history-block ID at `+0x28` is nonzero:
  it deletes that external history block and writes `+0x28=0`. Despite the
  caption, it does **not** reset repetition count, lapse count, A, priority,
  interval, last-review day, ratio, or due date.

#### Batch Add to outstanding

Before processing, SM20 asks **Every which element?**, default 5 and bounds
`1..100`. Let the accepted value be `s`; the first insertion target is
`min(3,s)`. For each selected element in source order:

```text
if status != 1: continue

pos = current Outstanding position, or 0 if absent
if pos != 0 and pos < target_position: continue

if last_review == Today:
    if command == AddToOutstanding: continue
    RescheduleElement(Today)                 # Add all only

remove/reinsert in Outstanding at target_position
SetPriority(element, current_priority * 0.9)
target_position += s                         # only after success
```

Thus the ordinary command does not reschedule accepted future elements, as its
embedded hint says, but it is still not queue-only: every successful insertion
or move raises importance by multiplying the numerical priority target by
`0.9`. With **Add all**, the same-day reschedule follows section 8.1: it stores
interval 1, ratio 1, moves `last_review` to `Today-1`, and schedules due Today,
without changing A; the separate `0.9` priority change then runs.

## 10. Smart Postpone

The browser **Dilute** command is not a second hidden interval formula. It
opens this same Smart Postpone subsystem over the selected branch/subset with
`include non-outstanding` set true; the neighboring **Postpone** path supplies
false. Its delay, filtering, profile merge, record writes, and PRNG behavior
are therefore exactly the rules below.

### 10.1 Dialog-to-engine mapping

The three pages in **Postpone outstanding elements** are a front end to the
same `0x47`-byte record and evaluator described below. The UI-to-record routine
is `0xB80330`, the record-to-UI routine is `0xB7B850`, and the real/simulation
dispatcher is `0xB7E120`.

The **Scope** page maps as follows:

| UI choice | Stored/control value | Effect |
|---|---:|---|
| All outstanding repetitions | scope `0` | source is the global Outstanding population |
| Selected branch or concept | scope `1` | source is restricted by root ID `+0x00` |
| Current browser | scope `2` | source is the current browser population |
| Skip the following number of top priority elements | method flag `+0x05 = 1` | protect `+0x10` elements; normal filters are followed by the forced second pass if necessary |
| Skip elements as defined by Parameters | method flag `+0x05 = 0` | use only the Parameters eligibility gates; no protected-count target or forced pass |

If scope `2` is selected while no current browser exists, the dialog changes
the scope back to `0`; it does not run against an implicit empty browser.

`Name`, `Branch scope`, Save, Default, Delete, and List manage named/global or
branch-specific profiles. They do not add another scoring formula. The values
visible in a profile such as **Default** are collection/configuration state and
must be exported; they are not universal constants that a clone may assume.

On the **Parameters** page, the displayed delay factor is a presentation of a
stored integer percentage:

```text
displayed_delay_factor = 1 + stored_delay_percent / 100
```

Thus the screenshot's topic factor `1.5` is stored as `50`. The controls
captioned **Maximum interval** and **Minimum interval** do *not* clamp the
element's final interval. Machine code uses them to clamp the number of days
being added by this postponement after priority scaling and before random
dispersion. Dispersion is not clamped back to the configured minimum or
maximum afterward; only the absolute floor of one day is applied again.

The skip-control boundary behavior is exact:

| UI control | Candidate is rejected when |
|---|---|
| Skip items / Skip topics | the corresponding type-wide box is checked |
| Interval beyond `X` | `age >= X` |
| Forgetting index below `X` | item `FI < X` |
| A-Factor below `X` | topic `A <= X` |
| Postpone count `X` | `total_postponements >= X` |
| Priority (%) `X` | rank-derived `P < X` |

The **Adjust** page contains one functional policy group, one functional source
option, and three misleading modifier checkboxes:

| UI control | Executable behavior |
|---|---|
| Respect / Ignore / most conservative / most liberal sub-branch settings | stored at `+0x0F`; profile handling is section 10.5 |
| Include elements that are not outstanding | stored at `+0x12`; bypasses only the Outstanding-membership exclusion |
| Modify item delay in proportion to forgetting index | stored at `+0x45`, displayed again, but never read by evaluator `0xB81280` |
| Modify topic delay in proportion to A-Factor | stored at `+0x46`, displayed again, but never read by evaluator `0xB81280` |
| Modify delay in proportion to element priority | no record field, no event handler, omitted by both marshalling routines, and never read |

Consequently, toggling any of those three modifier checkboxes has no effect on
postponement in this executable. A normal pass nevertheless always applies the
square-root priority scaling at `0xB815CF..0xB8161D`, and a forced pass uses
priority linearly in `0xB81140`; neither behavior is controlled by the third
box.

**Simulate** sets `+0x13`, invokes the same source/filter/delay calculation,
and reports its results, but section 10.3's random dispersion and all record
writes are skipped. Simulation therefore consumes no PRNG values.

### 10.2 Profile record

The identified settings record is `0x47` bytes:

| Offset | Meaning |
|---:|---|
| `+0x00` | root element ID (`UInt32`) |
| `+0x04` | scope |
| `+0x05` | top-priority/protected-count method flag |
| `+0x06` | internal forced-second-pass flag |
| `+0x07` | managed profile-name pointer |
| `+0x0F` | sub-branch mode: 0 Respect, 1 Ignore, 2 conservative, 3 liberal |
| `+0x10` | protected/top count (`UInt16`, UI range 1..20000) |
| `+0x12` | include non-outstanding |
| `+0x13` | simulation |
| `+0x14` | item delay percent |
| `+0x16` | topic delay percent |
| `+0x18` | item maximum delay |
| `+0x1A` | topic maximum delay |
| `+0x1C` | item minimum delay |
| `+0x1E` | topic minimum delay |
| `+0x20` | skip items |
| `+0x21` | skip topics |
| `+0x22` | item age/interval cutoff (`UInt32`) |
| `+0x26` | topic age/interval cutoff (`UInt32`) |
| `+0x2A` | item forgetting-index cutoff (`UInt8`) |
| `+0x2B` | topic A cutoff (`Double`) |
| `+0x33` | item total-postponement cutoff (`UInt8`) |
| `+0x34` | topic total-postponement cutoff (`UInt8`) |
| `+0x35` | item priority threshold (`Double`) |
| `+0x3D` | topic priority threshold (`Double`) |
| `+0x45` | UI “modify item by FI” checkbox |
| `+0x46` | UI “modify topic by AF” checkbox |

The record has no field for the third UI checkbox, “modify delay in proportion
to element priority.” The two final stored flags are profile data only;
evaluator `0xB81280` does not read them. A clone must preserve these behaviors
rather than implement what the captions appear to promise.

### 10.3 Candidate eligibility and delay

Evaluator: `0xB81280`. For each candidate:

```text
P       = rank-derived priority percentage
elapsed = Today - last_review
age     = max(elapsed, stored_interval, 1)
```

Normal item eligibility, for type 1:

```text
not SkipItems
age < item_age_cutoff
FI >= item_FI_cutoff
total_postponements < item_postpone_cutoff
P >= item_priority_threshold
```

Normal topic eligibility, for types 0, 2, and 4:

```text
not SkipTopics
age < topic_age_cutoff
A > topic_A_cutoff                    # strict
total_postponements < topic_postpone_cutoff
P >= topic_priority_threshold
```

Other nondeleted types fall through to a generic factor of `1.01` without
those type filters/clamps. Type 3 is normally deleted and filtered earlier.

For an eligible ordinary candidate, select item/topic settings by type and
calculate:

```text
baseFactor = 1 + delay_percent / 100
rawDelay   = round_even(age * baseFactor) - age
delay      = round_even(2 * rawDelay * sqrt(P / 100))
delay      = max(delay, 1)
delay      = clamp(delay, configured_min_delay, configured_max_delay)

if delay > 200:
    emit warning only; do not clamp to 200

if not simulation:
    delay = round_even(spread(delay, 0.5 * delay))
delay = max(delay, 1)
factor = (age + delay) / age
```

In a real, non-simulation run, every ordinarily eligible candidate consumes
two PRNG values and is passed to Delay Element. In simulation, there is no
record write, no dispersion call, and no PRNG consumption.

### 10.4 Source ordering, protection, and exclusion order

Outer routine: `0xB81980`; apply/statistics routine: `0xB81850`.

For the top-priority/protected-count method, SM20 first priority-sorts the
source so numerically high-priority, low-importance elements are processed
first. It uses rank positions as keys and the same descending heap/tie behavior
as section 9.2.

The pass order is exact:

```text
for each source entry:
    if top method and sourceCount - postponedCount <= protectedCount:
        stop

    read element ID
    run progress callbacks
    if deleted: continue
    if not includeNonOutstanding and not IsOutstanding: continue
    if already in postponed output: continue
    evaluate and, if eligible, apply postponement
```

The stop expression uses original `sourceCount`, not a count prefiltered for
deleted or ineligible elements. Such elements can consequently count among the
protected remainder.

If normal filters leave more than `protectedCount` unpostponed, SM20 sets the
internal forced flag and runs a second pass. The outer deletion,
Outstanding-membership, and already-postponed exclusions remain. Parameter
eligibility filters are bypassed, and delay becomes deterministic:

```text
delay = min_delay
        + round_even((max_delay - min_delay) * P / 100)
factor = (age + delay) / age
```

Type 1 uses item min/max; all other candidates use topic min/max. The forced
pass performs no random spread and consumes no PRNG values.

The parameter method has no protected-count target and no forced second pass.

### 10.5 Branch-profile merging

Routine `0xB7EDB0` applies nested profiles unless the sub-branch mode is
Ignore. Respect can copy the exactly applicable profile through `0xB7F580`.
The aggregate merge routine is `0xB7FE80`.

For **conservative** mode:

```text
MIN: delay percentages, min/max delay fields, age cutoffs,
     postponement-count cutoffs, priority thresholds
MAX: FI cutoff, A cutoff
OR:  SkipItems, SkipTopics
```

For **liberal** mode:

```text
MAX: delay percentages, min/max delay fields, age cutoffs,
     postponement-count cutoffs, priority thresholds
MIN: FI cutoff, A cutoff
AND: SkipItems, SkipTopics
```

The priority-threshold MIN/MAX directions above are exactly what the
disassembly implements, even though their semantic effect can appear
counterintuitive with eligibility `P >= threshold`.

### 10.6 Effects and persisted results

For a memorized candidate, Smart Postpone calls Delay Element and the general
rescheduler. It therefore persists:

- a later absolute due date;
- a new stored interval;
- a multiplied/accumulated Real48 interval ratio;
- recent and total postponement counters when the interval grows;
- membership in postponed/unpostponed result lists and aggregate statistics.

It does not change A, rank priority, repetition count, lapse count, or
last-review day. The include-non-outstanding pending-element edge case follows
the nonmemorized rescheduler behavior in section 8.1 and can memorize an
element.

There is no workload-time or study-capacity read in Smart Postpone. The
“protected” value is an element count, not minutes, repetitions/day, or a
capacity ledger.

## 11. Automatic overflow/postponement

Routine: `0xD60450`.

The executable's automatic path is count- and profile-driven:

```text
if auto_postpone_disabled: exit
if last_auto_run_day == Today: exit

unless caller forces the run:
    if collection_nonempty and (Now - last_collection_use) > 10.0 days:
        optionally notify
        disable auto postpone
        exit

last_auto_run_day = Today             # written before the count gates

if combined_Outstanding_count <= 10: exit

overdue = scheduled elements from collection_learning_start
          through Today - 1
if overdue_count <= 10: exit

load profile named "Default" from postpone.ini
set includeNonOutstanding = false
clear managed profile/branch name
run Smart Postpone on overdue
```

Both count comparisons are strict: processing requires more than ten current
Outstanding elements and more than ten overdue elements. Today's due elements
are not part of the backlog list. There is no automatic capacity forecast,
time budget, “overflow” ledger, or new-card admission calculation in this
path. The Default Smart Postpone profile determines what is actually moved.

The “maximum outstanding” values updated by `0xD74BA0`/`0xD82F50` are peak
statistics and reset when Outstanding plus Final Drill reaches zero. The
overload statistics around `0xCAE260` likewise record ratios; they are not
capacity controls.

## 12. Mercy

The browser Learning-menu command captioned **Spread** dispatches operation
`0x25` directly to subset Mercy preparation `0xD3D7E0`. It is this section's
subset-Mercy rescheduling path, not priority Spread and not a separate
scheduler.

### 12.1 Collection-dependent investment estimate

Data preparation: `0xD8CB70`; age helper `0xCF7470`; matrix estimate
`0xCF44C0`.

Mercy does not use A for this estimate. It calls the matrix routine with fixed
forgetting index `3.0`. The FI bin is:

```text
bin = trunc((clamp(3.0 + 0.000001, 1.2, 10) - 1.2) / 0.3) + 1
    = 7
```

Let `M` be the live 20 by 20 unsigned-16-bit O-Factor matrix, with values
scaled by 1000. It is internal, collection-owned optimizer state, not a user
preference. The executable contains no path that treats its 400 cells as Mercy
settings or as a manually editable custom matrix.

SM20 persists the matrix inside the fixed-size `info/sm8opt.dat` optimization
record. The binary expects `0x49BC` (18,876) bytes. The relevant beginning of
that record is:

| File range | Size | Meaning |
|---|---:|---|
| `0x000..0x31F` | 800 bytes | live O-Factor matrix `M` |
| `0x320..0x63F` | 800 bytes | empirical/learned O-Factor matrix |
| `0x640..0x95F` | 800 bytes | unsigned-16-bit observation counts |

The verified lifecycle is:

1. New-record routine `0xCFA330` visits all 400 cells, obtains the starting
   factor from `0xCF29D0`, writes it to both matrices, and zeroes the matching
   observation count.
2. Collection-open routine `0xD6FB10` reads `\info\sm8opt.dat`; `0xCF26F0`
   attaches the persisted record and allocates a same-sized working record.
3. For an eligible item repetition, `0xCFA570` updates the working record.
   `0xCFC9E0` increments the cell count at `+0x640` and updates its empirical
   factor at `+0x320`. `0xCF43E0` then recomputes the live matrix at `+0x000`
   from the accumulated evidence and fitted curves. Section 13 gives the
   formulas.
4. Only the commit path `0xCF9A80`/`0xCF2560` copies the working record into
   the persisted record. `0xD54110` writes that record back to
   `\info\sm8opt.dat`. The working-copy boundary prevents an abandoned or
   failed repetition from changing the live optimizer state.

A newly created collection's matrix is deterministic. Two collections created
independently by this executable contain a byte-identical initial record. In
both, the live and empirical matrices are equal and all 400 observation counts
are zero. This makes the starting table a property of the program; only its
learned successor is collection-dependent. Outside column zero every initial
cell is:

```text
M[row][column] = round_even(1000 * (1.2 + 0.3 * row / column))
```

evaluated in float64 and not on the exact rational. Three cells that are ties
over the rationals arrive just below one — `1537.4999999999998` at `[9][8]`
and `[18][16]`, `1612.4999999999998` at `[11][8]` — and therefore round down,
while the twelve genuine ties settle on the even value. Column zero follows no
such rule and is the series:

```text
2484 2347 2217 2094 1978 1868 1765 1667 1575 1487
1405 1327 1254 1184 1119 1057  998  943  890  841
```

A clone that starts a fresh collection must generate this matrix internally.
It must not expose the table as a settings field or ask the user to paste 400
numbers. The initial matrix is only a starting estimate: SM20 refits all 400
cells after every eligible item repetition. Section 13 specifies that optimizer
in full.

This record belongs to the **SM-15 component of Algorithm SM-20**, not to a
separate legacy scheduler. SM20 runs one algorithm that evaluates several
models per repetition and combines them; its own repetition export names the
columns `OI2, OI15, OI19, OI20, OI_FSRS, Weighted Interval, Weighted FI
Interval` alongside `RM2, RM15, RM19, RM20, RM_FSRS` and
`Met2_19, Met15_19, MetFSRS_19, Met20_19`. `sm8opt.dat` is the SM-15 member's
state; `alg17/` holds the DSR members' state.

Whether a clone must implement the optimizer therefore depends on whether it
runs that component at all. Every SM20 item repetition feeds it; topic and
extract repetitions never touch it. A clone that schedules its items with its
own algorithm never produces an SM-15 observation, so its matrix correctly
stays at the initial values forever — the same state SM20 itself holds in a
topics-only collection. See §13.8.

A clone migrating an existing collection should import the complete
optimization record (or an equivalently decoded representation), not only the
first 800 bytes. Importing only `M` reproduces Mercy's estimate at that instant
but discards the empirical matrix, observation counts, and fitted state needed
for subsequent updates. Section 13.1 maps all `0x49BC` bytes.

```text
E   = M[0][0] / 1000
rep = min(repetition_count, 20)

for k = 2 .. rep:
    E = E * (M[6][k - 1] / 1000)     # zero-based row/column

age             = max(Today - last_review, 1)
investment_base = min(E, age)
```

This matrix product, not `3^rep`, is the exact executable behavior.

### 12.2 Mercy score

Routine: `0xCF6D00`.

Let `L` be lapses, `P` rank-derived priority, and `R` the rescheduling-period
value supplied to scoring:

```text
rep       = min(repetition_count, 20)
age       = max(Today - last_review, 1)
lapseOrd  = L / (L + 1)
ageOrd    = age / (age + 200)

Recency   = 0.65 * (1 - ageOrd) + 0.35 * (1 - lapseOrd)
Investment = 0.5 * (investment_base / (investment_base + 400))
             + 0.5 * (rep / (rep + 3))
Importance = 1 - P / 100

candidateAge = max(Today + (R - 1) - last_review, 1)
if investment_base == 0:
    ratio = 0
else:
    ratio = candidateAge / investment_base
ratioOrd = ratio / (ratio + 1.4)

Lateness = 0.6 * ratioOrd + 0.4 * ageOrd
Easiness = 0.7 * (1 - lapseOrd) + 0.3 * (1 - Lateness)

weighted = (
    wRecency   * Recency
  + wInvestment* Investment
  + wEasiness  * Easiness
  + wImportance* Importance
  + wLateness  * Lateness
) / (wRecency + wInvestment + wEasiness + wImportance + wLateness)

score = round_even(clamp(weighted, 0, 1) * 1,000,000)
```

The stored weight-record order is
`[Importance, Lateness, Investment, Easiness, Recency]`. Default initialization
at `0xB26070` supplies `10, 3, 4, 1, 1` in that order.

### 12.3 Candidate ordering

Mercy has four ordering modes:

```text
mode 0: key = score;             generic descending heap sort
mode 1: key = 1,000,000-score;   generic descending heap sort
mode 2: retain candidate order
mode 3: fixed-size queue randomization from section 9.6
```

Mode 0 places higher scores first; mode 1 places lower scores first. Equal
keys follow the exact heap ties in section 9.2. Mode 3 consumes exactly one
global PRNG value per candidate. A deleted candidate becomes an element-zero,
key-zero placeholder; final rescheduling skips ID zero.

### 12.4 Candidate gathering and final due-date assignment

Gather routines: `0xD87380`, `0xD3E8D0`.

For collection-wide Mercy, candidates are current scheduled repetitions from
the collection learning-start day through `Today + G - 1`, inclusive, where
`G` is the gathering horizon. A subset run uses its supplied subset queue.

Mercy is **not item/card-only**. Collection gathering at `0xD876D0` separates
type `1` items from the non-item topic family, then `0xD877E4..0xD87817`
appends both lists to the combined Mercy candidate list: items first, followed
by topics. Ordinary topics and text/media extracts are therefore included when
they are scheduled in the gathering horizon. A subset Mercy run accepts the
element types present in its supplied subset. Deleted records are skipped;
pending, forgotten, or dismissed elements normally have no scheduled
repetition to gather.

Both families use the same Mercy score and assignment mechanism. Topic or
extract A is not an input to the Mercy score and is not changed by Mercy;
Mercy is a reschedule transaction, not a topic repetition.

Let `N` be the number selected for rescheduling, `R` the number of rescheduling
days, and:

```text
q = ceil(N / R)
```

Final assignment is:

```text
for d = 1 .. R:
    for s = 1 .. q:
        index = (d - 1) * q + (q - s + 1)
        if index <= candidate_count:
            RescheduleElement(candidate[index], Today + d - 1)
```

Indices are one-based. This reverses processing order within each equal-day
block. Mercy writes actual due dates and intervals through `0xD82AA0`; for
memorized elements it does not change A, priority, repetitions, lapses, or
last-review day. It can update postpone counters when an assigned interval is
longer.

### 12.5 Mercy capacity planner

The planner has no independent capacity ledger. It reads current
`ScheduledCount(day)`, so prior Smart Postpone, Later, manual rescheduling, or
an earlier Mercy run is already reflected in its input schedule.

Use:

```text
T = Today
L = collection learning-start day
C = elements per day
R = rescheduling days
G = gathering days
cnt(d) = max(ScheduledCount(d), 0)
```

When `R` or `G` is edited, the UI enforces the current future/nonfuture horizon
relationship, then recomputes:

```text
N = sum(cnt(d), d = L .. T + G - 1)   # or selected subset count
C = ceil(N / R) if N > 0 else 0
```

When `C` is edited in nonfuture mode, a subset uses
`R=ceil(N/C); G=R`. Otherwise the exact solver is:

```text
balance   = 0
allocated = 0
d         = min(L - 1, T - 1)

do:
    d += 1
    c = cnt(d)
    if d >= T:
        allocated += C
        balance = balance - C + c
    else:
        balance += c
while d < T or balance > 0

N = allocated + balance
R = d - T + 1
G = R
```

When `C` is edited in future mode:

```text
balance   = sum(cnt(d), d = L .. T + G - 1)
allocated = 0
d         = min(L - 1, T - 1)

do:
    d += 1
    c = cnt(d)
    if d > T + G - 1:
        balance += c
    if d >= T:
        allocated += C
        balance -= C
while balance > 0

N = allocated + balance
R = d - T + 1
G = max(G, R)
```

The UI caps `C` at 5,000 and `R`/`G` at 3,650. A horizon above 1,825 triggers
the executable's warning/switch/recompute path.

## 13. Adaptive O-Factor optimizer

Everything §12.1 reads out of `M` is the *output* of this subsystem. `M` is not
a constant table. SM20 refits all 400 cells after every eligible item
repetition, so a collection's matrix diverges from the initial one as soon as
items are learned. The routines below are the complete recovered mechanism.

```text
0xCFA570  repetition driver (calls the update, then the regeneration)
0xCFC9E0  per-repetition evidence update
0xCF3530  forgetting-curve fit for one (A-factor, repetition) cell
0xCF43E0  live-matrix regeneration entry
  0xCF4230  column-1 (first interval) refit      <- 0xCF5720
  0xCF30E0  per-A-factor decay-exponent refit    <- 0xCF2B60
  0xCF9740  cross-A-factor smoothing of the exponents
  0xCF3110  writes the live matrix
0xCFA330  initial record
0xCF26F0  attach persisted record + allocate working record
0xCF2620  persisted -> working (begin / rollback)
0xCF2560  working -> persisted (commit)         <- 0xCF9A80
0xD54110  persisted record -> \info\sm8opt.dat
```

Numeric helpers, named from their instruction bodies:

```text
0x40C5D0  Round   (cvtsd2si, SSE round-half-to-even)
0x40C6C0  Trunc   (cvttsd2si)
0x40C140  Ln
0x40B0E0, 0xF8CE50  Exp
0x4771D0  Power (float64)     0x477410  Power (float32)
```

### 13.1 Full optimization-record map

The record is one flat `0x49BC`-byte block. All indices below are 1-based, and
every address is a byte offset from the start of the record, and therefore from
the start of `info/sm8opt.dat`.

| Range | Size | Element address | Meaning |
|---|---:|---|---|
| `0x0000..0x031F` | 800 | `40*(a-1) + 2*(r-1)` | live O-Factor matrix `M[a][r]`, uint16 = factor x 1000 |
| `0x0320..0x063F` | 800 | `0x2F6 + 40*a + 2*r` | empirical matrix `RF[a][r]`, uint16 = factor x 1000 |
| `0x0640..0x095F` | 800 | `0x616 + 40*a + 2*r` | `Cases[a][r]`, uint16, saturating at 60,000 |
| `0x0960..0x0985` | 38 | `0x95C + 2*a`, `a` = 2..20 | `DecayExp[a]`, uint16 = magnitude x 10,000, clamped to `[0, 30000]` |
| `0x0986..0x09AB` | 38 | `0x982 + 2*a`, `a` = 2..20 | `ExpCases[a]`, uint16, clamped to 60,000 |
| `0x09AC..0x28EB` | 8000 | `0x807 + 400*a + 20*r + u` | `Recalled[a][r][u]`, uint8 |
| `0x28EC..0x482B` | 8000 | `0x2747 + 400*a + 20*r + u` | `Trials[a][r][u]`, uint8 |
| `0x482C..0x48A3` | 120 | `0x4826 + 6*a` | expected-grade curve vs A-factor, 20 x Real48 |
| `0x48A4..0x48CB` | 40 | `0x48A2 + 2*a` | its 20 uint16 case counts |
| `0x48CC..0x497F` | 180 | `0x48C6 + 6*i` | grade-vs-forgetting-index curve, 30 x Real48 slots, 18 seeded |
| `0x4980..0x49BB` | 60 | `0x497E + 2*i` | its 30 uint16 case counts, 18 seeded |

`Recalled`/`Trials` are the raw forgetting-curve evidence: for each
(A-factor category, repetition category, U-factor bin) they hold how many
reviews were recalled and how many were attempted. When a `Trials` cell passes
250, both it and the matching `Recalled` cell are halved (`shr 1`), so old
evidence decays instead of overflowing the byte.

### 13.2 Category axes

```text
AF(a) = 0.3*(a - 1) + 1.2            # 0xCF64C0, a = 1..20 -> 1.2 .. 6.9
```

The executable labels these axes itself. Its `ForgettingCurve15.csv` export
headers read `AF range,` and `Repetition range,` for the matrix, and
`Interval, Recall, Pass grades, Repetitions` for the evidence arrays, next to
the caption `Global forgetting curve collected with Algorithm SM-15`.

**A-factor category `a`.** For any repetition after the first, `a` is the
element's A quantized by `0xCF66B0`. For the *first* repetition, where
`0xCFC9E0` sees repetition number 1, the row index is instead `lapses + 1`;
`0xCFA570` has already clamped lapses to 19 and repetition number to 20. Row 1
therefore means "A = 1.2" on later repetitions and "no lapses yet" on the first
one, which is why column 1 of the initial matrix decreases with the row index.

**Repetition category `r`** (`0xCF54A0`), computed from the live matrix by
walking the interval forward until it passes the interval actually used:

```text
I = M[a][1] / 1000 ; prev = I ; n = 2
while usedInterval > I and n < 20:
    prev = I
    I    = I * M[a][n] / 1000
    n   += 1
if n > 2:  r = (n - 2) + (usedInterval - prev) / (I - prev)
else:      r = 1
r = clamp(r, 2, 20)                  # and r = 1 when repetition number is 1
```

**U-factor category `u`.** The U-factor is the executed interval expressed as a
multiple of the previous one, already corrected by `0xCFA570` for early or late
review (`U := U * usedInterval / scheduledInterval`). Its value scale is

```text
ufValue(a, r, k) = k                              if r == 1     # 0xCF51B0
                 = 1 + k * trunc(AF(a)) / 20      if r > 1
```

`trunc(AF(a))` over `a` = 1..20 is `1 1 1 2 2 2 3 3 3 3 4 4 4 5 5 5 6 6 6 6`.
Binning (`0xCF3320`), with `lo = ufValue(a,r,1)` and `hi = ufValue(a,r,20)`:

```text
u = Round((clamp(uf, lo, hi) - lo) / (hi - lo) * 19) + 1        # clamped to 20
```

For `r = 1` the axis is literally "interval in days, 1..20"; for `r > 1` it is
"interval ratio, from `1 + trunc(AF)/20` to `1 + trunc(AF)`".

### 13.3 Initial record

`0xCFA330` fills both matrices from `0xCF29D0` and zeroes every observation
count, then seeds `DecayExp[a] = 10000` and `ExpCases[a] = 1` for `a` = 2..20,
the expected-grade curve from `0xCF95F0`, and the grade-vs-FI curve from a
static table. `0xCF29D0` is exactly:

```text
M[a][1] = Exp(-0.057*(a - 1) + 0.91)                 # first interval, days
M[a][2] = AF(a)
M[a][r] = (r - 1)^(-1.0) * (AF(a) - 1.2) + 1.2       # r >= 3
stored  = Round(value * 1000)
```

Evaluating that in float64 and rounding half-to-even reproduces both shipped
`sm8opt.dat` files byte for byte, including the three near-ties §12.1 lists and
the column-zero series. `DecayExp = 10000` means "exponent -1.0", which is the
`(r-1)^-1` above: the initial matrix is the general parametric surface of §13.6
evaluated at its default parameters, not a separate hard-coded table.

`0xCF95F0(AF, -0.67, 2.4) = clamp(5.2 - Exp(-0.67*AF + 2.4), 0, 5)` gives the
initial expected-grade curve `0.2667, 1.165, 1.900, ..., 5.0`.

### 13.4 What one repetition changes: `0xCFC9E0`

Inputs are the repetition record: grade, A, used interval, U-factor, lapses,
repetition number, and the repetition category from `0xCF54A0`.

```text
a = (repetitionNumber == 1) ? lapses + 1 : AFactorCategory(A)
r = (repetitionNumber == 1) ? 1          : Round(repetitionCategory)
u = UFactorCategory(a, r, U)                                   # 0xCF3320
countAsRecalled = (grade >= 3)

# tail correction: a lapse whose U-factor already sits in the last bin is
# admitted probabilistically instead of being discarded
if u == 20 and not countAsRecalled:
    d  = decay(a, r)                                           # 0xCF3530
    pA = Exp(-d * ufValue(a, r, 20))
    pB = Exp(-d * U)
    if (pA - pB) > Random:  countAsRecalled = true             # 0x40A390

if countAsRecalled:  Recalled[a][r][u] += 1
Trials[a][r][u] += 1
if Trials[a][r][u] > 250:
    Trials[a][r][u]   >>= 1
    Recalled[a][r][u] >>= 1
if Cases[a][r] < 60000:  Cases[a][r] += 1

d     = decay(a, r)                                            # refit, 0xCF3530
newRF = (d == 0) ? ufValue(a, r, 20) : -Ln(0.9) / d

if r == 1:  newRF = clamp(newRF, 1, 20)                        # days
else:       newRF = clamp(newRF, 1.2, AF(a))                   # interval ratio
RF[a][r] = Round(newRF * 1000)
```

The `0.9` is hard-coded: the empirical matrix is anchored at a 10 % forgetting
index, and the user's requested forgetting index is applied later, outside the
record. Exactly one `RF` cell and one `Cases` cell move per repetition.

### 13.5 Forgetting-curve fit: `0xCF3530`

`decay(a, r)` is the exponential decay constant of the measured retention curve
for that cell.

```text
if Cases[a][r] == 0:
    return -Ln(0.9) / (RF[a][r] / 1000)          # invert the stored factor
for k = 1..20:
    x[k] = ufValue(a, r, k)
    n[k] = Trials[a][r][k]
    ret  = n[k] > 0 ? Recalled[a][r][k] / n[k] : 0
    y[k] = n[k] == 0 ? 0 : (ret > 0 ? max(Ln(ret), -3) : -3)
return -WeightedSlopeThrough(x, y, n, 20, C = 0)
```

The model is `R(u) = Exp(-decay * u)`, fitted through the origin with the trial
counts as weights, so `-Ln(0.9)/decay` in §13.4 is the U-factor at which that
curve predicts 90 % recall. The value when a cell has no evidence at all is
`0.07`.

### 13.6 Live-matrix regeneration: `0xCF43E0`

Called on every repetition, immediately after `0xCFC9E0`. It rebuilds all 400
cells from a five-parameter surface, which is why a single review visibly moves
cells far away from the one that was measured.

**Step 1, column 1** (`0xCF4230`, fit by `0xCF5720`):

```text
X[a] = a - 1
Y[a] = Ln(RF[a][1] / 1000)
W[a] = Cases[a][1] + 1
(s1, c1) = WeightedLine(X, Y, W, 20)                   # fallback (-0.18, 2.5)
M[a][1]  = Round(clamp(Exp(s1*(a-1) + c1), 1, 20) * 1000)      a = 1..20
```

**Step 2, one decay exponent per A-factor category** (`0xCF30E0` over
`0xCF2B60`, for `a` = 2..20):

```text
for r = 3..20:                              # r = 2 is the anchor, excluded
    Z[r] = Ln(r - 1)
    T[r] = RF[a][r]/1000 > 1.21 ? clamp(Ln(RF[a][r]/1000 - 1.2), -4, 4) : -10000
    N[r] = Cases[a][r]
if all N[r] == 0:  N[20] = 1
slope = WeightedSlopeThrough(Z, T, N, 18, C = Ln(AF(a) - 1.2))
DecayExp[a] = Round(clamp(-slope * 10000, 0, 30000))
ExpCases[a] = Round(min(sum of N, 60000))
```

The regression is forced through `(0, Ln(AF(a) - 1.2))`. That pins
`M[a][2] = AF(a)` and fits only the decay of the later columns.

**Step 3, smoothing across A-factor categories** (`0xCF9740`):

```text
X[a] = AF(a)
Y[a] = DecayExp[a] / 10000
W[a] = ExpCases[a]                                     a = 2..20
(s2, c2) = WeightedLine(X, Y, W, 20)                   # fallback (0.004, 0.98)
if s2 outside [-0.5, 0.5]:                             # pivot about AF = 3.6
    t  = s2*3.6 + c2
    s2 = clamp(s2, -0.5, 0.5)
    c2 = t - s2*3.6
```

**Step 4, write the matrix** (`0xCF3110`):

```text
M[1][r] = 1200                                         for r = 2..20
for a = 2..20:
    D = clamp(s2*AF(a) + c2, 0, 3)                     # 0xCF3F30
    for r = 2..20:
        M[a][r] = Round((1.2 + (AF(a) - 1.2) * (r - 1)^(-D)) * 1000)
```

Column 1 is not touched here; it is step 1's result. The live matrix is
therefore always the closed form

```text
M[a][1] = Exp(s1*(a-1) + c1)                     clamped to [1, 20] days
M[a][r] = 1.2 + (AF(a) - 1.2) * (r - 1)^(-D(a)) ,  D(a) = clamp(s2*AF(a)+c2, 0, 3)
```

and the collection-specific state that shapes it is `(s1, c1, s2, c2)`, derived
in turn from `RF`, `Cases`, `DecayExp`, and `ExpCases`.

**Weighted regression helpers.**

```text
WeightedLine(X, Y, W, n) -> (slope, intercept)          # 0xA875B0, 0xA87BE0
    w  = Round(W[k]) + 1e-5
    SW = sum w
    mX = sum(w*X)/SW   ; mY  = sum(w*Y)/SW
    mXX= sum(w*X*X)/SW ; mXY = sum(w*X*Y)/SW
    slope     = (mXY - mX*mY) / (mXX - mX*mX)
    intercept = mY - mX*slope

WeightedSlopeThrough(X, Y, W, n, C) -> slope            # 0xA87350, 0xA87FF0
    S1 = sum(W[k]*X[k]*X[k])
    S2 = sum(2*X[k]*W[k]*(C - Y[k]))
    return S1 == 0 ? 0 : -S2 / (2*S1)
```

Both are 1-based over `k` = 1..n.

### 13.7 Transaction boundary

Two record pointers exist: the persisted record and a same-sized working copy
allocated by `0xCF26F0`. Every mutation in §13.4 and §13.6 targets the working
copy.

```text
0xCFA570 entry : if dirty flag set -> 0xCF2620 (persisted -> working); set dirty
repetition     : 0xCFC9E0 then 0xCF43E0, both on the working copy
completion     : 0xCF9A80 -> 0xCF2560 copies working -> persisted, clears dirty
collection save: 0xD54110 writes the persisted record to \info\sm8opt.dat
```

An abandoned repetition never reaches `0xCF2560`, and the next repetition's
entry rollback discards its edits. A *failed* repetition is not abandoned: it
commits normally and, per §13.4, still contributes a `Trials` observation.

Because stored cells are uint16 scaled by 1000, a review can raise a `Cases`
count and shift the fitted parameters without changing any visible matrix cell.

### 13.8 Consequences for a clone

1. The matrix in §12.1 is derived state, not configuration. This section is
   the SM-15 component of Algorithm SM-20, so whether a clone needs it depends
   on whether the clone runs that component:
   - a clone that reproduces the SM-15 component — port §13, or `M` freezes
     and the Mercy investment estimate drifts from SM20's on any reviewed
     collection;
   - a clone that schedules its items by its own algorithm — nothing produces
     an SM-15 observation, so the frozen initial matrix is the correct and
     faithful state. This repository's items are cards scheduled by FSRS, so
     §13 is reference material here, not a porting target.
2. Topic and extract repetitions do not train the record: they use the §5
   scheduler and its own commit path (`0xD7CA60`), which never reaches
   `0xCFA570`. The shipped `second collection` is the direct evidence:
   `stats/topicreps.dat` = 3 and `info/RepetitionHistory.dat` is populated,
   yet its `sm8opt.dat` is byte-identical to the untouched
   `ABC of SuperMemo 20` record, with all 400 observation counts zero.
3. Porting the record means porting all `0x49BC` bytes. `M` alone cannot be
   updated: the next repetition needs `RF`, `Cases`, `Recalled`, `Trials`,
   `DecayExp`, and `ExpCases` to regenerate it.
4. The randomized tail admission in §13.4 consumes the global PRNG (§3.3). A
   port that wants sequence identity must draw from the same stream at the same
   point.
5. `RF[a][r]` and FSRS stability are the same physical quantity. §13.4 solves
   each cell for `-Ln(0.9)/decay`, the interval at 90 % recall; FSRS defines
   stability as the interval at 90 % recall (`fsrs4anki-helper` computes its
   forgetting curve from `factor = 0.9 ** (1 / decay) - 1`). SM20 estimates it
   from a population bucket because Algorithm SM-15 stores no per-element
   memory strength; FSRS measures it per card. A clone whose cards carry a
   measured stability should feed that to Mercy's investment estimate in place
   of the §12.1 matrix product, and keep the matrix product for topics, which
   have no such measurement. This repository does exactly that
   (`Sm20MercyCandidate.stability`, `Sm20MercyEngine.matrixExpectedInterval`)
   and it is the one deliberate departure from executable-identical Mercy
   scoring.

### 13.9 The SM-15 component's item repetition path

The optimizer above is fed by, and feeds back into, the SM-15 component's own
per-item state. This subsection records what has been recovered of that path.
It is documentation of `sm20.exe`, not a porting target for a clone whose items
use another algorithm; see §13.8.

`0xCFA570` runs the following chain for one item repetition, after the interval
correction and repetition-category step already described in §13.2:

```text
0xCF54A0  repetition category                    -> rep[+0x10F]
0xCF3F80  load current matrix values into rep
0xCFC9E0  update RF and the case arrays          (§13.4)
0xCF43E0  regenerate the live matrix             (§13.6)
0xCF3F80  reload the post-update values
0xCF8400  forgetting-index estimates             -> rep[+0xE7], [+0xEF],
                                                    [+0xFF], [+0x107]
0xCF3C90  update the grade-vs-FI curve
0xCF80D0  new A-factor                           -> rep[+0xBB]
0xCF8DB0  update the expected-grade-vs-A curve
0xCF5990  not decoded
0xCF8B90  not decoded                            -> rep[+0xC3]
```

#### Interpolated matrix read — `0xCF3A40`

The repetition category is fractional, so reads of the live matrix interpolate
between adjacent columns:

```text
OF(a, r):
    r  = min(r, 20)
    lo = Trunc(r)
    hi = lo < 20 ? lo + 1 : 20
    return (M[a][lo] + (r - lo) * (M[a][hi] - M[a][lo])) / 1000
```

#### Forgetting index and interval — `0xCF9C00`

This is the conversion the matrix is anchored to. `0xCF9C00` returns the
forgetting index, in percent, that the executed interval implies:

```text
if repetitionNumber == 1:  OF = M[lapses + 1][1] / 1000        # days
else:                      OF = OF(AFactorCategory(A), rep[+0x10F])
FI = (1 - Exp(Ln(0.9) * U / OF)) * 100
FI = clamp(FI, 0.1, 99.5)
```

The retention model is therefore

```text
R(u) = 0.9 ^ (u / OF)
```

with `u` the U-factor for a later repetition and the interval in days for the
first. `OF` is by construction the point where `R = 0.9`, which is what §13.4
solves each `RF` cell for.

Inverting it gives the scheduling direction, i.e. how a requested forgetting
index `f` (percent) becomes a date:

```text
R = 1 - f/100
I = I_previous * OF * Ln(R) / Ln(0.9)          # repetition 2 and later
I =              OF * Ln(R) / Ln(0.9)          # first repetition, OF in days
```

`Ln(R)/Ln(0.9)` is 1 at `f = 10`, about 0.487 at `f = 5`, and about 2.118 at
`f = 20`. So the stored matrix is a 10 %-forgetting-index table and the
requested index is a single multiplier applied on top of it. `0xCF52F0` uses
the same relation in the opposite direction, rescaling an executed interval to
its 10 % equivalent with `I * Ln(0.9) / Ln(1 - FI/100)`.

#### A-factor update — `0xCF80D0`

The new A is an exponential blend of the old value with a stage-dependent
estimate:

```text
newA = w * estimate + (1 - w) * oldA
```

| stage | `w` | estimate |
|---|---:|---|
| repetition number 0 | 0.6 | `(grade - 4) * 0.3 + 3.0` |
| repetition 1, no lapses | 0.85 | `0xCF7F60(rep[+0xF7])` |
| repetition 1, after a lapse | 0.4 | `(grade - 4) * 0.3 + 3.0` |
| repetition 2 and later | 0.4 | `0xCF52F0(rep)` |

If `rep[+0xF7]` or `rep[+0xE7]` is non-positive on a repetition that has
history, the routine reports an error and returns the old A unchanged.

**`0xCF7F60(g)`** inverts the expected-grade curve of §13.1. With
`(slope, intercept)` fitted over that 20-entry table by `0xCF9340`:

```text
A = slope == 0 ? 6.9 : (Ln(5.2 - g) - intercept) / slope
A = clamp(A, 1.2, 6.9)
```

That is the exact inverse of the `0xCF95F0` generator in §13.3,
`g = 5.2 - Exp(slope * A + intercept)`.

**`0xCF52F0(rep)`** estimates A from an ordinary repetition by asking which
A-factor category's matrix curve would have produced the interval just
executed:

```text
target = usedInterval * Ln(0.9) / Ln(1 - rep[+0xE7]/100)     # 10% equivalent
u      = (target / usedInterval) * U
k      = 20
while k > 0 and u <= OF(k, rep[+0x10F]):  k -= 1
if k == 0:  k = 1
return AFactor(k)
```

#### The two tail curves of §13.1

Both are exponentially-weighted running means of the grade, each with its own
saturating case counter.

**Grade versus forgetting index** — `0xCF3C90(x, grade)`, over the 30-slot
Real48 table at `0x48C6` and its counts at `0x497E`:

```text
i = clamp(Round(x), 1, 18)
Counts[i] = min(Counts[i] + 1, 60000)
w         = 1 / (10 * Ln(Counts[i] + 2))
Table[i]  = Table[i] * (1 - w) + grade * w
```

`0xCFA570` calls it with `x = rep[+0xEF]`, the forgetting index estimate from
`0xCF8400`.

**Expected grade versus A-factor** — `0xCF8DB0(rep)`, over the 20-slot Real48
table at `0x4826` and its counts at `0x48A2`:

```text
skip if repetitionNumber == 0
skip if repetitionNumber == 1 and lapses == 0
skip unless 0 <= grade <= 5
a         = AFactorCategory(rep[+0xBB])          # the A just written
Counts[a] = min(Counts[a] + 1, 60000)
w         = repetitionNumber == 2 ? 0.15 : 0.07
Table[a]  = Table[a] * (1 - w) + grade * w
if Table[a] < 0:  report and reset the slot to zero
```

The grade guard is direct evidence that SM-15 grades are integers 0 through 5;
§13.4's pass test is `grade >= 3`.

#### Grade normalization — `0xCF8400`, partial

`0xCF8400` sets `rep[+0xF7] = 4.0`, fits the grade-vs-FI table with
`0xCF8860`, then writes:

```text
rep[+0xE7] = 0xCF6B30(grade, slope, intercept)      # FI implied by the grade
rep[+0xEF] = 0xCF9C00(rep)                          # FI implied by the interval
```

It then evaluates `0xCF69A0` — the inverse map, forgetting index to grade — at
four points (`10`, `rep[+0xEF]`, `rep[+0xE7]/rep[+0xEF] * 10`, and
`rep[+0xE7] + 10 - rep[+0xEF]`) and reduces them into a low bound at
`rep[+0xFF]` and a high bound at `rep[+0x107]`. These bracket the grade
normalized to a 10 % forgetting index. The reduction is recovered; the four
estimators `0xCF6B30`, `0xCF69A0`, `0xCF8860`, `0xCF9340` are not disassembled,
and `rep[+0xF7]`'s later use is not traced.

#### Not recovered

`0xCF5990` and `0xCF8B90` in the chain above, the four estimator/fit routines
just named, and the item dispatcher's element-type codes. Beyond this
component, §19 lists what remains of Algorithm SM-20 as a whole.

## 14. Interaction and mutation matrix

This table is the shortest reliable guide to which subsystem a clone should
invoke. “Due state” means due date, stored interval, Real48 ratio, and possible
postpone counters through the low-level rescheduler.

| Operation | A | Priority rank | Reps/last review | Due state | Queue | PRNG |
|---|---:|---:|---:|---:|---:|---:|
| Automatic topic repetition | update | update | update | replace | remove/reinsert as learning requires | 2 |
| Explicit/forced repetition | update from chosen interval | update | update | replace | learning flow | 0 if explicit; 2 if generated |
| Allocate ordinary blank topic | initialize to raw Real48 `819a99999919` (`1.2`) | initialize rank | not yet committed | not yet scheduled | create element | 0 |
| Initial memorization at interval 1 | unchanged (`1.2` for ordinary blank topic) | unchanged | initialize | due Tomorrow | admission | 0 |
| Current-element Increase/Decrease Priority | unchanged | `-0.1` / `+0.1` target | unchanged | unchanged | unchanged | 0 |
| Browser batch Increase/Decrease | unchanged | sequential `P*change/100`, direction/bounds enforced | unchanged | unchanged | unchanged | 0 |
| Browser Priority Spread/Adjust | unchanged | sequential arithmetic/remapped targets | unchanged | unchanged | unchanged | 0 |
| Browser Set/Modify A | direct set / `1.01+m*(A-1.01)` | unchanged | unchanged | unchanged | unchanged | 0 |
| Text extraction | child blend; source reduced | source `*0.995`; child randomized target | child initialized | child due Tomorrow | child admitted | 1 |
| Media extraction | child `3.0`; source A unchanged | source `*0.995`; child randomized target | child initialized | child due Tomorrow | child admitted | 1 |
| Duplicate memorized element | raw A copied | same target/rank insertion | copied | rescheduled to Tomorrow | copied/updated status | 0 |
| Manual Reschedule UI | topic A update | topic priority update | unchanged | replace | as command requires | 0 |
| Advance Topic | bulk update against selected short interval | bulk interval drift | increment / Today | replace | learning flow | 1 per draw-eligible candidate |
| Advance Item | unchanged/not applicable | unchanged | unchanged | replace | unchanged | 1 per draw-eligible candidate |
| Later Today, already Outstanding | unchanged | unchanged | unchanged | unchanged | shift to a prompted position; in review modes 5-7 also drop from the review subset | 0 |
| Later Today, not Outstanding | topic A update against new `0` | unchanged | unchanged | due Today | insert/shift | 0 |
| Remember topic, explicit interval 1 | unchanged | unchanged | initialize | due Tomorrow | admit | 0 |
| Forget memorized topic | unchanged | unchanged | clear / Today | remove | restore intact/pending | 0 |
| Dismiss topic | unchanged | set target `100` | clear / Today | remove | remove learning/drill | 0 |
| Undismiss topic | unchanged | remains at prior value (normally `100`) | unchanged | unchanged | insert intact/pending | 0 |
| Add to Outstanding, accepted | unchanged | target `0.9*P` | unchanged | unchanged | insert/move | 0 |
| Add all, reviewed Today | unchanged | target `0.9*P` | `last_review=Today-1` | interval/ratio 1, due Today | insert/move | 0 |
| Add to Final Drill | unchanged | unchanged | unchanged | unchanged | append iff absent | 0 |
| Final drill / Random learning | unchanged | unchanged | unchanged | unchanged | select presented stage | 0 |
| Cut drills | unchanged | unchanged | unchanged | unchanged | clear Final Drill | 0 |
| Randomize repetitions / drill / pending | unchanged | unchanged | unchanged | unchanged | replace one queue order | queue count |
| Reset history | unchanged | unchanged | unchanged | unchanged | unchanged; history block only | 0 |
| Smart Postpone, normal memorized | unchanged | unchanged | unchanged | postpone | result lists | 2 per eligible element |
| Smart Postpone, forced pass | unchanged | unchanged | unchanged | postpone | result lists | 0 |
| Auto Postpone | unchanged | unchanged | unchanged | as Default profile | result lists | profile-dependent |
| Mercy modes 0/1/2 | unchanged | unchanged | unchanged | redistributed | source/result order | 0 |
| Mercy mode 3 | unchanged | unchanged | unchanged | redistributed | randomized | candidate count |
| Daily queue sort | unchanged | unchanged | unchanged | unchanged | replace orders | variable |
| Final Drill randomization | unchanged | unchanged | unchanged | unchanged | replace order | queue count |

Two qualifications apply:

1. UI priority commands may first commit an already-open repetition; that
   separate commit has its normal row's effects.
2. A low-level reschedule of a nonmemorized element enters memorization, so a
   Smart Postpone run explicitly including pending/non-outstanding elements can
   have initialization effects instead of the usual memorized row.

## 15. Adjustment clearing, protection, and admission rules

There is no identified per-element postponement-adjustment overlay to clear.
The relevant tools operate on two concrete stores:

- the due schedule/stored interval, which rescheduling operations remove and
  replace; and
- queue membership/order, which queue-only commands mutate without changing
  due state.

Therefore interactions compose as follows:

- a later manual reschedule or Mercy assignment replaces the due date produced
  by Smart/Auto Postpone;
- Mercy's planner sees all prior replacements through `ScheduledCount`;
- an ordinary repetition removes the current due repetition and writes a fresh
  one from the committed review;
- daily sort, Add to Final Drill, ordinary accepted Add to Outstanding, and
  the already-Outstanding branch of Later Today do not clear or overwrite a
  due-date change. Add to Outstanding still applies its separate `0.9`
  priority target, and Add all has the same-day reschedule exception;
- Smart Postpone's protected-count pass excludes in this order: stop target,
  deleted, non-Outstanding when disallowed, already-postponed, then parameter
  ineligibility. Its forced pass only bypasses the final parameter layer;
- Auto Postpone never admits Pending because it supplies overdue Outstanding
  candidates with `includeNonOutstanding=false`;
- normal Pending admission is not governed by overload capacity. Pending is a
  fallback learning stage after combined Outstanding and Final Drill;
- no topic learning/relearning-step array is injected into the daily merge.

An exact ASCII and UTF-16 search of this executable did not find the literal
label “Study More,” and the mapped scheduling writers reveal no separate Study
More adjustment field or clearing routine. If “Study More” refers to the
browser's Add to Outstanding command, the executable behavior is the spaced
queue insertion plus `0.9` priority target in section 9.7, with the Add-all
same-day exception. The absence of a label is not replaced here by an external
description.

## 16. Recommended clone architecture

Keep these layers separate in the new software:

```text
Numeric compatibility
  Real48 + round-even + Delphi PRNG + exact heap

Collection state
  all-element priority ranks + element records + due calendar + queues

Repetition transaction
  choose interval -> update reps/last-review -> update A -> update priority
  -> store ratio/interval/due

Reschedule transaction
  replace due/interval/ratio -> counters; normally no A/priority/repetition

Queue transaction
  reorder/membership only; never infer a due-date change

Tools
  extraction, daily merge, Smart/Auto Postpone, Mercy, Pending/Final Drill
```

This separation prevents the most serious fidelity errors: updating A during
postponement, treating priority as a scalar field, regenerating a random seed
per feature, or injecting Pending/Final Drill into the daily merge.

## 17. Minimum deterministic conformance suite

Before migrating real data, verify at least:

1. Real48 byte vectors from section 3.2.
2. The six-state seed-zero PRNG vector and `Random(N)` high-product behavior.
3. Every next-interval vector in section 5.2 and exactly two consumed draws.
4. A updates, including Real48 bytes:

   ```text
   adjust_A(2.0,10,20,false) -> 82db0d417407
   adjust_A(2.0,20,10,false) -> 814be47d1771
   adjust_A(2.0,10,20,true)  -> 82ba189d8b01
   ```

5. Blank-topic initialization bytes:

   ```text
   non-item record A -> 819a99999919 -> displayed 1.2
   ```

   Separately verify text-length override values:
   `N=0 -> 2.0`, `N=200 -> 1.625`, `N=1000 -> 1.375`.
6. Extract bytes from source A 2.0 and `N=200`:

   ```text
   child A -> 81666666965e
   source A after extract -> 816de7fba979
   ```

7. Priority insertions at exact half positions, including equal-target forced
   one-rank review drift.
8. Heap-sort fixtures containing repeated equal keys.
9. Daily queue fixtures that exhaust one type early and verify attempted merge
   counters.
10. PRNG draw counts for every stochastic branch, especially queue extraction,
    normal Smart Postpone, Advance rejection/success, and fixed-size
    randomization.
11. The fresh-collection interval-factor matrix: generate all 400 cells by the
    section 13.3 rule and compare the full 800 bytes against `info/sm8opt.dat`
    from a collection the executable created. This is cheap, needs no live SM20
    run, and is what catches a rounding rule that is right on paper and wrong
    in float64. Both shipped collections have been checked this way and match
    byte for byte.
12. *Only for a clone that schedules its items with Algorithm SM-15; see
    section 13.8.* A copied collection fixture containing eligible item
    repetition history: compare the live matrix at `+0x000`, empirical matrix
    at `+0x320`, and counts at `+0x640` after one committed repetition in SM20
    and the port; verify an abandoned repetition commits none of them. Also
    compare the fixture's profiles, all-element rank order, queue files, and
    every other byte mutated by the operation.
13. Browser batch-priority fixtures with mixed pending, memorized, dismissed,
    and deleted records; verify sequential reinsertions, dismissed Spread gaps,
    the memorized-only Adjust range scan, and exact-capacity rejection.
14. Remember/Forget/Dismiss/Undismiss fixtures comparing the status byte,
    `+0x0C..+0x12`, raw A/ratio bytes, history ID, postponement counters,
    priority rank, due calendar, and all affected queues.
15. Add-to-Outstanding fixtures for absent, earlier-position, later-position,
    reviewed-today, and Add-all cases, including insertion spacing and the
    `0.9` priority target.
16. Smart Postpone fixtures at every equality boundary, both normal and forced
    methods, and all eight combinations of the three Adjust modifier boxes;
    verify that the boxes do not change selected elements, delays, writes, or
    PRNG consumption.

## 18. Executable evidence map

| Area | Virtual address(es) |
|---|---|
| PRNG / Randomize | `0x40A350`, `0x40A390`, `0x40A310` |
| Real48 decode/encode | `0x410400`, `0x410490` |
| Text A / extract A / A adjustment / dispersion | `0xCF73F0`, `0xCF6130`, `0xCF7800`, `0xCF9E20` |
| Add element / blank-topic record initialization | `0xD7E9B0`, `0xD72070`, `0xD72C40` |
| Set/Modify A | `0xD5C790`, `0xD5C960` |
| Browser Set/Modify A handlers and workers | `0xC70C80`, `0xC70D20`, `0xD6D7FF`, `0xD6D82C` |
| Next topic interval | `0xE145A0` |
| Commit/memorize repetition | `0xD7CA60`, `0xD8AFF0`, `0xD8AFB0`, `0xD8EDD0` |
| Forced topic repetition | `0xD66670` |
| Priority percentage/position/set | `0xC99450`, `0xC99880`, `0xC9A680`, `0xC9B210` |
| Interval-driven priority drift | `0xC99B30` |
| Browser batch-priority dialog/apply | `0xD45830`, `0xD461F0`, `0xD46360`, `0xD45E30` |
| Extract priority / child generation | `0xC99A00`, `0xF25670` |
| Split/import/paste/duplicate | `0xF213C0`, `0xF3E430`, `0xF0A2A0`, `0xF2DF80`, `0xF4B9B0`, `0xD7E150` |
| General reschedule / Delay Element | `0xD82AA0`, `0xD62F00`, `0xD5C9C0` |
| Jump/manual Reschedule/Later Today | `0xF0E660`, `0xF0E7F0`, `0xCE8D10`, `0xF0E4C0` |
| Advance dialog/loop/element worker | `0xB24140`, `0xB241F0`, `0xB24F00` |
| Daily queue / curve / heap / sort | `0xB28180`, `0xB27280`, `0xB030D0`, `0xE235B0` |
| Queue randomization / priority sort | `0xE23490`, `0xE23BF0` |
| Queue creation / daily autosort | `0xD65EA0`, `0xD65D30` |
| Learning-stage selection | `0xD8A250`, `0xF3F000`, `0xF33150`, `0xF32F00` |
| Subset queue selection | `0xD80240`, `0xD899C0` |
| Browser Learn/Review launch modes | `0xC7ABF0`, `0xB78A50`, `0xF32680` |
| Remember/Forget/Dismiss/Undismiss | `0xD62E20`, `0xD8EDD0`, `0xD540A0`, `0xD7C050`, `0xD7C560`, `0xD559D0`, `0xD52E10` |
| Add Outstanding/Drill and Reset History | `0xD665B0`, `0xD663D0`, `0xD64480`, `0xE239B0`, `0xD86F50` |
| Smart Postpone dialog marshal/dispatch | `0xB80330`, `0xB7B850`, `0xB7E120` |
| Smart Postpone evaluation/apply/outer pass | `0xB81280`, `0xB81850`, `0xB81980` |
| Branch profile merge | `0xB7EDB0`, `0xB7F580`, `0xB7FE80` |
| Automatic postponement | `0xD60450` |
| O-Factor record create/load/update/recompute/commit/write | `0xCFA330`, `0xD6FB10`, `0xCFC9E0`, `0xCF43E0`, `0xCF9A80`, `0xCF2560`, `0xD54110` |
| O-Factor optimizer internals (§13) | `0xCF29D0`, `0xCF3530`, `0xCF2B60`, `0xCF30E0`, `0xCF9740`, `0xCF3110`, `0xCF4230`, `0xCF5720`, `0xCF3F30` |
| Optimizer category mapping | `0xCF64C0`, `0xCF65D0`, `0xCF66B0`, `0xCF51B0`, `0xCF3320`, `0xCF54A0` |
| Weighted regressions | `0xA875B0`, `0xA87BE0`, `0xA87350`, `0xA87FF0` |
| SM-15 item repetition path (§13.9) | `0xCF3A40`, `0xCF9C00`, `0xCF80D0`, `0xCF7F60`, `0xCF52F0`, `0xCF3C90`, `0xCF8DB0`, `0xCF8400` |
| Mercy preparation/matrix/score/gather | `0xD8CB70`, `0xCF44C0`, `0xCF6D00`, `0xD87380`, `0xD3E8D0` |
| Mercy weight defaults / planner recompute | `0xB26070`, `0xD3D8B0` |
| Priority-command pre-commit and handlers | `0xF2BBF0`, `0xF00190`, `0xF001B0`, `0xF26580`, `0xD71320`, `0xD45E30` |

## 19. Algorithm SM-20 components not yet recovered

This document covers the topic/extract scheduling path completely, plus the
SM-15 component that Mercy depends on. The item memory model is not
reconstructed. What that leaves open, in the executable's own vocabulary:

1. **The weighted combination.** SM20's repetition export writes
   `OI2, OI15, OI19, OI20, OI_FSRS, Weighted Interval, Weighted FI Interval`.
   Five component models each predict an optimum interval; the scheduled
   interval is the weighted result. Neither the weighting nor its inputs are
   recovered. This is the direct answer to "how does SuperMemo 20 schedule a
   card" and nothing here answers it.
2. **The SM-19 and SM-20 DSR models.** Their state is the `alg17/` folder:
   `StabilityIncrease.dat` (74,088 bytes), `FirstInterval.dat` (127,008),
   `Retrievability.dat` (18,240), `Recall.dat` and `RecallCases.dat` (37,044
   each), `StabilityIncreaseCases.dat`, `SleepRecall.dat`,
   `SleepRecallCases.dat`, `ForgettingCurve.dat`, `DifficultyDistribution.dat`.
   Multi-dimensional tables, larger than everything §13 covers. The export
   columns `R19, R20, D19, D20` are their outputs.
3. **SM20's internal FSRS component.** Columns `OI_FSRS, R_FSRS, D_FSRS,
   RM_FSRS`, string `Cannot compute new FSRS interval`, and
   `stats/Metric FSRS.dat`. Note this is SM20 running FSRS itself, not an
   import path.
4. **The SM-2 component.** Columns `EFactor, NewEFactor, OI2, R2, RM2`.
5. **Metric tracking.** `RM2, RM15, RM19, RM20, RM_FSRS` and
   `Met2_19, Met15_19, MetFSRS_19, Met20_19`, persisted as
   `stats/Metric SM16.dat`, `Metric SM17.dat`, `Metric FSRS.dat`,
   `Metric Weighted.dat`, `R SM16.dat`, `R SM17.dat`. Presumably how the
   weighting in item 1 is derived.

Both shipped collections confirm the boundary from the other side: every
`alg17/` file is byte-identical between them, exactly as `info/sm8opt.dat` is.
Three topic repetitions trained no item model of any kind.

Two smaller gaps sit inside what is otherwise covered: the routines listed as
not recovered at the end of §13.9, and the element-type codes the item
dispatcher maps to `3` before choosing a repetition path.

## 20. What remains collection-dependent, not algorithm-unknown

The code paths and formulas above are resolved for the hashed binary. The
following values must still be extracted from the user's live collection or
process to produce the same future, because no single constant answer exists
inside the executable:

- current PRNG seed;
- raw per-element records and exact due-calendar/queue state;
- all-element priority order;
- processed text presented to the text-length routine at creation time;
- `info/sm8opt.dat` optimizer state, including its live and empirical
  O-Factor matrices, observation counts, and fitted parameters;
- active Smart Postpone and branch profiles;
- daily randomization/merge settings and current learning mode;
- first-interval range settings at collection offsets `+0x2D/+0x2F`;
- Delphi runtime `ln`/`exp` last-bit behavior at rare rounding boundaries.

Those are migration inputs, not missing scheduler formulas. A port that exports
them and follows this document can be tested operation-by-operation against the
identified SM20 executable without relying on any external scheduler account.
