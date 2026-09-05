# Playtest: opening slice (issue #12 P4)

Reproducible scenarios. Record SHA, engine, renderer, device, resolution, and input. A skipped Godot run is **unverified**, not a pass.

## S1 — Vivar to Cardeña without the guide

1. New Game. A travel card says Vivar. Objective bar names Álvar / Martín. Courtyard HUD shows a WASD / E hint and honor-meter labels in the menu language.
2. Move (WASD or tap). First tip dismisses. Prompt reads **Llamar**. Hover the three meters and plazo for a tooltip.
3. Talk to both companions. Ring marks the selected person.
4. Leave by the south gate. Travel card names Burgos. Hear the child (HUD steps to the inn), ask lodging, then camp south. Walking the river first only whispers.
5. Arcas: both choices. Journal must not spoil the other path.
6. Cardeña farewell. Hub lock copy if you try to return.

Pass: 4 of 5 new players finish without an external walkthrough. **Not yet run.**

## S2 — Castejón combat + keep/sell

1. Dawn take. Garrison silhouettes differ from Cid.
2. Hold Mesura: attacks blocked with in-world copy.
3. Sell town. Keep path shows fail-copy and reload last chapter.
4. Pause → Dietario / Ayuda / Ajustes.

## S3 — Horse hold

1. Approach the unnamed destierro horse.
2. Hold interact. Progress bar fills; tap-talk does not mount.
3. Dismount is safe. Charge telegraph stays on couch.

## S4 — Profiler (blocked without hardware)

Run the three routes in `docs/PLAYABILITY.md` on Intel HD 4000 / Envy 720p30 and a named Android test device. Frame-time captures, not average FPS.
