# Growth and Run Carryover

## Responsibility

Own character growth, rewards, unlocks, run completion summaries, and
new-run carryover contracts.

## Future Code Paths

- `src/progression/`
- Future content data under `data/progression/`

## Key Scene and Resource Paths

- Future progression resources: `res://resources/progression/`
- Future reward UI scenes should live under `res://scenes/ui/`

## Interface Boundaries

- Consumes battle, quest, ending, and strategy outcomes.
- Publishes durable unlock and growth state to the save system.
- Does not own save file format, battle resolution, card effect execution, or
  quest branch evaluation.

## First Reads for Follow-up Issues

- `docs/project-overview.md`
- `docs/modules/cards_characters.md`
- `docs/modules/combat.md`
- `docs/modules/save_system.md`
- `src/progression/README.md`
