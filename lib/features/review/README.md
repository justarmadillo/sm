# `features/review/` — reveal, then grade

The recall half of the app. A card is shown, the answer and any Extra content are revealed, and a grade is recorded through FSRS. The top toolbar exposes the same Learning commands as the Priority screen. Grading is exactly-once: the command carries one operation id all the way down, so a double-tapped button is recognised as the same review rather than a second one.

| File | What it is |
|---|---|
| `review_command_runner.dart` | Exactly-once FSRS review application boundary |
| `review_commands.dart` | Commands for recall reviews |
| `review_providers.dart` | The objects the Review screen needs, built once |
| `review_screen.dart` | Reveal-first review surface for FSRS cards |
| `review_view_model.dart` | ViewModel for one reveal-and-grade recall interaction |

## `widgets/`

Pieces of the review screen whose state is clearer in isolation.

| File | What it is |
|---|---|
| `review_occlusion_panel.dart` | Answer-side image occlusion with reveal-all and restore controls |
