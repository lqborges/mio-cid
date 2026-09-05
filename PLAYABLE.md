# Mio Cid — playable slice

`main` is the review-clean three-cantar campaign through Pentecost.

**Tip:** Vivar through Tagus, marriages, lion, Búcar / Tizona, Corpes, querella, Cortes de Toledo, three-week wait, spectator lists, Pentecost credits.

In-game: the top bar is the current objective. Pause → **Dietario** / **Ayuda** / **Ajustes**. Ayuda replays the opening tips (move, talk, dismiss, choice, held Mesura). Chapters use regional CSG kits ([docs/STYLE_SHEET.md](docs/STYLE_SHEET.md)). Hold-interact fills a mount bar; Mesura names why attacks are blocked. See [docs/PLAYABILITY.md](docs/PLAYABILITY.md) and issue #12. The external walkthrough stays issue #11.

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
4. **Nuevo juego** starts at Vivar. WASD walks; **E** talks. Menu language also labels the honor meters and plazo bar.

If the Output dock reports parse errors for `ObjectiveCatalog`, `InputGlyphs`, or `CombatFeel` after a pull, the scripts are present — regenerate the gitignored class cache:

```bash
godot --headless --path . --import
```

That rewrites `.godot/global_script_class_cache.cfg`. Autoloads also preload those three scripts so an empty `.godot` is less likely to drop WASD / E / pause.

## What is playable (in order)

| Beat | What you get |
| --- | --- |
| Main menu | New game / load / fail-copy |
| `a1_vivar` | Empty solar, first names, plazo |
| `a1_burgos` | Hear the child, ask the inn, then camp south. A travel card names the next place. Walking the river early only whispers — the child verse must land first. |
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
| `a2_embassy2` | Medinaceli road; recruit Avengalvón; second gift to Alfonso; family returns |
| `a2_yusuf` | Day 1 huerta field (not a wall climb); day 2 one charge + resolve |
| `a2_embassy3` | Third gift; pardon whisper; exit toward Tagus or repay |
| `a2_repay_raquel` | Cheat-path only; unreachable if you refused the sand chests |
| `a2_tagus` | Three-day court; Alfonso's pardon; forced yes to the marriages |
| `a2_bodas` | Infantes in Valencia; train/gift; cage still locked |
| `a3_leon` | Lion joke; mesura or rage to return it; no kill |
| `a3_bucar` | Shore battle; Infantes flee; Tizona in hand |
| `a3_despedida` | Swords gifted; Elvira and Sol leave; Avengalvón lives |
| `a3_corpes` | Off-stage crime; Félez report; content warning; hear-only skips grove not fact |
| `a3_querella` | One-ask SpeechTrial; legal/mesura files the complaint; ride_host does not unlock Toledo |
| `a3_toledo` | García first, then swords / dowry / riepto. Tizona to Pero, Colada to Martín |
| `a3_valencia_wait` | Three weeks on `lists_wait`. Jimena rest. No mouth-cost |
| `a3_carrion` | Spectator lists. Cid is not a hurtbox and not possessable. One shout per duel |
| `a3_pentecost` | Poem ending and credits. He dies. **No corpse on Babieca** |

Spanish display strings. English loc keys. Greybox 3D (CSG / capsules).

## Controls (foot)

WASD or click-to-move. Run, slam, leap, dodge, shout, interact. Hold mesura / rage dump where that component is present. Horse companion: mount and couch lance on open ground. At Carrión you watch; you do not enter the lists.

## Saves

Local HMAC saves via the menu. New Game resets honor, roster, treasury, clock, chapter flags, plot swords, and the lists seed.
