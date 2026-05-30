# Faction Design Packet Template

Copy this file for one faction planning slot. Keep placeholders neutral until
the faction is approved for production data.

## Packet Status

| Field | Value |
| --- | --- |
| Packet owner | `<designer>` |
| Date | `<YYYY-MM-DD>` |
| MVP faction slot | `<faction_slot_1_or_2>` |
| Approval status | `Draft` |
| Review notes link | `<optional link>` |

## Faction Identity

| Field | Value |
| --- | --- |
| Working label | `<working faction label, not final>` |
| Production ID placeholder | `faction.<placeholder_id>` |
| Production name placeholder | `<final name TBD>` |
| Alignment placeholder | `<ally | neutral | enemy | TBD>` |
| Color placeholder | `<#RRGGBB or TBD>` |
| One-line intent | `<neutral faction concept intent>` |

## Visual Direction

| Field | Notes |
| --- | --- |
| Silhouette language | `<large shared shapes, readable symbols, or line language>` |
| Clothing/material motifs | `<materials, uniform cues, or recurring costume details>` |
| Profession/culture markers | `<non-final markers that help distinguish faction members>` |
| Icon direction | `<simple icon concept for faction recognition>` |
| Palette constraints | `<approved colors, avoid list, or TBD>` |

## Gameplay Direction

| Field | Notes |
| --- | --- |
| Faction gameplay role placeholder | `<offense, defense, control, support, economy, hybrid, or TBD>` |
| Card/mechanic keywords under consideration | `<planning-only keywords>` |
| Character roster needs | `<three character slots and rough role spread>` |
| Unresolved gameplay decisions | `<open questions>` |

## Art Asset Placeholders

| Asset | Placeholder ID | Notes |
| --- | --- | --- |
| Faction icon | `faction_icon.<placeholder_id>` | `<manifest status or TBD>` |
| Shared motif reference | `<optional asset_id>` | `<notes>` |

## Production Mapping Checklist

- [ ] Create or update `data/factions/factions.json` only after approval.
- [ ] Replace placeholders with final `faction.*` ID, name, alignment, color,
      and summary.
- [ ] Add or reserve `faction_icon.*` in `assets/asset_manifest.json` when the
      icon asset is known.
- [ ] Keep planning-only notes in this packet unless they belong in production
      `summary` text.
