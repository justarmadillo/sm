# RULES.md — how to write code in this repository

Read this before changing anything. It is written for an AI assistant, but the
owner of this codebase is **not a professional programmer**: they must be able
to open any file six months from now, with no AI available, and understand it
from the code alone. Every rule below exists to serve that.

If a rule here conflicts with your defaults, this file wins. If it conflicts
with something the owner tells you directly, the owner wins.

---

## 1. The one test that must never be weakened

`test/architecture/folder_rules_test.dart` fails the build when a folder
imports something it must not. It is the shape of the app, enforced:

```
shared/      knows nothing about anything
documents/   knows only shared/
scheduling/  knows shared/, settings/, and what storage promises
settings/    knows shared/ and what storage promises
storage/     knows documents/, scheduling/, shared/ — never a screen
features/    knows everything except how rows are actually written
app/         wires it all together, so it may reach anywhere
```

**Never add a folder to that test's allow-list to make your code compile.**
If your change needs a forbidden import, the change is in the wrong folder.
The usual fix: business logic belongs in `scheduling/`, not in a screen; a
screen talks to `storage/contracts/`, never to `storage/drift/`.

Consequence worth knowing: because `scheduling/` cannot import Flutter, every
scheduling rule is testable with plain `dart test`, no widget binding, no
temporary database. Keep it that way.

---

## 2. Where new code goes

Read the `README.md` of the folder you are about to touch before the code. It
names every file in that folder and what it is for. Start at `lib/README.md`.

Every folder holding Dart files is covered, but not always by a file of its
own: `scheduling/` documents its seven subfolders from the parent, and
`storage/README.md` carries a table per subfolder. A `widgets/` folder is
described in its screen's README. If you add a file, add its row — a README
that has fallen behind the folder is worse than none, because it is believed.

**A new screen** → a new folder in `lib/features/<screen>/`, with these names.
The names always mean the same thing, in every feature:

| File | What it is |
|---|---|
| `<name>_screen.dart` | the widget the user looks at |
| `<name>_view_model.dart` | the screen's state, and the actions it can start |
| `<name>_commands.dart` | plain descriptions of what can change; no logic |
| `<name>_command_runner.dart` | carries a command out, inside a transaction |
| `<name>_query.dart` | reads only; builds what the screen displays |
| `<name>_providers.dart` | builds this feature's objects once |
| `widgets/` | pieces of this screen too big to keep in the screen file |

**Commands change things. Queries never do.** That split is why a query can be
read without wondering whether it moved someone's schedule. Do not put a write
in a `_query.dart` file.

### Where shared code goes

| It is shared, and it… | Put it in |
|---|---|
| needs nothing but Dart | `lib/shared/` |
| draws something | `lib/shared/ui/` |
| needs a repository or a stored type | an extension in `lib/storage/contracts/`, beside the contract it extends |
| is used by one screen only | that screen's own folder, never `app/providers.dart` |

The third row exists because the first two are impossible for anything that
touches storage: section 1 forbids `shared/` from importing `storage/`, so
"shared by two screens → `lib/shared/`" has no answer for a helper that needs
a repository. `ActivityRecord.forCommand` is the worked example — every command
runner needed it, and it lives on the type it builds.

**If shared code still has no legal home, stop and say so.** Do not copy it
into both callers and do not widen the folder test. A duplicate that compiles
is worse than a question that blocks: the copies drift, and the drift is
silent. Three names for one operation (`_log`, `_activity`, `_appendActivity`)
is what that looks like six months later.

---

## 3. Naming

The test for every name: *if the owner saw this name in six months with zero
context, would they know what it does and where to add something related?*

### Rules

- **No vague words.** Never `data`, `item`, `info`, `handle`, `process`,
  `manager`, `util`, `helper`, `temp`, `thing`, `value`, `obj`. Say what it
  actually is.
- **No synonyms for an operation that already exists.** Before writing a
  helper, search for what it does — `grep -rn "appendActivity" lib` — and if
  something already does it, call that. A second name for one operation reads
  as two different things, and the day they stop agreeing nobody notices,
  because nobody knew they were the same.
