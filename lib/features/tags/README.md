# `features/tags/` — naming things, and finding them again

Flat tags with direct links to elements; no hierarchy, on purpose. A tag is stored by a stable identifier so renaming one does not touch the rows that use it, and `element_tag_name_index.dart` is what turns those identifiers back into names for a screen.

| File | What it is |
|---|---|
| `element_tag_name_index.dart` | Resolves stable tag identifiers into display names for screen read models |
| `tags_command_runner.dart` | Carries tag commands out inside the shared command boundary |
| `tags_commands.dart` | Plain requests for changes to tags and element-tag links |
| `tags_picker_dialog.dart` | A reusable picker for choosing the direct tags of elements |
| `tags_providers.dart` | The objects the Tags screen and picker need, built once |
| `tags_query.dart` | Read-only models for the Tags screen |
| `tags_screen.dart` | The screen for creating, renaming, and deleting flat tags |
| `tags_view_model.dart` | Screen actions for creating, renaming, and deleting tags |
