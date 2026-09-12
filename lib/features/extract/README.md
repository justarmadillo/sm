# `features/extract/` — processing one extract

An extract is a passage taken out of a source that is scheduled in its own right. This screen is where one is read, refined, cut further, and turned into cards.

The shared formulation page is here because extracts, topics, and videos all use the same card creation workflow and return to their calling page when it closes.

| File | What it is |
|---|---|
| `extract_command_runner.dart` | Runs every command that creates or changes an extract |
| `extract_commands.dart` | Commands for creating and processing extracts |
| `extract_context_overlay.dart` | The context overlay: where an extract came from, without leaving the page |
| `extract_providers.dart` | The objects the Extract screen and card formulation page need |
| `extract_screen.dart` | Processing surface for an independently scheduled extract |
| `extract_view_model.dart` | ViewModel for independently processing one extract |
| `formulation_command_runner.dart` | Application boundary for batch Q&A and cloze formulation |
| `formulation_commands.dart` | Commands and immutable drafts, including optional Extra content, for turning an element into recall cards |
| `formulation_dialog.dart` | Full-page batch Q&A, cloze, and overlapper card creation with revealed-side Extra content |
