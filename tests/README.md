# Tests

Automated tests, fixtures, and Godot headless validation helpers live here.

Current headless checks:

```sh
godot --headless --path . --script tests/test_combat_minimal.gd
godot --headless --path . --script tests/test_quest_graph_minimal.gd
godot --headless --path . --script tests/test_campaign_fronts_minimal.gd
godot --headless --path . --script tests/test_resource_registry.gd
```

See `docs/modules/tests.md`.