- **Three or more parameters means named parameters.** `_apply(command,
  schedule, rank, scale, type)` cannot be read at the call site without opening
  the function; `_apply(command: …, schedule: …, rank: …)` can. Two positional
  parameters are fine when the order is obvious from the name (`replace(old,
  new)`). This is the same rule as "no single letters", applied to the call
  site instead of the body.

  Two exceptions. An `@override` of a framework signature cannot change shape —
  `estimateMaxScrollOffset` takes the six positional arguments Flutter passes
  it. And a parser's inner loop helper (`_emit`, `addBlock`) may stay
  positional where its arguments are the same cursor triple on every call and
  naming them at forty call sites would bury the parse.

  **Forty declarations in `lib/` still take three or more positional
  parameters.** That number may fall and must not rise: converting one when you
  are already editing it is welcome, converting all forty in one pass is the
  kind of churn section 10 forbids.
- **No unexplained abbreviations.** `repetitionCount`, not `reps`.
  `reviewLog`, not `revlog`. `randomNumberSeed`, not `prngSeed`.
  `Sm20RandomNumberGenerator`, not `Sm20Prng`.
- **No single letters**, including loop and scan cursors. Use `cursor`,
  `blockIndex`, `lineAfterBlock`, `editStart`. The two exceptions the codebase
  tolerates: `i`/`j` inside a three-line loop that does nothing but count, and
  `a`/`b` in a comparator whose two arguments are genuinely symmetric — and
  even then prefer `first`/`second`.
- **Booleans read as a yes/no question**: `isLoading`, `hasError`,
  `canCommitProgress`, `shouldSort`, `didConfirm`, `wasTitleEditedByHand`.
  Never `loading`, `error`, `ok`, `valid`, `wanted`, `present`.
- **Providers are named for what they hold**: `queueViewModelProvider`,
  `contentRepositoryProvider`. Never `p1`, never a bare noun that could be
  either the object or the screen.
- **No "And" in a name.** `validateAndSaveUser` is two functions. The one
  standing exception in this repo is `compareAndSwap…`, because comparing and
  swapping are one indivisible step and splitting them would let a
  double-tapped grade overwrite itself. It is documented as an exception in
  `lib/storage/README.md`. Do not add a second exception without saying why.

### The verbs — use the same verb for the same kind of operation

Documented in `lib/storage/README.md`; repeated here because it matters most:

`find…` one row or nothing · `list…` many rows · `count…` how many ·
`insert…` create · `update…` change an existing row · `save…` either ·
`append…` add to a log that is never rewritten · `delete…` remove for good.

This holds in the key/value settings store too: `findValue`, `saveValue`,
`listAllValues`, `saveAllValues`, `deleteKey`. Do not introduce `get…`,
`fetch…`, `load…`, `store…`, `write…`, or `put…` as synonyms.

### Domain vocabulary is preserved, never "simplified"

SuperMemo and FSRS words are the domain and they stay, exactly spelled:
`aFactor`, `lapses`, `stability`, `difficulty`, `retrievability`, `interval`,
`priority`, `Mercy`, `postpone`, `drill`, `outstanding`, `memorized`,
`Sm20…`, `FSRS`. Renaming these to something "clearer" destroys the link to
the algorithm being implemented. Making a boolean read as a question
(`memorized` → `isMemorized`) is fine; replacing the word is not.

---

## 4. Names frozen by the database — the trap that breaks collections

Drift turns a Dart getter name in `lib/storage/database/tables.dart` into a SQL
column name. **Renaming one renames the column, and every collection already on
disk stops loading.** The same is true of any string used as a storage key: a
JSON key inside a snapshot, an enum's `storageName`, a settings key, or raw SQL
in a migration test.

So a few names in `storage/` are deliberately older-looking than the rest of
the app. The plain-English name lives on the Dart side of the converter:

| Frozen in the database | Plain name in the app | Bridged by |
|---|---|---|
| `RevlogEntries`, `RevlogRow`, table `revlog_entries` | `ReviewLogEntry` | `reviewLogFromRow` |
| column `reps` | `repetitionCount` | `cardMemoryFromRow` |
| keys `prng_seed`, `seed` | `randomNumberSeed` | `Sm20RuntimeStore` |

