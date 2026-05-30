# Progression

Owns player progress state for medals, troop Rank, Rank reward choices,
discovery records, run history, and limited new-run carryover.

Current scripts:

- `progression_state.gd`: aggregate progression state and reward/unlock accessors.
- `run_history.gd`: per-run quest outcome history and first clear/failure records.
- `discovery_log.gd`: first character acquisition and known boss/quest intel.
- `carryover_state.gd`: filtered state allowed to seed a new run.

Content definitions stay under `data/`; these scripts store only player progress
IDs and JSON-friendly save snapshots. See `docs/modules/progression_carryover.md`.
