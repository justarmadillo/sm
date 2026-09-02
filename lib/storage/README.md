# `storage/` — the database, files, and folders on disk

| Folder | What it holds |
|---|---|
| `contracts/` | plain interfaces: what the app promises it can save and load |
| `database/` | drift table definitions, schema version, migrations |
| `drift/` | the classes that keep the promises in `contracts/`, using SQL |
| `files/` | rolling backups, source image blobs, and the rotating diagnostic log |
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

This is why a few names in `database/` are shorter or older-looking than the
rest of the app. They are frozen because a shipped collection already uses
them, and the plain-English name lives on the Dart side of the converter:

| Frozen in the database | Plain name in the app | Bridged by |
|---|---|---|
| `RevlogEntries`, `RevlogRow`, table `revlog_entries` | `ReviewLogEntry` | `reviewLogFromRow` |
| column `reps` | `repetitionCount` | `cardMemoryFromRow` |
| keys `prng_seed`, `seed` | `randomNumberSeed` | `Sm20RuntimeStore` |

The same rule holds for any string used as a storage key: a JSON key inside a
snapshot, an enum's `storageName`, or a settings key. Renaming the Dart symbol
around them is safe; renaming the string is a migration.

`database/app_database.g.dart` is generated — never edit it by hand.

## The verbs, so you can guess a method name

`find…` one row or nothing · `list…` many rows · `count…` how many ·
`insert…` create · `update…` change an existing row · `save…` either ·
`append…` add to a log that is never rewritten · `delete…` remove for good.

These hold in the key/value settings store too: `findValue`, `saveValue`,
`listAllValues`, `saveAllValues`, `deleteKey`.

`compareAndSwap…` is the exception that keeps an "and" in its name: comparing
and swapping are one indivisible step, and splitting them would let a
double-tapped grade overwrite itself.

## Where the data actually is

`platform/app_paths.dart` decides. `files/source_asset_file_store.dart` keeps
images under portable SHA-256 names in private application support.
`files/backup_service.dart` packages the database and referenced images once
per study day, before the day's first write. Pre-migration backups remain a
database-only snapshot because their one job is to protect the schema upgrade.