**Renaming a Dart symbol around a storage string is safe. Renaming the string
is a migration.** If a rename genuinely requires a schema change, stop and ask
the owner — do not write the migration unprompted.

`lib/storage/database/app_database.g.dart` is generated. Never edit it by hand.

---

## 5. Comments

- A **doc comment at the top of every file** saying what it is for, in one
  sentence.
- A **doc comment on every non-obvious function**, saying **why** it works this
  way — not what it does, which the name should already say.
- **Delete comments that restate the code.** `// increment the counter` above
  `counter++` is noise.
- Prefer explaining a decision over describing a mechanism. Real examples from
  this codebase, all worth imitating:
  - *"A blank of the same width when the row cannot be dragged, so every row
    stays aligned whichever sort is active."*
  - *"Scrolls sideways rather than wrapping: a wrapped line of code is a
    different line of code."*
  - *"Opening at the marker happens once per screen, not on every rebuild:
    otherwise scrolling away would keep snapping the reader back."*
  - *"No `constraints` here. On PopupMenuButton that property sizes the *menu*,
    not the button."*
- When you write a comment near a rename, **check it still reads as English.**
  A mechanical rename that turns "a heuristic" into "editStart heuristic" is a
  bug in the prose.

---

## 6. Function size and single responsibility

- **Aim for under 60 lines.** A function that needs a comment saying "now we do
  the next part" wants to be two functions.
- **A `build` method should read as a list of named parts**, not a wall of
  nesting. Extract each visible region into a named method or a private widget:
  `_appBar`, `_titleRow`, `_actionButtons`, `_readingSurface`, `_sidePanel`.
  Every screen in this repo already follows this — match it.
- **Private widget class vs. private method:** use a `class _Thing extends
  StatelessWidget` when the piece is self-contained and takes a few inputs
  (`_QueueTile`, `_LeechWarning`, `_ActionBar`). Use a private **method** when
  the piece needs `setState` or the State's keys — a widget class there would
  need ten constructor parameters and read worse.
- **Legitimately long is allowed, but rare.** A flat decoder
  (`AppSettings.fromMap`), a dispatch `switch`, or a parser loop with one
  branch per construct is cohesive at 100+ lines and should not be chopped up.
  If you cannot name the extracted piece, do not extract it.

### Where `lib/` actually stands

`python tool/audit_rules.py` prints this, so it can always be rechecked:

| | |
|---|---:|
| functions measured | 2013 |
| median function | 9 lines |
| over 60 lines | 81 (4.0%) |
| over 100 lines | 25 (1.2%) |
| over 200 lines | 6 (0.3%) |

The median is the number that matters and it is healthy. The tail is the
problem, and the tail is almost entirely command runners.

### The over-budget list

Every function over 150 lines that is **not** a parser loop or a flat decoder.
Each is one transaction doing many steps, which is why it was allowed; none is
readable in one sitting, which is why it is written down.

| Function | Lines |
|---|---:|
| `MercyCommandRunner.apply` | 289 |
| `QueueCommandRunner.runDailyAdmission` | 281 |
| `FormulationCommandRunner.formulate` | 279 |
| `MercyCommandRunner.undo` | 265 |
| `PriorityCommandRunner.batch` | 211 |
| `MercyCommandRunner.preview` | 192 |
| `ExtractCommandRunner.createExtract` | 180 |
| `ReviewCommandRunner.review` | 170 |
| `VideoCommandRunner.addClip` | 164 |
| `ReaderCommandRunner._runEdit` | 154 |

Exempt, and staying that way: `parseMarkdownBlocks` (247) and `parseRange`
(142) are parser loops with one branch per construct, and `AppSettings.fromMap`
is a flat decoder. Splitting those makes them worse.

**A change touching a listed function must not raise its number.** Lowering one
is always welcome; removing one from the table is better. Nothing may be added
to this table — a new function over 60 lines is a function to split, not a row
to append.

The numbers are line spans from the declaration to its closing brace. Recount
with the tool before editing the table; a number nobody can reproduce is a
number the next reader has to trust blindly, which is why the unreproducible
percentages that used to be here were removed.

