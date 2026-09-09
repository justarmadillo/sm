# `features/browser/` — the whole collection as one tree

The home screen. Everything in the collection is here, nested the way the user filed it, and every other screen is reached from a row in this tree.

Two files carry more than their names suggest. `browser_view_model.dart` holds the element commands the Reader shares with the tree, so Dismiss means the same thing from both. `open_element.dart` is the single way any element is opened — one place decides that a video opens the Video screen and an extract opens the Extract screen, so a new element type is one edit rather than a dozen.

| File | What it is |
|---|---|
| `add_element_flow.dart` | Starts each standalone creation flow from the home screen |
| `browser_command_runner.dart` | Carries out the Browser's commands, one transaction each |
| `browser_commands.dart` | What the Browser can change about the collection's shape |
| `browser_providers.dart` | The objects the Browser screen needs, built once |
| `browser_screen.dart` | The Browser: the whole collection as one tree, and the way into any element in it |
| `browser_tree_query.dart` | The Browser's tree: every element in the collection, nested and ordered the way the user has filed it |
| `browser_view_model.dart` | Element commands shared by the Browser tree and the reader |
| `element_content_query.dart` | Reads the body of any one element, whatever kind it is |
| `import_sheet.dart` | Making a topic: paste or write markdown, or open a `.md` file |
| `open_element.dart` | The one way to open any element for reading or editing, wherever it was clicked |
