# Natural-Language Intake Workflow

Use this workflow when a design or art request starts as prose and needs to
become reviewable Linear issues, JSON content, asset manifest entries, and
validation evidence.

## Flow

1. **Design discussion**
   - Capture the goal, player-facing fantasy, constraints, and what should not
     change.
   - Ask for approval on creative direction, tone, character identity, card
     names, ending meaning, art style, and any balance intent that changes how
     the game should feel.
   - Symphony can normalize wording, identify affected systems, and point to
     the relevant first-read docs without changing files.

2. **Issue splitting**
   - Split the request into small Symphony-ready Linear issues: design packet,
     data/config change, art brief or asset reservation, validation cleanup, and
     review follow-up when needed.
   - User approval is required for the split when it changes scope, defers a
     requested feature, or turns one creative request into multiple releases.
   - Mechanical issue creation, status updates, PR links, and validation notes
     can run unattended.

3. **Content design packet**
   - Write the approved creative choices as a compact packet before editing
     production data: IDs, names, roles, rules, references, acceptance notes,
     and open questions.
   - Use [templates/](templates/) and [../../data/README.md](../../data/README.md)
     as the shape reference for data that already has schemas.
   - If the request needs endings or another content type without a current
     schema/template, create a design/schema issue before adding production
     rows.

4. **Production data JSON**
   - Edit the matching `data/` file only after the packet is clear. Follow
     [README.md](README.md) for ID rules, required fields, and reference fields.
   - Symphony can copy template shapes, rename IDs, update references, and keep
     schema-valid JSON unattended.
   - User approval is required for new canon, new mechanics, final balance
     values, progression gates, reward intent, or ending outcomes.

5. **Art brief and asset manifest**
   - Turn approved visual direction into an art brief with subject, pose,
     composition, mood, palette, constraints, target asset category, and source
     content ID.
   - Reserve or update entries in
     [../../assets/asset_manifest.json](../../assets/asset_manifest.json) using
     the rules in [../../assets/README.md](../../assets/README.md).
   - Placeholder manifest entries may stay `required: false`. Mark an entry
     `required: true` only when the file exists and validation/runtime lookup
     should depend on it.
   - User approval is required for final art direction and final asset choice.
     Symphony can add placeholder-safe manifest rows and keep paths/IDs
     consistent.

6. **Validation report**
   - Attach validation results to the PR or Linear workpad. At minimum, run:

```sh
python tools/dev/validate_content_data.py
python tools/dev/validate_asset_manifest.py
python tools/dev/content_inventory_report.py
git diff --check
```

   - When Godot is available, also run:

```sh
godot --headless --path . --script tools/dev/validate_content_data.gd
```

7. **Godot resource lookup**
   - Runtime/UI code should ask for stable manifest IDs such as
     `portrait.iris` or `card_art.spark_bolt`.
   - The lookup contract lives in
     [../modules/resource_loading.md](../modules/resource_loading.md) and
     `src/resource_loading/resource_registry.gd`; do not hardcode final asset
     paths in gameplay rules.

8. **User review checkpoints**
   - Review before production edits when creative direction, rules, or canon are
     still unsettled.
   - Review before landing when the PR includes new player-facing identity,
     event outcomes, ending logic, final art, or balance that was not already
     approved.
   - Docs-only, schema-valid data reshaping, manifest placeholders, and
     validation-note updates can land unattended when they match the approved
     packet.

## Good Request Shapes

- **Character design:** "Create a playable scout from the Verdant League: quick
  support role, optimistic tone, starts with two mobility cards and one guard
  card, no new combat mechanics, needs a portrait placeholder."
- **Card variants:** "Make three `card.spark_bolt` variants for early/mid/late
  progression. Keep the same status references, vary cost and numeric effect,
  and propose names before editing JSON."
- **Event/ending rules:** "Design an ending for failing to protect the harbor:
  list trigger conditions, required quest/progression IDs, reward consequences,
  and any schema gap before adding data."
- **Art asset request:** "Reserve card art for `card.rally_banner`: heroic
  vertical composition, warm battlefield light, no final binary yet, manifest ID
  `card_art.rally_banner`, placeholder-safe until approved."
