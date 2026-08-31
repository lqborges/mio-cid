# Mio Cid

Greenfield Godot 4 campaign from the public-domain *Cantar de Mio Cid*. Design source of truth: [docs/DESIGN.md](docs/DESIGN.md). Short pointer: [docs/gdd.md](docs/gdd.md).

Not Puy du Fou. Not the 1961 film. See [AGENTS.md](AGENTS.md) for engine pins and the IP denylist.

## Open in Godot 4.7.2

1. Install **Godot 4.7.2** (standard build, not .NET) from the [4.7.2-stable archive](https://godotengine.org/download/archive/4.7.2-stable/).
2. Open the Godot Project Manager → **Import**.
3. Select this repository’s `project.godot` (repo root).
4. Confirm **Project Settings → Physics → 3D → Physics Engine** is `Jolt Physics`.
5. Default renderer is **GL Compatibility** so Intel HD 4000 boots. On Iris Xe or a discrete GPU you can pass `--rendering-method forward_plus`.

Do not install the `godot-jolt` addon. Jolt is built into 4.7.2. The greybox arena is `content/chapters/_dev/arena.tscn` (high 3/4 isometric, not over-the-shoulder).

## Layout

| Path | Role |
| --- | --- |
| `game/` | Runtime GDScript |
| `content/` | Art, dialogue, locales, audio |
| `data/schema/` | JSON Schema for tunables |
| `tests/` | gdUnit4 |
| `tools/` | Python |
| `addons/gdUnit4/` | Test framework (pin in AGENTS.md) |
| `addons/dialogue_manager/` | Dialogue Manager 4.x (pin in AGENTS.md; vendor at PR-07) |

## Tests

GitHub Actions workflow `.github/workflows/import-and-test.yml` runs headless `godot --import` and gdUnit4 when a Godot 4.7.2 binary is available. If the binary is missing from the CI cache, the job skips those steps and still succeeds.

## License

Code is MIT. See [LICENSE](LICENSE).
