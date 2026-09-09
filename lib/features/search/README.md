# `features/search/` — full text, across everything

One field over an SQLite FTS5 index covering sources, extracts, cards, and videos. Read-only: a hit is a way into an element, never a change to one.

| File | What it is |
|---|---|
| `search_providers.dart` | The objects the Search screen needs, built once |
| `search_query.dart` | Full-text search across the whole collection |
| `search_screen.dart` | Full-text search across the collection |
