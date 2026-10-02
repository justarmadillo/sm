# `features/custom_study/` — browse by tag, save decks, study and cram

The tag browser. Pick tags to include or exclude, see every element they
reach (tags inherit through filing, exactly as in the Browser), and save the
filter as a named deck — an Anki-style filtered deck that is re-read every
time it is opened, so it never holds a stale list.

A deck never invokes daily admission or queue randomization. A Random deck
shuffles with a seed the session owns, never the collection's shared
random-number stream. Every write to an element goes through the existing
study screens.

How a session treats each element is decided once, at Start:

| Element | Deck reschedules | Deck does not reschedule |
|---|---|---|
| cram-only (`#cram`, directly or through a parent) | practice | practice |
| card | early review: FSRS grades it even when not due | practice |
| source, extract, video | read as usual; Done advances it | practice: Next moves nothing |

"Due only" uses the queue's own rule, so a new card or a pending topic is not
due, and cram-only elements — which have no spaced-repetition due date — are
left out.

| File | What it is |
|---|---|
| `custom_study_query.dart` | Read-only matches for a filter: include/exclude tags, types, due only, order, limit, tag counts |
| `custom_study_view_model.dart` | The filter being edited, saved decks, matches, and the frozen session plan |
| `custom_study_commands.dart` | Plain requests to save, change, and delete decks |
| `custom_study_command_runner.dart` | Carries deck commands out inside the shared command boundary |
| `custom_study_screen.dart` | The two-pane (or folded, on a phone) screen and the study route loop |
| `custom_study_providers.dart` | Objects built once for this screen |
| `widgets/deck_list.dart` | The saved decks and the unsaved filter, as a pickable list |
| `widgets/tag_filter_list.dart` | Every tag with its count, cycled off → included → excluded |
| `widgets/deck_options.dart` | Types, match all/any, due only, order, limit, and reschedule |
| `widgets/match_list.dart` | The matched elements, with those past the limit set apart |
| `widgets/deck_name_dialog.dart` | Asks for a deck's name, for Save as deck and Rename |
