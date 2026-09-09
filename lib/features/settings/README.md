# `features/settings/` — editing preferences and collection housekeeping

| File | What it does |
|---|---|
| `settings_screen.dart` | the app bar, the save controls, the profile registry, and the list of sections |
| `widgets/` | one file per section of that list |
| `settings_view_model.dart` | holds the settings draft and starts save, maintenance, import, and export actions |
| `settings_controls.dart` | reusable labelled controls used only by this screen |
| `fsrs_settings_rescheduler.dart` | saves FSRS policy changes and updates affected schedules transactionally |
| `collection_file_dialogs.dart` | selects and saves `.irbackup` packages through Windows or Android dialogs |
| `settings_providers.dart` | supplies the platform dialogs and app-level replacement promise to this screen |

## `widgets/`

One section per file, each taking the same draft and the same view model. The
screen file is then short enough to show what Settings *is* — a list of
sections in a fixed order — without scrolling past every row in every one.

| File | What it does |
|---|---|
| `study_day_section.dart` | when one study day ends and the next begins |
| `queue_section.dart` | how much of the collection today's queue admits |
| `remember_section.dart` | what a newly remembered element starts out with |
| `card_memory_section.dart` | FSRS, and the safeguards around a card's memory |
| `smart_postpone_sections.dart` | scope, parameters, and the A-factor nudges |
| `mercy_section.dart` | how Mercy chooses what to move, and how far |
| `collection_data_section.dart` | exporting and importing the whole collection |
| `maintenance_section.dart` | repairing and compacting the collection |
| `diagnostics_section.dart` | what the app records about its own behaviour |

The three Smart Postpone sections share one file because they edit one profile
between them: the helper that writes it back exists once, so no row can quietly
write to a different profile than the row above it.

The screen may ask storage and app-level contracts to perform work, but it does
not import Drift or write database rows itself. One `OperationId` is created
when a confirmed collection action starts and follows that action downward.
