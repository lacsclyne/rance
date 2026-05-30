# Design Packet Templates

Use design packets for concept planning before content is ready to become
schema-validated runtime data. They are working documents for faction direction,
adult female character appearance, two card-version intents, art needs, and open
decisions.

Use production JSON in `data/` only after the packet is approved and the final
IDs, names, gameplay values, and references are ready to validate.

## Templates

- [Faction packet](faction-packet.md): plan one faction slot before creating or
  revising `data/factions/factions.json`.
- [Character card packet](character-card-packet.md): plan one adult female
  character and her Version A / Version B card variants before creating or
  revising `data/characters/characters.json` and `data/cards/cards.json`.

## When to Use a Design Packet

Use a packet when:

- The character or faction is still in concept review.
- Appearance, profession markers, silhouette, role, rarity, card intent, or art
  asset IDs are undecided.
- Designers need a copyable format for the MVP roster target of two factions,
  three characters per faction, and two card versions per character.
- The work should not affect runtime loading, validation, balance, or final game
  data yet.

Use production data JSON when:

- Final IDs and names are approved.
- Card types, rarity, cost, target, effects, stats, starter decks, skills, and
  references are ready to pass validation.
- Required asset manifest entries are known or reserved.

## Production Mapping

After approval, map each packet into runtime content deliberately:

| Packet field | Production target |
| --- | --- |
| Faction ID, name, alignment, color, summary | `data/factions/factions.json` |
| Character ID, display name, faction, gameplay role | `data/characters/characters.json` |
| Approved card Version A / Version B IDs, names, type, rarity, target, tags, effect intent | `data/cards/cards.json` |
| Portrait, card art, and faction icon asset IDs | `assets/asset_manifest.json` |
| Final art files | `assets/portraits/`, `assets/card_art/`, `assets/icons/factions/` |

Do not copy planning-only notes into production data unless they are appropriate
for a runtime field such as `summary`, `role`, `bio`, `tags`, or an asset
manifest entry. Adult body and appearance notes are art-direction input, not
gameplay stats.

## Approval Status

Use these status values consistently:

- `Draft`: packet is incomplete or still exploratory.
- `Needs review`: packet is complete enough for design/art review.
- `Approved for production mapping`: final IDs, names, art IDs, and gameplay
  direction can be entered into production data.
- `Deferred`: packet is intentionally not entering the current content pass.
