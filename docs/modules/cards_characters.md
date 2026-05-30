# Cards and Characters

## Responsibility

Own card identities, character identities, roster membership, collections, and
the domain rules that bind cards to characters.

## Future Code Paths

- `src/cards_characters/`
- Future content data under `data/cards/` and `data/characters/`

## Key Scene and Resource Paths

- Future card resources: `res://resources/cards/`
- Future character resources: `res://resources/characters/`
- Future roster UI scenes should live under `res://scenes/ui/` and call this
  module through documented APIs.

## Interface Boundaries

- Do not resolve battle timing or damage. Combat consumes card and character
  definitions through stable interfaces.
- Do not own campaign territory, quest flags, save slot format, or UI layout.
- Collection changes that must persist should be expressed as save-system data,
  not written directly to disk here.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/data_definitions.md`
- `docs/modules/combat.md`
- `docs/modules/save_system.md`
- `src/cards_characters/README.md`
