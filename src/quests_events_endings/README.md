# Quests, Events, and Endings

Owns quest graph runtime state, event routing, branch choices, chest reward
selection, rest nodes, combat-node handoff, and result settlement summaries. See
`docs/modules/quests_events_endings.md`.

Content fixtures now include minimal `data/events/events.json` and
`data/endings/endings.json` rows. They are schema-validated and indexed by
`ContentDataLoader`, but no runtime event router or ending resolver consumes
them yet.

Current runtime classes:

- `QuestDefinition`: quest graph definition, including a compatibility path
  that synthesizes a minimal event -> combat -> chest -> result graph from
  legacy quest data rows.
- `QuestNode`: node model for `battle`, `elite`, `boss`, `event`, `chest`,
  `rest`, `branch`, and `result`.
- `QuestRunState`: stateful run executor that calls the combat module, tracks
  HP, records chest choices, and emits strategic settlement summaries.
- `RewardPoolDefinition`: weighted 3-choice reward candidate generation.
