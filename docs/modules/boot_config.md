# Boot and Global Config

## Responsibility

Own project startup, app lifecycle handoff, global configuration defaults, and
future autoload registration.

## Future Code Paths

- `src/boot/app_root.gd`
- `src/config/app_config.gd`
- `project.godot`
- `default_bus_layout.tres`

## Key Scene and Resource Paths

- `res://scenes/boot/main.tscn`
- `res://src/boot/app_root.gd`
- `res://src/config/app_config.gd`
- `res://default_bus_layout.tres`
- Future config resources: `res://resources/config/`

## Current Baseline

- `project.godot` owns the application name/version, boot scene, viewport size,
  stretch mode/aspect, placeholder input actions, renderer, and default audio
  bus layout path.
- `scenes/boot/main.tscn` instantiates `AppRoot` as the main scene root.
- `AppRoot` initializes only safe technical services and registers `app_config`
  in its local service registry.
- `AppConfig` mirrors the project-level constants that other modules may read
  without mutating startup state.
- No autoload is registered yet. If a later issue needs global access, promote
  only stable technical services from `AppRoot` or `AppConfig`.

## Interface Boundaries

- Own startup order and project-wide defaults only.
- Do not own save serialization, content schema, battle state, or UI screen
  behavior.
- Other modules may read published config values, but should not mutate boot
  state directly.
- Boot must not start gameplay, campaign simulation, save flows, or final UI.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `project.godot`
- `scenes/boot/main.tscn`
- `src/boot/app_root.gd`
- `src/config/app_config.gd`
- `src/boot/README.md`
- `src/config/README.md`
