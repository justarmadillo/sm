# `storage/` — the database, files, and folders on disk

| Folder | What it holds |
|---|---|
| `contracts/` | plain interfaces: what the app promises it can save and load |
| `database/` | drift table definitions, schema version, migrations |
| `drift/` | the classes that keep the promises in `contracts/`, using SQL |
| `files/` | rolling backups and the rotating diagnostic log |
| `platform/` | where the app's folders are, and timezone rules |

One contract, one file, one implementation of the same name:
`contracts/learning_repository.dart` is kept by `drift/drift_learning_repository.dart`.

## Why contracts and implementations are separate

A screen imports the **contract**, never the drift class. That is what lets a
test hand a screen a hand-written stand-in instead of opening a real database,
and it is enforced by `test/architecture/folder_rules_test.dart`.

## Before you rename anything in `database/tables.dart`

Drift turns a Dart getter name into a SQL column name. Renaming
`parentIsSource` there renames the column, and every existing collection stops
loading. The comment at the top of that file says what to do instead.

`database/app_database.g.dart` is generated — never edit it by hand.

## The verbs, so you can guess a method name

`find…` one row or nothing · `list…` many rows · `count…` how many ·
`insert…` create · `update…` change an existing row · `save…` either ·
`append…` add to a log that is never rewritten · `delete…` remove for good.

`compareAndSwap…` is the exception that keeps an "and" in its name: comparing
and swapping are one indivisible step, and splitting them would let a
double-tapped grade overwrite itself.

## Where the data actually is

`platform/app_paths.dart` decides. `files/backup_service.dart` copies the
database once per study day, before the day's first write, and again before any
migration runs.