---

## 7. Flutter and Riverpod specifics

- `arg` in a `FamilyAsyncNotifier` is Riverpod's inherited name for the value
  the screen was opened with. It **cannot** be renamed. Every such class in
  this repo carries a doc comment saying what its `arg` holds — keep doing
  that when you add one.
- Never read `DateTime.now()`. Take a `Clock`. That is how the
  daylight-saving tests cross a DST boundary without waiting for October.
- Never generate an id inline. Take an `IdGenerator`.
- Every user action that writes carries one `OperationId` all the way down, so
  a double-tapped button is recognised as the same operation rather than a new
  one. Do not create a second `OperationId` mid-flow.

---

## 8. Before you say you are done

Run both, and read the output:

```bash
dart analyze lib test
```

```bash
flutter test
```

- `dart analyze` must print **No issues found!**
- `flutter test` must print **All tests passed!** — and note the count. If it
  says `Some tests failed.`, you are not done, whatever the exit code says.
  (`flutter test` can exit 0 on a tool crash. Read the last line, not the code.)
- Do **not** run two `flutter test` processes at once. They fight over the
  build directory and the second one crashes with a file-lock error that looks
  like a real failure.
- Report failures honestly, with the output. Never claim a pass you did not see.

### The rules in this file, checked

```bash
python tool/audit_rules.py
```

One section per mechanisable rule here: positional parameters, forbidden verbs,
vague names, missing file doc comments, `DateTime.now()`, hand-rolled failure
boundaries, swallowed errors, unconstrained enum columns, and writes inside a
`_query.dart`.

It reads the text of the files, so it finds candidates, not verdicts — read
every hit before touching it. When I last ran it, twelve of the fourteen
"swallowed error" hits were correct code whose explanatory comment the checker
had stripped before looking. Two of its sections are budgets rather than zeros
(section 3's positional parameters, section 6's over-budget functions): the
number may fall, never rise.

### Formatting

Format **only the files you changed**:

```bash
dart format <the files you touched>
```

Running `dart format lib test` reformats files you never touched, which buries
your actual change in noise and can surface pre-existing lint warnings as if
you caused them.

Then check that the files you touched are actually clean:

```bash
dart format --output=none --set-exit-if-changed <the files you touched>
```

It must print nothing but the file count. A file listed as `Changed` is one you
formatted with a different tool version than the one that wrote it — say so
rather than reformatting the whole repository to silence it.

---

## 9. Three ways a bulk edit goes wrong here

All of these have already happened in this repo. Check for them every time.

**1. The rename leaks into a string.** A regex over a `.dart` file will happily
rewrite `'reps'` inside a persisted JSON key, a `storageName`, or raw SQL in a
triple-quoted test fixture. That silently breaks reading existing data, and
`dart analyze` will not catch it. After any bulk rename:

```bash
git diff -U0 -- '*.dart' | grep -E "^[+-]" | grep -E "'|\"" | grep <new-name>
```

Every hit must be a deliberate change.

**2. The rename leaks into English prose.** Replacing `a` with `editStart`
turns "a heuristic that guesses wrong" into "editStart heuristic that guesses
wrong". Grep your own doc comments after renaming any short identifier.

Prefer renaming with a script that masks string literals, then audit the diff
anyway. Do not trust the mask.

**3. A move quietly rewrites a sentence the user reads.** Splitting a screen
into `widgets/` moves hundreds of lines of hint text and button labels, and
"improving" one of them on the way is invisible in a diff that large. The text
is the product. Moving code must not change a single word of it.

After moving UI code, compare the visible strings on both sides of the move —
every long single-line literal in the file you emptied must still exist,
somewhere, in the files you filled:

```bash
git show HEAD:<old-file> | grep -oE "'[^']{8,}'" | sort > /tmp/before.txt
cat <new-files> | grep -oE "'[^']{8,}'" | sort > /tmp/after.txt
comm -23 /tmp/before.txt /tmp/after.txt
```

It must print nothing. A line that only appears in `before` is text you lost;
run the reverse (`comm -13`) for text you invented.

