# UI

Reusable UI controllers and screen-level presentation code live here. See
`docs/modules/ui.md`.

## Routing Entry Points

- `scene_router.gd`: deterministic route registry and current-screen host
  manager with `register`, `show`, `current`, and `clear` operations.
- `ui_shell.gd`: thin scene script for `res://scenes/ui/shell.tscn`; exposes
  `register_screen`, `show_screen`, `current`, and `clear_screen`.
- `quest_vertical_slice.gd`: first playable UI slice that presents strategy,
  quest, formation, combat, reward, and settlement screens over the sample
  content fixtures.

The router owns only screen instantiation and host replacement. Gameplay state,
screen layout decisions, final copy, fonts, and visual styling stay outside this
foundation.
