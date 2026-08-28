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

Each folder has its own `README.md`. Read the one for the folder you are about
to touch — it lists every file and what it is for. Start at `lib/README.md`.

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

**Shared by two screens** → `lib/shared/`, never copied into both.
**Used by one screen** → that screen's own folder, never `app/providers.dart`.

---

## 3. Naming

The test for every name: *if the owner saw this name in six months with zero
context, would they know what it does and where to add something related?*

### Rules

- **No vague words.** Never `data`, `item`, `info`, `handle`, `process`,
  `manager`, `util`, `helper`, `temp`, `thing`, `value`, `obj`. Say what it
  actually is.
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

Current state of `lib/`, which you are expected not to make worse:

| | |
|---|---|
| median function | 11 lines |
| over 60 lines | 32 (3.8%) |
| over 100 lines | 12 (1.4%) |

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

Still oversized and known: the command runners
(`MercyCommandRunner.apply`, `runDailyAdmission`, `formulate`, `review`).
These are single transactions doing many steps. If you touch one, leave it no
longer than you found it.

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

### Formatting

Format **only the files you changed**:

```bash
dart format <the files you touched>
```

Running `dart format lib test` reformats files you never touched, which buries
your actual change in noise and can surface pre-existing lint warnings as if
you caused them.

---

## 9. Two ways bulk renames go wrong here

Both of these have already happened in this repo. Check for them every time.

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
