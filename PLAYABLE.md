# Mio Cid — playable slice

This branch (`playable/0e9dbd46-ready`) is the review-clean campaign as of the Valencia hub. It is **not** merged to `main`. Later chapters (embassy 2, Yusuf, lion, Tagus, Corpes) are still in flight on other worktrees.

**Tip commit:** `4820fd8` (Valencia hub + siege review fixes + repay Raquel).

## How to run

### Linux export (no editor)

```bash
./build/linux/mio-cid.x86_64
```

If you received a copy of the export directory, run the same binary from that folder (the `.pck` must sit next to the executable).

GL Compatibility is the shipped renderer (Intel HD 4000 / Envy 720p). On a discrete GPU you can pass:

```bash
./build/linux/mio-cid.x86_64 --rendering-method forward_plus
```

### From Godot 4.7.2

1. Open `project.godot` in **Godot 4.7.2** (standard, not .NET).
2. Physics engine must stay **Jolt Physics** (built-in; no `addons/jolt/`).
3. Press Play. Main scene is `game/ui/main_menu.tscn`.
4. **Nuevo juego** starts at Vivar.

## What is playable (in order)

| Beat | What you get |
| --- | --- |
| Main menu | New game / load / fail-copy |
| `a1_vivar` | Empty solar, first names, plazo |
| `a1_burgos` | Shutters, inn refusal, river camp |
| `a1_arcas` | Sand chests — cheat or refuse (real branch) |
| `a1_cardena` | Jimena / Elvira / Sol, monastery gift, hub lock |
| `a1_navapalos` | Dream of Gabriel; plazo completes and hides |
| `a1_castejon` | Dawn take; sell or Alfonso wrath (keep = game over) |
| `a1_alcocer` | Occupy, wait, sortie vs Fáriz and Galve |
| Booty divide | Quinto / mesnada / treasury; gift-to-Álvar |
| `a1_embassy1` | Gift to Alfonso; `thirty_horses` blocked below 30 |
| `a1_poyo` | Place-name camp; cannot skip Tévar; cannot return to Cardeña |
| `a1_tevar` | Battle, capture, table, Colada in hand |
| `a2_murviedro` | Coastal field take |
| `a2_siege` | Eight siege events on CampaignClock; wall-storm refused |
| `a2_jeronimo` | Valencia hub rooms, Jerónimo, horse named Babieca, locked lion cage |
| `a2_repay_raquel` | Cheat-path only; unreachable if you refused the sand chests |

Spanish display strings. English loc keys. Greybox 3D (CSG / capsules).

## Not in this build

Embassy 2 / Avengalvón road, Yusuf, lion escape, embassy 3, Tagus pardon, Búcar / Tizona, Corpes, Toledo, Pentecost, Steam/Android of *this* slice (an earlier Android debug APK exists on the `pr-android` branch).

The hub’s road to Alfonso (`a2_embassy2`) is not shipped here: the exit whispers and does not graph-hop into a missing scene.

## Controls (foot)

WASD or click-to-move. Run, slam, leap, dodge, shout, interact. Hold mesura / rage dump where that component is present. Horse companion: mount and couch lance on open ground.

## Saves

Local HMAC saves via the menu. New Game resets honor, roster, treasury, clock, chapter flags, and plot swords.
