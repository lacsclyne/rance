# Project Documentation Hub

Start here for the current documentation map. This file is the stable entry
point for humans and agents who need to find the authoritative first-read doc
for a project concern.

Use [project-overview.md](project-overview.md) for current project direction and
[modules/README.md](modules/README.md) for the module index. Use the ownership
map below to pick the single first-read document for the concern you are
changing.

## Ownership Map

| Concern | First-read document | Primary code/data directories |
| --- | --- | --- |
| Project direction | [project-overview.md](project-overview.md) | `project.godot`, `src/`, `scenes/`, `data/`, `resources/`, `assets/` |
| Godot boot/app config | [modules/boot_config.md](modules/boot_config.md) | `project.godot`, `scenes/boot/`, `src/boot/`, `src/config/`, `resources/config/` |
| Content data | [modules/data_definitions.md](modules/data_definitions.md) | `data/`, `data/schemas/`, `src/data/`, `resources/data/` |
| Art briefs and asset intake | [content-authoring/art-intake-workflow.md](content-authoring/art-intake-workflow.md) | `assets/`, `data/`, `src/resource_loading/` |
| Cards/characters | [modules/cards_characters.md](modules/cards_characters.md) | `src/cards_characters/`, `data/cards/`, `data/characters/`, `resources/cards/`, `resources/characters/` |
| Combat | [modules/combat.md](modules/combat.md) | `src/combat/`, `data/combat/`, `scenes/combat/`, `resources/combat/` |
| Quests/events/endings | [modules/quests_events_endings.md](modules/quests_events_endings.md) | `src/quests_events_endings/`, `data/quests/`, `data/events/`, `data/endings/`, `resources/events/`, `resources/endings/` |
| Strategy map | [modules/strategy_map.md](modules/strategy_map.md) | `src/strategy_map/`, `data/factions/`, `data/strategy_map/`, `scenes/strategy_map/`, `resources/strategy_map/` |
| Progression | [modules/progression_carryover.md](modules/progression_carryover.md) | `src/progression/`, `data/progression/`, `resources/progression/` |
| Save | [modules/save_system.md](modules/save_system.md) | `src/save/`, `resources/save/`, `scenes/ui/` |
| UI | [modules/ui.md](modules/ui.md) | `src/ui/`, `scenes/ui/`, `resources/ui/`, `assets/ui/` |
| Resources/assets | [modules/resource_loading.md](modules/resource_loading.md) | `src/resource_loading/`, `resources/`, `assets/`, `data/` |
| Tools | [modules/dev_tools.md](modules/dev_tools.md) | `tools/`, `tools/dev/`, `tests/fixtures/` |
| Tests | [modules/tests.md](modules/tests.md) | `tests/`, `tools/dev/` |
| CI | [modules/tests.md](modules/tests.md) | `.github/`, `tests/`, `tools/dev/` |
| Design/config/art intake | [content-authoring/intake-workflow.md](content-authoring/intake-workflow.md) | `docs/content-authoring/`, `data/`, `assets/`, `tools/dev/` |
| Content authoring | [content-authoring/README.md](content-authoring/README.md) | `data/`, `data/schemas/`, `tools/dev/`, `src/data/` |

## Update Rule

Any issue that creates a module, moves a module, or changes a module boundary
must update this hub in the same PR or explain in the PR/Linear notes why the
hub did not need a change.

## Historical Context

Files under [requests/](requests/README.md) are historical request notes, not
current source of truth. [design/system-clone-plan.md](design/system-clone-plan.md)
records an earlier data-bootstrap plan and is also historical when it conflicts
with current module docs or [../data/README.md](../data/README.md).
