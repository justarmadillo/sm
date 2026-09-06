# `shared/` — used by everything, depends on nothing

| File | What it is |
|---|---|
| `clock.dart` | the only place the current time is read from |
| `id_generator.dart` | new identifiers; random in the app, fixed in tests |
| `result.dart` | a value that is either a success or a named failure |
| `operation_id.dart` | one id that follows a single user action all the way down |
| `text_excerpt.dart` | collapses and bounds text for one-line list previews |
| `diagnostics_sink.dart` | where the app records what it just did |
| `in_memory_diagnostic_sink.dart` | the recent-events ring the diagnostics panel shows |
| `fan_out_diagnostic_sink.dart` | sends one event to several places at once |
| `command_base.dart` | what every command has: an operation id and a timestamp |
| `command_execution.dart` | the transaction, retry, generation, and diagnostic boundary every command shares |
| `utf8_offsets.dart` | Dart string indices to UTF-8 byte offsets, and back |
| `ui/` | shared visual language, responsive layout rules, and small reusable widgets |

## `shared/ui/`

| File | What it is |
|---|---|
| `app_theme.dart` | the app's colours and typography |
| `desktop_scroll_view.dart` | keyboard scrolling with a persistent desktop scrollbar |
| `element_type_badge.dart` | one icon, colour, and label for each element type |
| `screen_width.dart` | the shared compact-versus-wide layout decision |
| `status_pill.dart` | compact coloured state labels shared by study screens |
| `toast_message.dart` | small self-dismissing success and error notices |

## Two rules

- Files directly in `shared/` are plain Dart. No Flutter, no database.
- `shared/ui/` may use Flutter, but must not depend on any single screen.

Both are enforced by `test/architecture/folder_rules_test.dart`.

## Why a Clock instead of DateTime.now()

Because a scheduler that reads the wall clock cannot be tested. Every layer
takes a `Clock`; the app hands it `SystemClock`, and a test hands it
`FakeClock`. That is how the daylight-saving tests cross a DST boundary without
waiting for October.

## Why an OperationId

Press "Good" twice quickly and the second press must not count as a second
review. The screen makes one `OperationId`, the command carries it, and every
row and log line written for that press records it — so the second press is
recognised as the same operation instead of a new one.
