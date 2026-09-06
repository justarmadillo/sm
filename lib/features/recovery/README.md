# `features/recovery/` — startup recovery

| File | What it is |
|---|---|
| `recovery_screen.dart` | Explains why startup stopped and restores a backup without providers. |

This screen deliberately runs outside `ProviderScope`: opening the provider
graph would require the database whose failure brought the user here.
