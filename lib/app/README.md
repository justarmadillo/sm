# `app/` — how the app starts, and what everything shares

| File | What it does |
|---|---|
| `providers.dart` | builds every object more than one screen needs |
| `startup_tasks.dart` | work that must finish before the first frame |
| `incremental_reader_app.dart` | the root widget, and which screen opens first |

`lib/main.dart` runs before any of it: find the folders, copy the database if a
migration is about to run, open it, warm the settings store, then draw.

## Why providers.dart exists

It is the one place that chooses the *concrete* database, clock, and timezone
rules. Everything below it takes those as constructor arguments, so a command
runner or a repository can be built in a test with no Riverpod at all.

Anything only one screen uses is **not** here — it lives in that screen's own
`features/<screen>/<screen>_providers.dart`. That is also why `app/` no longer
imports the features: the arrows point one way now.

## The two startup tasks, and why they are in that order

1. `warmSettings` — the synchronous providers read a cached settings object, so
   the store has to be loaded first or the first frame renders against shipped
   defaults and then visibly jumps to the user's own values.
2. `runDailyBackupIfDue` — at most one rolling backup per study day, taken at
   startup because that is the only moment guaranteed to precede the day's
   writes. A failure is reported, never fatal: the user came here to read.
