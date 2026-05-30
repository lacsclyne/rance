# Module Index

Each module document defines the module responsibility, future code paths, key
scene/resource paths, interface boundaries, and first files to read for later
implementation issues.

| Module | Implementation index | Main code path |
| --- | --- | --- |
| Boot and global config | [boot_config.md](boot_config.md) | `src/boot/`, `src/config/` |
| Data definitions | [data_definitions.md](data_definitions.md) | `src/data/` |
| Cards and characters | [cards_characters.md](cards_characters.md) | `src/cards_characters/` |
| Factions and strategy map | [strategy_map.md](strategy_map.md) | `src/strategy_map/` |
| Quests, events, and endings | [quests_events_endings.md](quests_events_endings.md) | `src/quests_events_endings/` |
| Combat system | [combat.md](combat.md) | `src/combat/` |
| Growth and run carryover | [progression_carryover.md](progression_carryover.md) | `src/progression/` |
| Save system | [save_system.md](save_system.md) | `src/save/` |
| UI | [ui.md](ui.md) | `src/ui/` |
| Resource loading | [resource_loading.md](resource_loading.md) | `src/resource_loading/` |
| Developer tools | [dev_tools.md](dev_tools.md) | `tools/dev/` |
| Tests | [tests.md](tests.md) | `tests/` |

## Current Data Contracts

The data-only content foundation lives under `data/`. It provides JSON schemas
and minimal fixture collections for later Godot import, editor tooling, and
gameplay prototype tasks. No runtime data loader is implemented yet.
