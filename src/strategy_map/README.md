# Strategy Map

Owns faction progress, regions, fronts, and long campaign pressure code.
See `docs/modules/strategy_map.md`.

Current runtime entry points:

- `campaign_state.gd`: strategic turn state, available quest listing, settlement consumption, and no-UI simulation.
- `front_state.gd`: per-front pressure, enemy strength, quest availability, and long-term modifiers.
- `strategic_action.gd`: quest action metadata for strategic pressure results.
