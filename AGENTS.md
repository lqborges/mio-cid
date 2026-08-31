# Contributor rules

This file is binding for anyone (human or agent) editing this repository.

## Engine pin

| Item | Value |
| --- | --- |
| Engine | **Godot 4.7.2** (standard / non-.NET). Upgrade only on a dedicated PR. |
| Renderer | **GL Compatibility default** (Intel HD 4000 / Envy 720p30). Forward+ is allowed on Iris Xe / discrete GPU via `--rendering-method forward_plus`. Do not ship Forward+ as the only renderer. |
| Runtime language | **GDScript only** in `game/`. Tools are Python. No C# assemblies. |
| Physics | **Built-in Jolt Physics**. `physics/3d/physics_engine="Jolt Physics"` in `project.godot`. |

Do **not** vendor `godot-jolt`. Do **not** create `addons/jolt/`. The addon only supports Godot 4.3–4.6; 4.7.2 uses the engine module.

## Addon pins

Placeholders live under `addons/` until the listed PR vendors the tag.

| Addon | Git tag | Repo | When |
| --- | --- | --- | --- |
| gdUnit4 | **v6.2.1** | https://github.com/godot-gdunit-labs/gdUnit4 | 4.7-compatible. Not GUT. |
| Dialogue Manager | **v4.0.3** | https://github.com/nathanhoad/godot_dialogue_manager | v4.0.x (Godot 4.6+). Vendor at PR-07. |

Do not bump these tags in passing; pin changes are their own PR.

## Folder contract

`res://` is the repo root.

| Path | Owns |
| --- | --- |
| `game/` | Runtime GDScript |
| `content/` | Art, per-chapter `.dialogue`, locales, audio |
| `data/` | JSON tunables and generated `.tres` (import scripts are the only `.tres` author) |
| `data/schema/` | JSON Schema drafts |
| `tests/` | gdUnit4 tests |
| `tools/` | Python import / lint |
| `addons/gdUnit4/` | Test framework (vendored tag above) |
| `addons/dialogue_manager/` | Dialogue (vendored at PR-07) |

Designers never put numbers in GDScript. Greybox 3D (capsules / CSG) is required until art PRs; Mixamo is temp-only under `content/art/_dev/`.

## Localization

Spanish display strings and VO first. Loc **keys** are English identifiers. Poem formulas live in CSV (`content/locales/`), not hardcoded GDScript.

## Denylist

Public-domain *Cantar de Mio Cid* only. Never ship:

- Puy du Fou assets, staging, or score (including Nathan Stornetta-adjacent music)
- Rotating castle, Espadero de Vivar, arrow-in-chest Valencia
- Flute-Babieca / flute on the horse
- Jura de Santa Gadea
- Corpse on Babieca / dead Cid strapped to the horse
- Duel with Jimena’s father
- Holy-war / Reconquista-shooter framing

If a reference, filename, VO line, or asset smells like the park show or the 1961 film’s corpse-horse, it does not merge.
