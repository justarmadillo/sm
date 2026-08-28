# `scheduling/` — when is something due

Pure Dart arithmetic. No Flutter, no database. A due-date bug can be reproduced
in a unit test instead of by clicking through the app.

| Folder / file | What it decides |
|---|---|
| `cards/card_scheduler.dart` | when a card comes back (FSRS) |
| `topics/topic_scheduler.dart` | when a source or extract comes back (SM-20) |
| `daily_queue/queue_policy.dart` | what is in today's queue, and in what order |
| `mercy/mercy.dart` | how a backlog is spread over future days |
| `mercy/mercy_workflow.dart` | the preview you confirm, and the snapshot that undoes it |
| `postpone/sm20_postpone.dart` | how an overloaded day is pushed out |
| `postpone/sm20_advance.dart` | how future work is pulled closer to today |
| `history/revlog.dart` | one row for every scheduling event, of any kind |
| `history/scheduler_event.dart` | the append-only audit trail |
| `history/scheduling_journal.dart` | writes that trail, inside the caller's transaction |
| `metrics/scheduler_metrics.dart` | is the schedule healthy? (diagnostics panel) |
| `element.dart` | the shape shared by sources, extracts, and cards |
| `study_day.dart` | the day boundary everything is expressed in |
| `priority_rank.dart` | relative importance, as a sortable key |
| `sm20_numeric.dart` | exact Delphi float maths, to match SuperMemo bit for bit |
| `scheduling_context.dart` | builds the schedulers from the user's current settings |
| `effective_due_query.dart` | the one answer to "when does this actually come back?" |

## Vocabulary

These are SuperMemo's own words, kept so the code can be checked against the
published algorithm:

- **topic** — a source or an extract; something you read.
- **item** — a card; something you answer.
- **outstanding** — due today and not yet done.
- **mercy** — bulk relief: spread a backlog over several future days.
- **postpone** — push work later. **advance** — pull work earlier.
- **A-factor** — how fast a topic's interval grows.

## Why the maths is exact

`sm20_numeric.dart` reproduces Delphi's 48-bit real arithmetic. That is not
nostalgia: it is what makes this app's intervals match real SuperMemo
collections, which is how the conformance vectors in
`test/scheduling/sm20_collection_fixture_test.dart` can check them.

## Where the transactions are

Nothing here writes to the database. The command runners in
`features/daily_queue/`, `features/review/`, and `features/priority/` call into
these files and then save the result. Mercy is the one to watch: the maths is
here, but `features/daily_queue/mercy_command_runner.dart` runs it, because
applying a batch needs the queue's candidate loader.
