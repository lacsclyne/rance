# Scenes

Godot scenes live here, grouped by module. The only committed scene for this
initial framework is `scenes/boot/main.tscn`, which exists so the editor can
open and run the project without temporary gameplay logic.

## UI

- `scenes/ui/shell.tscn`: neutral UI shell with a single `ScreenHost` child.
  It is scripted by `res://src/ui/ui_shell.gd` and uses
  `res://src/ui/scene_router.gd` for route registration, screen replacement,
  current route lookup, and clearing.

The UI shell is not the project root scene and does not define final screen
composition or styling.
