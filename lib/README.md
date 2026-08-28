# Map of `lib/`

Start here when you do not know where something lives.

```
lib/
  main.dart      where the app starts
  app/           startup and the objects the whole app shares
  features/      ONE FOLDER PER SCREEN YOU CAN SEE
  documents/     what a document is made of
  scheduling/    when something is due
  settings/      every setting, and how it is stored
  storage/       the database, files, and folders on disk
  shared/        clock, ids, results, diagnostics, shared UI
```

## Which folder do I want?

| I want to change… | Go to |
|---|---|
| what a screen looks like or does | `features/<that screen>/` |
| how markdown is parsed into blocks | `documents/` |
| when a card or topic comes back | `scheduling/` |
| what today's queue contains | `scheduling/daily_queue/` + `features/daily_queue/` |
| a setting, or its default | `settings/` |
| what is saved, or a database column | `storage/` |
| a value used everywhere (time, ids) | `shared/` |
| which concrete database is opened | `app/providers.dart` |

## How one action flows through the app

Take "the user presses Later" on the Reader:

1. `features/reader/reader_screen.dart` — the button.
2. `features/reader/reader_view_model.dart` — the screen's state; builds a command.
3. `features/reader/reader_commands.dart` — `PostponeElement`, a plain description of the intent.
4. `features/reader/reader_command_runner.dart` — opens a transaction and carries it out.
5. `scheduling/topics/topic_scheduler.dart` — works out the new due day.
6. `storage/contracts/learning_repository.dart` — the promise "this can be saved".
7. `storage/drift/drift_learning_repository.dart` — the SQL that actually saves it.

Every feature follows that shape. `*_commands.dart` lists what can change;
`*_command_runner.dart` is the code that changes it; `*_query.dart` only reads.

## The rule that keeps this readable

`test/architecture/folder_rules_test.dart` fails the build if a folder imports
something it should not — for example if `scheduling/` starts importing Flutter,
or a screen writes a database row directly. Read that file for the exact list.
