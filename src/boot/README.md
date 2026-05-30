# Boot

Startup orchestration and app lifecycle code live here. See
`docs/modules/boot_config.md`.

## Entry Point

- `res://scenes/boot/main.tscn` is the configured main scene.
- `app_root.gd` is attached to the main scene root and initializes only safe
  technical services.

## Current Services

- `app_config`: local `AppRoot` service pointing at `src/config/app_config.gd`.

No boot autoload is registered yet. Future issues that need global app access
should promote the stable service here rather than registering gameplay systems
from `project.godot`.
