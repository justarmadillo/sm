# `features/daily_queue/` — today's study session

The count-based session that mixes cards and topics. What is admitted today is decided once, inside the queue's own transaction, so what the screen shows and what the collection recorded as deferred are one decision rather than two.

Mercy and Smart Postpone live here rather than in `settings/` because they are things the user *does* to a backlog, not preferences.

| File | What it is |
|---|---|
| `mercy_command_runner.dart` | Canonical preview, apply, and undo transactions for SM20 Mercy |
| `queue_candidates_query.dart` | Reads the population the day's queue is built from |
| `queue_command_runner.dart` | Application transactions for SM20's three learning queues |
| `queue_commands.dart` | Commands that shape the day's queue |
| `queue_providers.dart` | The objects today's study queue needs, built once |
| `queue_query.dart` | Read model for the daily study queue |
| `queue_screen.dart` | The user's count-based study session, mixing cards and topics |
| `queue_view_model.dart` | Presentation state for the daily heterogeneous queue |
| `open_study_element.dart` | Shared dispatch from an element type to its study screen |
| `smart_postpone_dialog.dart` | The Smart Postpone simulation report and its confirmation |
| `study_screen_outcome.dart` | Outcome returned by a screen opened from the study queue |
