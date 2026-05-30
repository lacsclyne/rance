# Assets

Reserved for source media such as art, audio, fonts, and UI reference files.
Do not add large binary assets or licensed material without a dedicated issue.

Runtime code should resolve asset paths through
`src/resource_loading/resource_registry.gd` once a stable ID is available.
Until the asset manifest schema lands, use the in-memory registry contract and
optional placeholder paths instead of hardcoding final art paths in gameplay or
UI modules.
