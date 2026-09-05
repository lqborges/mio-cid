# Playability baseline (issue #12)

Parent: [issue 12](https://github.com/lqborges/mio-cid/issues/12). Play guide stays [#11](https://github.com/lqborges/mio-cid/issues/11).

This document records **what this repo claims**, **what is implemented**, and **what is still unverified**. Visual and performance claims are not a pass until P0 captures exist.

## Engine / hardware (reconciled)

| Item | Source of truth |
| --- | --- |
| Engine | Godot **4.7.2** standard, built-in Jolt, GDScript only (`AGENTS.md`) |
| Default renderer | **GL Compatibility** |
| Current playable floor | Intel HD 4000 / HP Envy, **720p30**. Do not raise this silently. |
| Production-art budget target | GTX 1660-class / 1080p30 once kits replace CSG. Proposed, not measured. |
| Play camera | High three-quarter / isometric, locked (`CidController`). Not TPS orbit. |
| v1 store | Windows + Linux. Android APK and touch HUD are a **test build**, not store scope. |

Older DESIGN wording (GTX 1660 as the only min spec; third-person orbit; human-height tourism camera) was stale against README/AGENTS/`CidController`. DESIGN.md now matches this table.

## Proposed art budget (unmeasured)

Lock these only after P0 profiler routes on the named min-spec PC and a named Android test device.

| Budget | Proposed greybox headroom | Production-art proposal |
| --- | --- | --- |
| Draw calls | CSG + few meshes | Measure before kitbash |
| Visible actors | Player + named mesnada + townsfolk capsules | ≤ 24 skinned in combat |
| Texture memory | Built-in placeholders | 2K cap on min spec |
| Triangles | Greybox boxes | ≤ 1.5M typical chapter |
| Lights | 1 directional | ≤ 4 shadow-casting |
| Particles | Off / tiny | Hero skills + 8 deaths (Low) |

Unavailable hardware is a **blocked gate**, not a CI pass.

## Repeatable profiler routes (run on device)

Record SHA, engine, renderer, device, resolution, input method, quality, peak memory, and frame-time captures (not average FPS alone).

1. **Opening slice:** Vivar solar → gate → Burgos square / inn / river → Arcas choice → Cardeña farewell.
2. **Castejón combat:** dawn take, garrison, keep/sell (sell path), pause, fail-copy keep, load.
3. **HUD / UI:** honor meters, objective bar, pause journal/help/settings, dialogue, choice, touch HUD if the device is a phone.

File reproduced defects as separate issues with captures. Do not treat this checklist as playtest evidence.

## Implemented vs deferred

| Item | Status |
| --- | --- |
| DESIGN/README/PLAYABLE hardware + camera reconciliation | Done (#13) |
| Objective HUD + journal + onboarding + pause Help/Settings | Done (#13) |
| Travel arrival card + Burgos stepped objectives / child-first river | Done (this PR) |
| Autoload preload for ObjectiveCatalog / InputGlyphs / CombatFeel (empty / stale `.godot` class cache) | Done (this PR) |
| HUD locale + meter/plazo tooltips + WASD/E courtyard hint | Done (this PR) |
| Style sheet + license manifest + regional CSG kits | Done (this PR) |
| Foreground occluder fade (locked camera) | Done |
| Combat windup/active/recovery + hit flash + Mesura block copy | Done |
| Horse hold-progress bar | Done |
| P0 screenshots / device captures | **Deferred** — no named min-spec capture yet |
| Production skinned kits / Mixamo-free hero mesh | **Deferred** — dedicated art PRs |
| Formative 4-of-5 player test | **Deferred** — see `tests/playtest/opening_slice.md` |
| Min-spec / Android profiler gates | **Deferred** — unavailable hardware is a blocked gate |

## How to verify in-engine

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/unit/test_objective_catalog.gd
godot --headless --path . -s res://tests/unit/test_player_guide.gd
godot --headless --path . -s res://tests/unit/test_chapter_kit.gd
godot --headless --path . -s res://tests/unit/test_combat_feel.gd
godot --headless --path . -s res://tests/unit/test_a1_vivar.gd
godot --headless --path . -s res://tests/unit/test_a1_burgos.gd
godot --headless --path . -s res://tests/unit/test_early_game_travel.gd
```

If Godot is missing, report those scripts as **unverified**, not as a pass.