---

## 10. Scope

- Do what was asked. Do not widen it, do not quietly narrow it.
- **Renaming-only means renaming only** — no logic changes, no restructuring,
  no "while I was in there".
- If you find a real problem outside the scope, say so in one sentence and
  keep going. Do not fix it unasked.
- If part of the work is blocked, finish everything else and say plainly what
  you left out and why.
- Anything that changes the database schema, deletes user data, or rewrites
  history is the owner's decision, not yours. Ask first.

---

## 11. One failure boundary, and it already exists

`lib/shared/command_execution.dart` holds `executeCommand`: the transaction,
the already-applied check, the dataset generation bump, the diagnostic event,
and the `catch` that turns anything unexpected into a recorded
`UnexpectedFailure`. Storage arrives as callbacks so the innermost layer stays
free of database contracts.

- **Every command goes through `executeCommand`.** A runner's own `_run` may
  wire the callbacks; it must not reimplement the boundary.
- **Needs a different diagnostic payload? Extend `executeCommand`.** Do not
  hand-roll `try { transactions.run(...) } catch { recordCommandException }`
  around a body. Seven runners in this repo did exactly that, and one of them
  drifted so far that an unexpected Mercy failure records no diagnostic event
  at all, unlike every other command in the app.
- **Never invent a local failure message for an unexpected error.** Every
  `catch (error, stackTrace)` either returns a typed failure the caller
  already knows how to show (`ValidationFailure`, `NotFoundFailure`,
  `ConflictFailure`), or goes through `recordCommandException`. An
  `UnexpectedFailure` built by hand is an error the diagnostics panel will
  never show you.
- **An empty `catch` is not allowed.** If there is genuinely nothing to do,
  the comment has to say why nothing is the right answer.

---

## 12. What the database must guarantee, not the reader

An enum is stored as its index, so a stored number outside the enum is a
`RangeError` thrown while reading a row — a crash on a screen the user just
opened, from data that has been on disk for months.

- **A column holding an enum index carries a `CHECK` bounding it to that
  enum's range.** `IntColumn get lifecycle => integer().check(lifecycle
  .isBetweenValues(0, 2))();` SQLite then refuses to store a value the app
  cannot read back, and `Enum.values[row.lifecycle]` is safe by construction.
- **Where a column cannot carry one — a nullable log column — the reader
  guards instead.** `ElementType.fromIndexOrNull` is the pattern, and the
  guard's doc comment says which column it exists for.
- **Appending an enum value is a migration.** The `CHECK` bounds the old
  range, so widening the enum without widening the constraint writes rows the
  database rejects. Section 4 applies: stop and ask.
- The same holds for an enum index inside a JSON blob, which no constraint can
  reach. Decode it through a guard with a documented fallback, and choose the
  pessimistic value — `ProvenanceState.stale` says "this location is no longer
  trustworthy", which is exactly what an unreadable state means.

---

## 13. What counts as a behavioural change

"No behavioural changes" is a common instruction and it needs one meaning.
These are behaviour, and changing any of them needs to be asked for:

- **scheduling arithmetic** — any due date, interval, A-factor, priority rank,
  queue order, or random draw. Including the *number* of random draws: the
  PRNG is global and shared, so an extra draw shifts every later element.
- **stored data** — a column's value, a JSON key, an enum index, a revision
  counter, or whether a row is written at all.
- **user-visible text** — labels, hints, error messages, empty states.
- **what the user must click** to reach the same result.

These are *not* behaviour, and may be cleaned up freely:

- moving code between files, renaming private members, extracting a helper;
- deleting an unused parameter, an unread field, or an unreachable branch;
- a comment, a doc comment, or a README.

These are **grey — ask before changing**:

- the payload or wording of a diagnostic event, or whether one is recorded;
- what happens when stored data is damaged (a crash becoming a fallback is a
  real change, even though healthy data behaves identically);
- the shape of a public API that only tests call.

When an instruction says "no behavioural changes" and the work needs one from
the first or grey list, finish everything that does not, then ask. Do not
decide on the owner's behalf, and do not quietly skip the rest of the task.
