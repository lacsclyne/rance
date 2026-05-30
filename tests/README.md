# Tests

Automated tests, fixtures, and Godot headless validation helpers live here.

Current headless checks:

```sh
godot --headless --path . --script tests/test_combat_minimal.gd
godot --headless --path . --script tests/test_quest_graph_minimal.gd
godot --headless --path . --script tests/test_save_manager_minimal.gd
godot --headless --path . --script tests/test_campaign_fronts_minimal.gd
godot --headless --path . --script tests/test_resource_registry.gd
godot --headless --path . --script tests/e2e/test_headless_mvp_loop.gd
```

Related local build/export smoke check:

```sh
python tools/dev/validate_build_export.py
```

The E2E smoke test loads the sample content data, builds a minimal collection
and formation, drives a quest battle into a reward choice, and verifies the
settlement summary. It intentionally avoids UI scenes, art assets, campaign-map
front APIs, and balance assertions beyond deterministic fixture outcomes.

See `docs/modules/tests.md`.
