# Resources

Reserved for reusable Godot resources such as `.tres` and `.res` files.
Keep module-specific resources aligned with the matching docs in `docs/modules/`.

Reusable runtime resources should be registered by stable ID through
`src/resource_loading/resource_registry.gd` when gameplay or UI code needs to
look them up. The registry records type, Godot path, optional placeholder path,
and cache policy metadata without loading large resources during tests.
