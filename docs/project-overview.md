# Project Overview

`rance` is organized as a Godot 4.x project for a long-form grand strategy card
RPG with campaign pressure, collectible character cards, faction progress,
quests, events, endings, growth, carryover, and save support.

This framework issue only establishes project shape and documentation entry
points. It does not implement combat, card effects, strategy rules, story
content, numeric formulas, or art assets.

## Godot Version

- Target engine family: Godot 4.x.
- Project entry: `project.godot`.
- Main scene: `res://scenes/boot/main.tscn`.
- `config_version=5` is used because it is the Godot 4 project format.
- If a later issue pins a specific minor version, update this section and the
  PR validation notes in the same change.

## Directory Conventions

| Path | Purpose |
| --- | --- |
| `project.godot` | Godot project entry and editor-openable configuration. |
| `scenes/` | Godot scenes grouped by feature area. |
| `scenes/boot/main.tscn` | Minimal boot scene used by the project entry. |
| `src/` | GDScript source, grouped by module. |
| `data/` | Versioned content tables and declarative data files. |
| `resources/` | Godot `.tres` or `.res` resources shared by modules. |
| `assets/` | Source media such as art, audio, fonts, and references. |
| `docs/modules/` | Implementation index documents for each module. |
| `docs/requests/` | Preserved historical request notes. |
| `tools/dev/` | Developer-only scripts and editor helpers. |
| `tests/` | Automated tests, fixtures, and headless validation helpers. |

## Module Index

Start at [docs/modules/README.md](modules/README.md), then open the module file
that matches the issue scope.

| Module | Index |
| --- | --- |
| Boot and global config | [boot_config.md](modules/boot_config.md) |
| Data definitions | [data_definitions.md](modules/data_definitions.md) |
| Cards and characters | [cards_characters.md](modules/cards_characters.md) |
| Factions and strategy map | [strategy_map.md](modules/strategy_map.md) |
| Quests, events, and endings | [quests_events_endings.md](modules/quests_events_endings.md) |
| Combat system | [combat.md](modules/combat.md) |
| Growth and run carryover | [progression_carryover.md](modules/progression_carryover.md) |
| Save system | [save_system.md](modules/save_system.md) |
| UI | [ui.md](modules/ui.md) |
| Resource loading | [resource_loading.md](modules/resource_loading.md) |
| Developer tools | [dev_tools.md](modules/dev_tools.md) |
| Tests | [tests.md](modules/tests.md) |

## Naming Rules

- Use `lower_snake_case` for folders, GDScript files, scene files, and data
  files.
- Use `PascalCase` for Godot `class_name` declarations when a later issue adds
  scripts.
- Keep scene names descriptive and module-scoped, such as
  `strategy_map_screen.tscn`.
- Keep data IDs stable, lowercase, and namespaced by module when data schemas
  are introduced.
- Avoid abbreviations unless the abbreviated term is already used in Godot.

## Documentation Rule

When adding a new module or changing a module boundary, update all relevant
index points in the same PR:

- `docs/project-overview.md`
- `docs/modules/README.md`
- The specific `docs/modules/<module>.md` file
- Any README in the new or moved code/resource directory

Later implementation issues should keep their changes inside the documented
module paths unless they explicitly update the affected boundary docs.

## Historical Notes

Earlier planning notes under `docs/requests/` are preserved as project history.
The file `docs/requests/0001-2d-rpg-card-battle-system-outline.md` describes an
older 2D RPG card-battle direction. Use this overview and the module indexes as
the source of truth when that draft conflicts with the current direction.
