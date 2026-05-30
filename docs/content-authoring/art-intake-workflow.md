# Art Brief and Asset Intake Workflow

Use this workflow when generated or commissioned artwork moves from reference
discussion into `assets/asset_manifest.json` and Godot resource lookup.

The repository stores stable asset IDs and intended paths before final art
exists. Large reference packs, licensed material, and final source binaries
should only be committed when a dedicated issue asks for them.

## Asset Categories

| Category | Asset ID | Source content ID | File path |
| --- | --- | --- | --- |
| `card_art` | `card_art.<card_id_suffix>` | `card.<card_id_suffix>` | `assets/card_art/<card_id_suffix>.<ext>` |
| `portrait` | `portrait.<character_id_suffix>` | `character.<character_id_suffix>` | `assets/portraits/<character_id_suffix>.<ext>` |
| `faction_icon` | `faction_icon.<faction_id_suffix>` | `faction.<faction_id_suffix>` | `assets/icons/factions/<faction_id_suffix>.<ext>` |
| `skill_icon` | `skill_icon.<skill_id_suffix>` | `skill.<skill_id_suffix>` | `assets/icons/skills/<skill_id_suffix>.<ext>` |
| `encounter_background` | `encounter_background.<encounter_id_suffix>` | `encounter.<encounter_id_suffix>` | `assets/backgrounds/encounters/<encounter_id_suffix>.<ext>` |
| `ui` | `ui.<ui_asset_name>` | optional | `assets/ui/<ui_asset_name>.<ext>` |

The ID suffix, `source_id` suffix, and file stem must match. Use lowercase
ASCII letters, numbers, and underscores.

## Art Brief Template

Keep the brief in the art issue, PR description, or commissioning handoff. If a
brief must be committed, put it in docs, not beside the binary asset.

```md
## Art Brief

- Target asset category:
- Asset ID:
- Source content ID:
- Source content notes:
- Visual style:
- Palette:
- Pose/composition:
- Profession markers:
- Simplification rules:
- Negative prompts/avoidance notes:
- Output dimensions:
- File format:
- Status target:
- Reviewer/approval notes:
```

Field expectations:

- `Target asset category`: one of the manifest categories above.
- `Asset ID`: stable lookup ID, such as `card_art.spark_bolt`.
- `Source content ID`: matching data ID, such as `card.spark_bolt`; omit only
  for UI assets that do not represent one data row.
- `Source content notes`: gameplay role, faction, rarity, tags, or biography
  cues pulled from `data/`.
- `Visual style`: rendering style and reference direction.
- `Palette`: dominant colors and any faction or UI color constraints.
- `Pose/composition`: camera angle, silhouette, crop, focal point, and
  foreground/background balance.
- `Profession markers`: job, class, weapon, tool, uniform, faction emblem, or
  other readable identifiers.
- `Simplification rules`: what must stay legible at in-game size and what can
  be reduced or omitted.
- `Negative prompts/avoidance notes`: motifs, anatomy, symbols, text, gore,
  lighting, clutter, or style traits to avoid.
- `Output dimensions`: exact requested pixel dimensions and aspect ratio.
- `File format`: `.png`, `.jpg`, `.jpeg`, `.webp`, `.svg`, `.aseprite`,
  `.kra`, or `.psd`.
- `Status target`: normally `placeholder` before production, `draft` for a
  candidate file, and `final` after approval.

## Status and Naming Flow

The production flow is placeholder -> draft -> approved -> replaced, but the
manifest only accepts these exact `status` values:

- `placeholder`: reserves the asset ID and path. The file may be missing while
  `required` is `false`.
- `draft`: a candidate file exists at the exact manifest `path`, but art
  direction or implementation review is not complete.
- `final`: the asset is approved for the repository. This is the manifest value
  for the human approval state.

Replacement is an event, not a manifest status. To replace an approved asset,
keep the same `id`, `source_id`, and `path` when the image represents the same
content. Set `status` back to `draft` while the replacement is reviewed, then
return it to `final` after approval. Create a new ID only when the source
content ID or asset purpose changes.

Set `required` to `true` only when the file is committed and runtime or content
validation depends on that asset. Keep `placeholder` and speculative draft
entries `required: false`.

## Intake Steps

1. Identify the source content row in `data/`, such as `card.spark_bolt` in
   `data/cards/cards.json` or `character.iris` in
   `data/characters/characters.json`.
