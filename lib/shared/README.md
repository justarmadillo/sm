# `shared/` — used by everything, depends on nothing

| File | What it is |
|---|---|
| `clock.dart` | the only place the current time is read from |
| `id_generator.dart` | new identifiers; random in the app, fixed in tests |
| `result.dart` | a value that is either a success or a named failure |
| `operation_id.dart` | one id that follows a single user action all the way down |
| `diagnostics_sink.dart` | where the app records what it just did |
| `in_memory_diagnostic_sink.dart` | the recent-events ring the diagnostics panel shows |
| `fan_out_diagnostic_sink.dart` | sends one event to several places at once |
| `command_base.dart` | what every command has: an operation id and a timestamp |
| `utf8_offsets.dart` | Dart string indices to UTF-8 byte offsets, and back |
| `ui/` | the colours, the toast, and the badge every screen reuses |

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
