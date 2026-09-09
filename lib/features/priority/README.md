# `features/priority/` — the whole collection in one ordered list

Priority is relative: an element does not have a score, it has a position. This folder owns both the slider that changes one position and the flat list that shows every position at once.

The Learning menu also lives here. It is the bulk half of the same idea — the commands that act on a selection of rows rather than on the one element in front of you.

| File | What it is |
|---|---|
| `learning_command_menu.dart` | The Learning menu, and the questions a command asks before it runs |
| `learning_commands.dart` | The Learning commands offered on one element, and the code that runs them |
| `priority_browser_command_runner.dart` | Runs the Learn-menu commands issued from the priority browser |
| `priority_browser_commands.dart` | The Learn menu on the priority browser, as explicit commands |
| `priority_browser_screen.dart` | The priority browser: the whole collection in one ordered list |
| `priority_command_runner.dart` | Runs every command that changes relative priority |
| `priority_commands.dart` | Commands that change relative priority |
| `priority_dialog.dart` | The priority slider, available on every surface |
| `priority_providers.dart` | The objects the priority slider and the priority browser need |
| `priority_query.dart` | Read model for the priority slider and the priority browser |
| `priority_view_model.dart` | ViewModels for the priority slider and the priority browser |
