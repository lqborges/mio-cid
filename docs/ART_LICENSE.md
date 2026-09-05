# Art and license manifest (issue #12 P2)

Only assets that may ship. Dedicated mesh/texture PRs must add a row here before merge.

| Path / id | Kind | License | Notes |
| --- | --- | --- | --- |
| `content/chapters/**/world.tscn` CSG | Original greybox | Repo | Modular kit paints at runtime from `data/art/kits.json` |
| `game/actors/look/humanoid_look.gd` | Original primitives | Repo | Period cloth/mail/veil/crown. Not a Mixamo retarget. |
| `content/art/characters/**` | Original capsules / CSG | Repo | Placeholders until a dedicated art PR |
| `data/look/portraits.json` | Original tunables | Repo | Colors + kit flags only |
| `addons/` Dialogue Manager, gdUnit4, EB Garamond | Third-party | Their tags | Do not bump in passing |

## Denylist (never ship)

Puy du Fou staging/score, Rotating castle, Espadero de Vivar, arrow-in-chest Valencia, flute-Babieca, Jura de Santa Gadea, corpse on the horse, duel with Jimena’s father, holy-war shooter framing, Mixamo placeholder hero in `content/art/` (temp-only under `content/art/_dev/` if ever needed).

## Production art (deferred)

Skinned meshes, 2K textures, and licensed photogrammetry are **not** in this slice. File a dedicated art PR with before/after viewpoints and a profiler capture. Unmeasured hardware is a blocked gate, not a pass.
