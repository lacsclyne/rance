# Combat

Runtime combat code lives here and stays independent from UI scenes.

- `combat_state.gd`: AP turn flow, shared team HP, leader action limits, simple
  effect resolution, and action logging.
- `combat_command.gd`: small command object for player actions and turn ending.
- `combat_result.gd`: command result and battle outcome summary.

See `docs/modules/combat.md` for the module boundary.
