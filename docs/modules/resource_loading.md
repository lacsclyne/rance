# Resource Loading

## Responsibility

Own resource lookup, cache policy, loading paths, and future async loading
services for content and assets.

## Future Code Paths

- `src/resource_loading/`
- `resources/`
- `assets/`

## Key Scene and Resource Paths

- Future loader resources: `res://resources/loaders/`
- Static content roots: `res://data/`, `res://resources/`, and `res://assets/`
- Asset manifest: `res://assets/asset_manifest.json`
- Card art: `res://assets/card_art/`
- Character portraits: `res://assets/portraits/`
- Faction icons: `res://assets/icons/factions/`
- Skill icons: `res://assets/icons/skills/`
- Encounter backgrounds: `res://assets/backgrounds/encounters/`
- UI imagery: `res://assets/ui/`

## Interface Boundaries

- Provides loading services and typed handles; it does not own the meaning of
  loaded gameplay data.
- Should not implement combat, card, quest, strategy, or save rules.
- Modules should avoid direct ad hoc file parsing when a loader contract exists.
- Missing placeholder art is valid until the manifest entry is marked
  `required: true`.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `resources/README.md`
- `assets/README.md`
- `assets/asset_manifest.json`
- `src/resource_loading/README.md`
