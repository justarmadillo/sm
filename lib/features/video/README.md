# `features/video/` — processing one range of a video

A video is a URL plus timestamps. It is played by whatever the platform already uses, never embedded and never through a host API, so no part of the app depends on another company keeping its player working.

The screen is deliberately shaped like the Extract screen: a range is processed the same way a passage is — open it, mark where you got to, cut what is worth keeping, then Done or Later.

| File | What it is |
|---|---|
| `import_video_sheet.dart` | Adding a video: its link, title, duration, and optional thumbnail |
| `video_clip_dialog.dart` | Cutting a clip: two times and what you want to remember about them |
| `video_command_runner.dart` | Runs every command that creates or changes a video or a range over one |
| `video_commands.dart` | Every request that creates or changes a video or a range over one |
| `video_providers.dart` | The objects the Video screen and its dialogs need |
| `video_screen.dart` | Processing surface for one range of a video |
| `video_view_model.dart` | ViewModel for processing one range of a video |
