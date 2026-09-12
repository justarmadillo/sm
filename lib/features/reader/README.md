# `features/reader/` — where the user spends their time

Continuous scrolling over one source, with the bars kept compact because the text is the point. The Reader is also where extraction starts, which is why selection is a first-class thing here and not a detail of the text widget.

`reader_command_runner.dart` is shared with the Browser: both can dismiss, postpone, and reschedule an element, and one runner means one set of scheduling rules.

| File | What it is |
|---|---|
| `reader_command_runner.dart` | Runs every command the Reader and the Browser can issue |
| `reader_commands.dart` | Explicit commands for everything the Reader can change |
| `reader_image_input.dart` | Reads and validates images chosen from the system picker or clipboard |
| `reader_providers.dart` | The objects the Reader screen needs, built once |
| `reader_screen.dart` | The Reader screen: continuous scrolling with compact persistent bars |
| `reader_view_model.dart` | ViewModel for the Reader |
| `typography_controller.dart` | Reader typography, persisted across sessions |

## `widgets/`

Pieces of this screen too big to keep in the screen file.

| File | What it is |
|---|---|
| `block_editor.dart` | Editing one block in place, with picker and clipboard image insertion |
| `document_editor.dart` | Fullscreen editing of one source's complete Markdown |
| `block_span_builder.dart` | Turns a block's inline layout into Flutter spans |
| `block_view.dart` | Renders one block of a document |
| `extract_highlights.dart` | Turns provenance into what the reader actually sees on the page |
| `reader_selection.dart` | Block-aware text selection with exact source coordinates |
| `reader_side_panel.dart` | The Reader's side panel: outline navigation everywhere, Windows-only outline editing, and extracts |
| `reader_view.dart` | The virtualized reading surface |
| `selection_knobs.dart` | The two draggable ends of a touch selection |
| `selection_toolbar.dart` | The floating toolbar that follows a selection |
