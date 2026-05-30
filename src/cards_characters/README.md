# Cards and Characters

Owns pure card collection, faction squad, leader slot, and formation domain
models. These scripts consume validated content indexes from
`ContentDataLoader` and do not parse data files directly.

Core runtime scripts:

- `card_instance.gd`: owned character-card instance state, duplicate level, and
  training points.
- `collection_state.gd`: owned card collection and faction AT/HP aggregation.
- `faction_squad_state.gd`: faction power snapshot with leader corrections.
- `leader_slot.gd`: frontline leader assignment and leader skill exposure.
- `formation_state.gd`: shared party HP, leader skills, and progression-ready
  frontline slot count.

Headless validation:

```sh
godot --headless --path . --script tests/cards_characters_domain_test.gd
```
