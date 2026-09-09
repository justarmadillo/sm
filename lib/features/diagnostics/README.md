# `features/diagnostics/` — what the scheduler has been doing

A development aid, not a user feature. It reads history and live state and shows whether the schedule is healthy; it never writes.

| File | What it is |
|---|---|
| `diagnostics_providers.dart` | The objects the diagnostics panel needs, built once |
| `diagnostics_query.dart` | The development diagnostics panel's read model |
| `diagnostics_screen.dart` | The development diagnostics panel |
| `scheduler_metrics_query.dart` | Builds the scheduler safety metrics from live collection state |
