# `features/occlusion/` — cards made by masking part of a picture

Draw rectangles over an image; each becomes a card that hides that region and asks what is under it. There is no view model: the editor state is the canvas's own, and lifting it out would mean passing every drag through a notifier for no gain.

| File | What it is |
|---|---|
| `occlusion_command_runner.dart` | Transactional creation of scheduled image-occlusion cards |
| `occlusion_commands.dart` | Commands that create scheduled cards from masked image regions |
| `occlusion_providers.dart` | Objects used only by the image-occlusion editor |
| `occlusion_screen.dart` | Screen for drawing masks and creating image-occlusion cards with optional revealed-side Extra content |

## `widgets/`

Pieces of this screen too big to keep in the screen file.

| File | What it is |
|---|---|
| `occlusion_canvas.dart` | Interactive normalized rectangle editor for image occlusion |
| `occlusion_view.dart` | Read-only image rendering with the masks appropriate to one review side |
