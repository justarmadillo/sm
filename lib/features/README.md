# `features/` — one folder per screen you can see

If you can point at it in the running app, its code is in one of these folders.

| Folder | The screen | What it does |
|---|---|---|
| `browser/` | Browser | the knowledge tree: making elements, and filing them |
| `reader/` | Reader | reading a document and making extracts from it |
| `extract/` | Extract | working one extract over, turning it into cards |
| `review/` | Review | showing a card, revealing it, grading it |
| `daily_queue/` | Today | the day's study session, and the ways to relieve it |
| `priority/` | Priority browser | the slider, and the whole collection in one list |
| `search/` | Search | full-text search across everything |
| `settings/` | Settings | changing how the app behaves |
| `diagnostics/` | Diagnostics | what the scheduler has been doing (development aid) |

## The files inside a feature folder

Not every feature has all of them, but the names always mean the same thing.

| File | What it is |
|---|---|
| `<name>_screen.dart` | the widget the user looks at |
| `<name>_view_model.dart` | the screen's state, and the actions it can start |
| `<name>_commands.dart` | plain descriptions of what can change; no logic |
| `<name>_command_runner.dart` | the code that carries a command out, in a transaction |
| `<name>_query.dart` | reads only; builds what the screen displays |
| `<name>_providers.dart` | builds this feature's objects once, for the screen to use |
| `widgets/` | pieces of this screen, too big to keep in the screen file |

Commands change things. Queries never do. That split is why you can read a
query without worrying that it moved someone's schedule.

## Adding a screen

Make a folder here named after the screen, follow the file names above, and add
its provider file. If the new screen needs something two screens share, that
belongs in `shared/`, not copied into both.
