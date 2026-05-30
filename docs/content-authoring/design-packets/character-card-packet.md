# Character Card Design Packet Template

Copy this file for one adult female character and her two card-version concepts.
Keep placeholders neutral until the packet is approved for production data.

## Packet Status

| Field | Value |
| --- | --- |
| Packet owner | `<designer>` |
| Date | `<YYYY-MM-DD>` |
| Faction packet link | `<relative link or TBD>` |
| MVP character slot | `<faction slot 1-2, character slot 1-3>` |
| Approval status | `Draft` |
| Review notes link | `<optional link>` |

## Character Identity

| Field | Value |
| --- | --- |
| Working label | `<working character label, not final>` |
| Production ID placeholder | `character.<placeholder_id>` |
| Production name placeholder | `<final name TBD>` |
| Faction placeholder | `faction.<placeholder_id>` |
| Character gameplay role placeholder | `<frontline, striker, support, control, utility, hybrid, or TBD>` |
| Profession/archetype marker | `<profession marker, not final lore>` |
| One-line design intent | `<neutral role and visual intent>` |

## Adult Female Character Notes

| Field | Notes |
| --- | --- |
| Adult age confirmation | `<adult, 18+; exact age or range TBD>` |
| Body notes | `<non-explicit build, posture, proportions, movement, or ergonomics>` |
| Silhouette | `<primary read at card size>` |
| Face notes | `<expression, facial shape cues, scars, makeup, eyewear, or TBD>` |
| Hair notes | `<style, length, color family, movement, or TBD>` |
| Clothing notes | `<outfit layers, materials, armor, uniform cues, or TBD>` |
| Profession markers | `<tools, accessories, insignia, gestures, or props>` |
| Faction markers | `<colors, symbols, materials, or shared motifs>` |
| Avoid list | `<visual ideas to avoid>` |

## Art Direction

| Asset | Placeholder ID | Notes |
| --- | --- | --- |
| Character portrait | `portrait.<placeholder_id>` | `<portrait art direction or TBD>` |
| Version A card art | `card_art.<placeholder_id>_a` | `<art direction or TBD>` |
| Version B card art | `card_art.<placeholder_id>_b` | `<art direction or TBD>` |
| Additional reference | `<optional asset_id>` | `<notes>` |

## Version A Card Intent

| Field | Value |
| --- | --- |
| Version label | `Version A` |
| Production card ID placeholder | `card.<placeholder_id>_a` |
| Production name placeholder | `<final name TBD>` |
| Card role placeholder | `<starter, signature, upgrade, reward, support, finisher, or TBD>` |
| Rarity placeholder | `<starter | common | uncommon | rare | TBD>` |
| Type/target placeholder | `<attack | skill | power | TBD> / <target TBD>` |
| Gameplay intent | `<what this version should help the player do, no final numbers>` |
| Synergy notes | `<character, faction, or deck hooks under consideration>` |
| Art beat | `<single clear action or pose for card art>` |
| Unresolved decisions | `<open design, balance, naming, or art questions>` |

## Version B Card Intent

| Field | Value |
| --- | --- |
| Version label | `Version B` |
| Production card ID placeholder | `card.<placeholder_id>_b` |
| Production name placeholder | `<final name TBD>` |
| Card role placeholder | `<starter, signature, upgrade, reward, support, finisher, or TBD>` |
| Rarity placeholder | `<starter | common | uncommon | rare | TBD>` |
| Type/target placeholder | `<attack | skill | power | TBD> / <target TBD>` |
| Gameplay intent | `<how this version differs from Version A, no final numbers>` |
| Synergy notes | `<character, faction, or deck hooks under consideration>` |
| Art beat | `<single clear action or pose for card art>` |
| Unresolved decisions | `<open design, balance, naming, or art questions>` |

## Production Mapping Checklist

- [ ] Create or update one `data/characters/characters.json` row only after
      approval.
- [ ] Replace the character placeholders with final `character.*` ID, name,
      `faction_id`, `role`, `base_stats`, `starting_deck`, `skill_ids`, and
      optional `bio`.
- [ ] Create or update the Version A and Version B rows in
      `data/cards/cards.json` only when type, rarity, cost, target, tags, and
      effects are ready to validate.
- [ ] Add or reserve the `portrait.*` and `card_art.*` entries in
      `assets/asset_manifest.json` when final asset IDs and paths are known.
- [ ] Keep appearance notes in this packet unless they are needed for an
      approved production `bio`, card tag, or asset direction note.
