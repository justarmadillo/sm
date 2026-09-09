# `storage/` — the database, files, and folders on disk

| Folder / file | What it holds |
|---|---|
| `contracts/` | plain interfaces: what the app promises it can save and load |
| `database/` | drift table definitions, schema version, migrations |
| `drift/` | the classes that keep the promises in `contracts/`, using SQL |
| `files/` | rolling backups, source image blobs, and the rotating diagnostic log |
| `platform/` | where the app's folders are, system timezone rules, and legacy zone-name compatibility |
| `dataset_lineage.dart` | stable collection identity and future handoff lineage |

One contract, one file, one implementation of the same name:
`contracts/learning_repository.dart` is kept by `drift/drift_learning_repository.dart`.

## Why contracts and implementations are separate

A screen imports the **contract**, never the drift class. That is what lets a
test hand a screen a hand-written stand-in instead of opening a real database,
and it is enforced by `test/architecture/folder_rules_test.dart`.

## Where rows become domain values

`database/row_converters.dart` is the only boundary where Drift row shapes,
frozen storage names, and readable domain names meet. The `tryDecode…`
functions used by integrity repair turn malformed persisted JSON into a typed
`StorageFailure` instead of leaking a cast or decoder exception. Rebuilding a
card's redundant JSON snapshot from typed columns also lives there, rather than
being reimplemented inside the database check.

Each Drift repository keeps repeated query ordering and multi-step writes in
named private functions. Public methods therefore read as the storage intent,
while row mapping and SQL mechanics remain in one discoverable place.

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
`files/backup_restore_service.dart` is the matching reader. It streams a package
into app-owned staging, validates and migrates that expendable copy, then
promotes it only after Drift is closed. Promotion moves the live database and
its WAL/SHM sidecars aside first, and restores every displaced file if the
replacement cannot be promoted. Manual exports and pre-import safety backups
use the same package writer as daily backups.

`DatabaseCheck.repairIntegrity()` in `contracts/database_check.dart`, implemented
by `drift/drift_database_check.dart`, repairs logical relationships that SQLite
cannot express as foreign keys. Unlike ordinary maintenance, that pass may
create or delete current-state rows, while leaving append-only history
untouched.

---

## Every file, by folder

### `contracts/` — what the app promises

An interface per area. A screen depends on these and never on `drift/`, which
is what lets the whole app be tested against fakes and what stops a screen from
writing a row itself.

| File | What it promises |
|---|---|
| `content_repository.dart` | What the app promises about saving and loading the things you read |
| `database_check.dart` | Findings and outcomes from collection-level integrity repair |
| `database_maintenance.dart` | What the app promises about keeping the database file in good shape |
| `learning_repository.dart` | What the app promises about saving and loading when things come back |
| `occlusion_repository.dart` | The storage promise for image-occlusion metadata owned by cards |
| `search_repository.dart` | What the app promises about the full-text index |
| `settings_repository.dart` | What the app promises about storing settings |
| `source_asset_repository.dart` | The storage promise for image metadata referenced by source markdown |
| `tag_repository.dart` | What the app promises about flat tags and their direct element links |
| `transaction_runner.dart` | Transaction scope shared by every repository |
| `transfer_repository.dart` | What the app promises about this collection's identity and lineage |
| `video_repository.dart` | What the app promises about saving and loading the videos you study |

### `database/` — the schema itself

| File | What it is |
|---|---|
| `app_database.dart` | The application database: connection policy, schema version, migrations |
| `connection.dart` | Opening the live database and its in-memory test twin |
| `row_converters.dart` | Conversion between Drift rows and domain values |
| `tables.dart` | Drift table definitions for the whole v1 schema |

`app_database.g.dart` sits beside these. It is generated — never edit it.

### `drift/` — the SQL that keeps the promises

One implementation per contract, same order, same names.

| File | What it is |
|---|---|
| `drift_content_repository.dart` | Saves and loads sources, blocks, extracts, and cards, using Drift |
| `drift_database_check.dart` | Drift implementation of the atomic collection check and repair pass |
| `drift_database_maintenance.dart` | Compacts and repairs the database file, using Drift |
| `drift_learning_repository.dart` | Saves and loads schedules, priority, and the repetition log, using Drift |
| `drift_occlusion_repository.dart` | Drift-backed storage for image-occlusion metadata |
| `drift_search_repository.dart` | Saves and queries the full-text index, using Drift |
| `drift_settings_repository.dart` | Saves and loads settings keys and values, using Drift |
| `drift_source_asset_repository.dart` | Drift-backed storage for source image metadata |
| `drift_tag_repository.dart` | Saves and queries flat tags using Drift |
| `drift_transaction_runner.dart` | Runs a block of work inside one database transaction |
| `drift_transfer_repository.dart` | Saves and loads this collection's identity and lineage, using Drift |
| `drift_video_repository.dart` | Saves and loads videos and the ranges taken over them, using Drift |

### `files/` — what is not in the database

| File | What it is |
|---|---|
| `backup_restore_service.dart` | Stages and restores validated collection packages and their image assets |
| `backup_service.dart` | Rolling backups of the live database |
| `rotating_log_sink.dart` | A local rotating structured log, one JSON object per line |
| `source_asset_file_store.dart` | Content-addressed image files owned by the application |

### `platform/` — what the operating system decides

| File | What it is |
|---|---|
| `app_paths.dart` | Where the application keeps its files |
| `time_zones.dart` | System-timezone scheduling and legacy named-zone compatibility |
