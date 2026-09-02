# `documents/` — what a document is made of

Pure Dart. No Flutter, no database, no scheduling. These files can be run in a
plain unit test, which is why a parsing bug is cheap to reproduce.

| File | What it is |
|---|---|
| `source.dart` | an imported document: its markdown and reading position |
| `source_asset.dart` | metadata for an image referenced by source markdown |
| `document.dart` | one source's markdown parsed at one revision |
| `block.dart`, `block_content.dart` | one paragraph, heading, list item, or fence |
| `extract.dart` | a passage promoted into its own learning object |
| `card.dart` | a question formulated from an extract |
| `markdown_block_parser.dart` | splits markdown into blocks, keeping exact offsets |
| `markdown_inline_parser.dart` | bold, italics, links — also keeping exact offsets |
| `inline_markup.dart` | the rendered text, and its map back to the markdown |
| `reader_anchor.dart` | a stable position in a document |
| `reader_coordinates.dart` | screen position becomes stored document offset here |
| `text_splice.dart` | the only way a source's text is allowed to change |
| `apply_source_edit.dart` | applies one splice, in one pure step |
| `source_edit.dart` | the append-only record of every edit ever made |
| `position_migration.dart` | how stored positions move when the text is spliced |
| `block_edit.dart` | turns an edit made to one block into an exact splice |
| `outline.dart` | the headings, and which stretch of text each one owns |

## The thing to understand first

Every position is a **UTF-8 byte offset into the source markdown** — not a
character index, and not a screen coordinate. That is what lets an extract made
last month still point at the right words after the document has been edited.

`shared/utf8_offsets.dart` does the conversion between Dart's string indices
and those byte offsets. `position_migration.dart` does the moving when text is
inserted or deleted before a stored position.
