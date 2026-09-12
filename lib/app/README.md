# `app/` — how the app starts, and what everything shares

| File | What it does |
|---|---|
| `collection_replacement.dart` | the narrow promise Settings uses to request a complete collection replacement |
| `collection_session_root.dart` | opens, closes, and recreates the database-backed provider scope |
| `providers.dart` | builds every object more than one screen needs |
| `startup_tasks.dart` | warms settings and runs the guarded automatic backup cadence before the first frame |
| `startup_gate.dart` | inspects and opens the collection, or preserves a classified recovery failure |
| `incremental_reader_app.dart` | the root widget, and which screen opens first |

`lib/main.dart` resolves the folders and draws `CollectionSessionRoot`. The root
then opens the database, warms settings, and runs the guarded startup work. It
can repeat that lifecycle after an imported collection replaces the live file;
package validation and file replacement remain storage responsibilities.

## Why providers.dart exists

It is the one place that chooses the *concrete* database, clock, and system
timezone rules. Everything below it takes those as constructor arguments, so
a command runner or a repository can be built in a test with no Riverpod at
all.

Anything only one screen uses is **not** here — it lives in that screen's own
`features/<screen>/<screen>_providers.dart`. That is also why `app/` no longer
imports the features: the arrows point one way now.

## The two startup tasks, and why they are in that order

1. `warmSettings` — the synchronous providers read a cached settings object, so
   the store has to be loaded first or the first frame renders against shipped
   defaults and then visibly jumps to the user's own values.
2. `runAutomaticBackupIfDue` — one rolling backup whenever the selected fixed
   cadence is due, taken at startup because that is the only moment guaranteed
   to precede the session's writes. A selected Windows or Android folder gets
   a mirrored package. A failure is reported, never fatal: the user came here
   to read.
