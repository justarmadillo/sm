# `settings/` — every setting, and how it is stored

One file per group. `app_settings.dart` composes them all and owns reading them
back from stored key/value pairs.

| File | Controls |
|---|---|
| `study_day_settings.dart` | home timezone, and what hour the day rolls over |
| `queue_settings.dart` | daily caps, and the topic/card mix |
| `card_settings.dart` | FSRS parameters, leech limits |
| `remember_settings.dart` | what happens when an element is remembered again |
| `postpone_settings.dart` | how an overloaded day is handled automatically |
| `smart_postpone_settings.dart` | the manual Smart Postpone pass, and its profiles |
| `mercy_settings.dart` | how a backlog is spread over future days |
| `diagnostics_settings.dart` | whether the log is written, and how large it gets |
| `settings_store.dart` | reads them once, caches them, writes changes back |
| `settings_list_equality.dart` | compares the list-shaped values by content |

The screen that edits them is `features/settings/`, not here.
`features/settings/fsrs_settings_rescheduler.dart` atomically saves relevant
card-setting changes, replays memory when the parameter version changes, and
recalculates existing FSRS due dates when requested.

## The stored keys are strings, and they are permanent

`app_settings.dart` maps each field to a key such as `queue.auto_sort`.
Renaming a **Dart field** is safe. Changing a **key string** is not: the old
value stays in the database under the old key, and the setting silently reverts
to its default the next time the app starts.

## Adding a setting

Add the field to its group's file, give it a default, map it to a new key in
`app_settings.dart` (both directions — writing and reading back), and add the
control to `features/settings/settings_screen.dart`. The round-trip test in
`test/settings/app_settings_test.dart` will catch a half-finished one.
