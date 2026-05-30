# Resource Loading

## Responsibility

Own resource lookup, cache policy, loading paths, and future async loading
services for content and assets.

This module provides stable-ID lookup so gameplay and UI modules can request a
typed resource handle without knowing the final art path.

## Future Code Paths

- `src/resource_loading/`
- `resources/`
- `assets/`

## Key Scene and Resource Paths

- Future loader resources: `res://resources/loaders/`
- Static content roots: `res://data/`, `res://resources/`, and `res://assets/`
- Resource registry script: `res://src/resource_loading/resource_registry.gd`
- Asset manifest: `res://assets/asset_manifest.json`
- Card art: `res://assets/card_art/`
- Character portraits: `res://assets/portraits/`
- Faction icons: `res://assets/icons/factions/`
- Skill icons: `res://assets/icons/skills/`
- Encounter backgrounds: `res://assets/backgrounds/encounters/`
- UI imagery: `res://assets/ui/`

## Registry Contract

`ResourceRegistry` stores lightweight registry entries only. Entries are
registered by:

- stable ID, such as `portrait.guardian`
- resource type, such as `texture`, `audio`, `scene`, `resource`, or `data`
- Godot path, such as `res://assets/portraits/guardian.png`
- optional placeholder path for unresolved final art
- cache policy placeholder, currently `on_demand`, `reuse`, or
  `keep_resident`

Lookup supports exact ID, typed ID, resource type index, and Godot path index.
The registry does not call `load()` or perform async work yet; cache policy is
metadata reserved for a future loader service.

`load_from_asset_manifest()` reads the LAC-28 manifest schema from
`assets/asset_manifest.json`, converts repository-relative asset paths into
`res://` paths, and stores manifest fields such as category, status, required,
and source ID as metadata. It does not define a second manifest format.

Content rows reference manifest entries by stable asset ID fields such as
`portrait_asset_id`, `card_art_asset_id`, `icon_asset_id`, and
`background_asset_id`; they do not store asset file paths.

## Interface Boundaries

- Provides loading services and typed handles; it does not own the meaning of
  loaded gameplay data.
- Should not implement combat, card, quest, strategy, or save rules.
- Modules should avoid direct ad hoc file parsing when a loader contract exists.
- Gameplay modules should depend on stable IDs and expected resource types, not
  on final `res://assets/` or `res://resources/` paths.
- Missing placeholder art is valid until the manifest entry is marked
  `required: true`.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `resources/README.md`
- `assets/README.md`
- `assets/asset_manifest.json`
- `src/resource_loading/README.md`
