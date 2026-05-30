# Combat

Runtime combat code lives here and stays independent from UI scenes.

- `combat_state.gd`: AP turn flow, shared team HP, leader action limits, simple
  effect/status resolution, enemy intent preview/resolution, and action logging.
- `combat_command.gd`: small command object for player actions and turn ending.
- `combat_result.gd`: command result and battle outcome summary.
- `status_definition.gd`, `status_instance.gd`, `support_slot.gd`: runtime
  wrappers for data-driven status and support effects.
- `encounter_definition.gd`, `intent_pattern.gd`, `intent_token.gd`,
  `enemy_intent.gd`: scripted encounter intent declarations and runtime preview
  tokens consumed by `combat_state.gd`.

See `docs/modules/combat.md` for the module boundary.
