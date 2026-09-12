# `features/custom_study/` — ad-hoc study by inherited tag

This screen reads a deterministic filtered population and delegates every
write to the existing study screens. It never invokes daily admission or queue
randomization.

| File | What it is |
|---|---|
| `custom_study_query.dart` | Read-only inherited-tag population and deterministic ordering |
| `custom_study_view_model.dart` | Filter state, frozen matches, and session progress |
| `custom_study_screen.dart` | Filter controls, match rows, and the study route loop |
| `custom_study_providers.dart` | Objects built once for this screen |
