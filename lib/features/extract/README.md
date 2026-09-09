# `features/extract/` — processing one extract

An extract is a passage taken out of a source that is scheduled in its own right. This screen is where one is read, refined, cut further, and turned into cards.

The formulation dialog is here rather than in its own folder because it only ever opens over an extract or a video, and closing it returns to the same page.

| File | What it is |
|---|---|
| `extract_command_runner.dart` | Runs every command that creates or changes an extract |
| `extract_commands.dart` | Commands for creating and processing extracts |
| `extract_context_overlay.dart` | The context overlay: where an extract came from, without leaving the page |
| `extract_providers.dart` | The objects the Extract screen and its formulation dialog need |
| `extract_screen.dart` | Processing surface for an independently scheduled extract |
| `extract_view_model.dart` | ViewModel for independently processing one extract |
| `formulation_command_runner.dart` | Application boundary for batch Q&A and cloze formulation |
| `formulation_commands.dart` | Commands and immutable drafts for turning an element into recall cards |
| `formulation_dialog.dart` | Batch Q&A and cloze formulation without leaving the current extract |