2. Choose the manifest category and stable asset ID using the table above.
3. Write the art brief and include the target dimensions, composition, palette,
   profession markers, simplification rules, and avoidance notes.
4. Add or update the entry in `assets/asset_manifest.json`.
5. Put committed files in the exact manifest path for their category. Do not
   commit final art or large source files unless the issue explicitly asks for
   them.
6. Validate the manifest:

```sh
python tools/dev/validate_asset_manifest.py
```

If the source content row changed, also validate content data:

```sh
python tools/dev/validate_content_data.py
```

If Godot is installed, the runtime-facing content validation command is:

```sh
godot --headless --path . --script tools/dev/validate_content_data.gd
```

Always run the repository whitespace check before committing:

```sh
git diff --check
```

## Godot Lookup

Gameplay and UI code should request assets by manifest ID, not by hard-coded
`res://assets/...` paths. `ResourceRegistry.load_from_asset_manifest()` reads
`assets/asset_manifest.json`, converts paths to `res://` paths, and stores
manifest metadata.

```gdscript
var registry := ResourceRegistry.new()
var result := registry.load_from_asset_manifest()
if result["ok"] and registry.has_resource("portrait.iris", ResourceRegistry.TYPE_TEXTURE):
	var portrait_path := registry.get_path("portrait.iris", ResourceRegistry.TYPE_TEXTURE)
```

Loader or UI code may then pass the returned path to the appropriate texture
loading path. The caller keeps the stable asset ID in gameplay-facing code.

## Example: Card Art Brief

```md
## Art Brief

- Target asset category: `card_art`
- Asset ID: `card_art.spark_bolt`
- Source content ID: `card.spark_bolt`
- Source content notes: Common attack card, cost 1, arcane tag, damage plus
  bleed status.
- Visual style: Painterly tactical card illustration with crisp silhouette and
  readable spell effect.
- Palette: Electric blue and white sparks over a muted warm battlefield accent.
- Pose/composition: Diagonal bolt crossing from lower left to upper right, with
  a small caster hand silhouette only if it stays secondary to the spell.
- Profession markers: Arcane caster cue through a rune ring or gloved casting
  hand; no specific character likeness.
- Simplification rules: Must read as a lightning attack at card thumbnail size;
  avoid small runes that become noise.
- Negative prompts/avoidance notes: No text, UI frame, gore, firearm, sci-fi
  machinery, photorealism, or crowded background.
- Output dimensions: 768x1024 px, portrait card-art crop.
- File format: `.png`
- Status target: `draft`
- Reviewer/approval notes: Check that the effect reads as arcane damage, not a
  healing or frost effect.
```

Manifest entry:

```json
{
  "id": "card_art.spark_bolt",
  "category": "card_art",
  "path": "assets/card_art/spark_bolt.png",
  "required": false,
  "status": "draft",
  "source_id": "card.spark_bolt"
}
```

## Example: Portrait Brief

```md
## Art Brief

- Target asset category: `portrait`
- Asset ID: `portrait.iris`
- Source content ID: `character.iris`
- Source content notes: Liberation Front guardian and front-line captain with
  high defense, shield wall, and command aura skills.
- Visual style: Clean painted character portrait suitable for dialogue and
  party roster UI.
- Palette: Liberation Front colors, sturdy steel neutrals, and a restrained
  warm leadership accent.
- Pose/composition: Bust portrait, three-quarter view, upright posture, shield
  edge or captain insignia visible near the shoulder.
- Profession markers: Guardian armor, captain badge, practical shield detail,
  calm command expression.
- Simplification rules: Face, role silhouette, and faction marker must stay
  readable at small UI size; armor engravings can be simplified.
- Negative prompts/avoidance notes: No modern military gear, exposed gore,
  exaggerated fantasy spikes, text, logo lockups, or overbusy background.
- Output dimensions: 1024x1024 px, square portrait crop.
- File format: `.png`
- Status target: `draft`
- Reviewer/approval notes: Check that Iris reads as defensive leadership rather
  than a rogue or caster.
```

Manifest entry:

```json
{
  "id": "portrait.iris",
  "category": "portrait",
  "path": "assets/portraits/iris.png",
  "required": false,
  "status": "draft",
  "source_id": "character.iris"
}
```
