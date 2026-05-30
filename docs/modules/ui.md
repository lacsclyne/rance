# UI

## Responsibility

Own screen composition, reusable widgets, input presentation, view models, and
navigation between player-facing surfaces.

## Future Code Paths

- `src/ui/scene_router.gd`
- `src/ui/ui_shell.gd`
- UI scenes under `scenes/ui/`

## Key Scene and Resource Paths

- Shell scene: `res://scenes/ui/shell.tscn`
- Future screen scenes: `res://scenes/ui/`
- Future UI resources: `res://resources/ui/`
- Future source media: `res://assets/ui/`

## Routing Foundation

- `SceneRouter` is a small route registry with deterministic `register`,
  `show`, `current`, and `clear` operations.
- `UIShell` is a neutral `Control` scene with a single `ScreenHost` child for
  future screens.
- The shell deliberately avoids final layout hierarchy, gameplay-specific screen
  composition, fonts, image assets, and decorative styling.

## Interface Boundaries

- UI displays state and sends user intent to domain modules through explicit
  APIs.
- UI does not own campaign simulation, battle rules, save migrations, data
  validation, or content authoring.
- Domain modules should remain testable without UI scenes loaded.
- Router tests run without gameplay state through
  `res://tests/test_ui_router_minimal.gd`.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/boot_config.md`
- `docs/modules/resource_loading.md`
- `src/ui/README.md`
- `scenes/README.md`
