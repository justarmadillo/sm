# `features/settings/` — editing preferences and collection housekeeping

| File | What it does |
|---|---|
| `settings_screen.dart` | draws setting sections, save controls, and collection transfer confirmation |
| `settings_view_model.dart` | holds the settings draft and starts save, maintenance, import, and export actions |
| `settings_controls.dart` | reusable labelled controls used only by this screen |
| `fsrs_settings_rescheduler.dart` | saves FSRS policy changes and updates affected schedules transactionally |
| `collection_file_dialogs.dart` | selects and saves `.irbackup` packages through Windows or Android dialogs |
| `settings_providers.dart` | supplies the platform dialogs and app-level replacement promise to this screen |

The screen may ask storage and app-level contracts to perform work, but it does
not import Drift or write database rows itself. One `OperationId` is created
when a confirmed collection action starts and follows that action downward.
