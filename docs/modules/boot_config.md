# Boot and Global Config

## Responsibility

Own project startup, app lifecycle handoff, global configuration defaults, and
future autoload registration.

## Future Code Paths

- `src/boot/`
- `src/config/`
- `project.godot`

## Key Scene and Resource Paths

- `res://scenes/boot/main.tscn`
- Future config resources: `res://resources/config/`

## Interface Boundaries

- Own startup order and project-wide defaults only.
- Do not own save serialization, content schema, battle state, or UI screen
  behavior.
- Other modules may read published config values, but should not mutate boot
  state directly.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `project.godot`
- `scenes/boot/main.tscn`
- `src/boot/README.md`
- `src/config/README.md`
