# Corpes content rating packet

This is the rater packet copied from the GDD depiction board. **External process:** PEGI 16 submission is owned by the publisher/rating producer, not verified in this repo.

Player is **not** at Robledo. The crime happens off-stage. The player is in Valencia when Félez Muñoz finds Elvira and Sol. Hear-only skips images, not flags. The fact cannot be skipped.

## Depiction board

| Item | Decision |
| --- | --- |
| Violence vs adults | Aftermath only; no impact frames of the crime |
| Sexual violence | **Not depicted.** Text: they were beaten and abandoned. No sexualization, no camera on bodies. |
| Blood | Optional distant dark on leaves in default path; off in hear-only |
| Player agency | Player is not there; cannot intervene; cannot skip the fact |
| Interactable corpses | None |
| Skip | Hear-only skips images, not flags |

## Who is on camera

**Shown:** grove as place, linen, Félez, later Elvira and Sol **alive in Valencia** (cloaks, seated, not speaking much), present at Toledo (veiled, not as speakers) and Pentecost.

**Never shown:** the beating, nudity, wolves at bodies, beauty-shots of injury, player-present combat.

Greybox hall, not a rape depiction. PEGI packet is documentation + warning + hear-only, not graphic 3D.

## Two accessibility branches (fact cannot be skipped)

| | Default | “Hear Félez, do not see” |
| --- | --- | --- |
| Content warning | Yes, before either | Yes |
| Camera | (1) Valencia hall, Cid at the table. (2) Cut: oak grove, **empty**, wind, one strip of torn linen on a branch, no bodies, no blood close-up. (3) Félez’s face. (4) Cut to black. (5) Hall: Félez reports. | Skip (2)–(4). Félez enters the hall and reports. Same VO. |
| Player control | None during cinematic | None during report |
| Flags set | `corpes_happened`, `corpes_news`, `elvira_alive`, `sol_alive`, `felez_found_them` | **Identical** |
| Honor | `corpes_news` (−35 honra) | Same |
| Mesura | After report: choice `mesura_hold` (rage suppressed) vs `corpes_rage_dump` (−12 honra). Red `ride_host` is deferred, not here. | Same |

## Sensitivity-reader checklist

Use this list on the PR and before rating submission.

- [ ] Player is not at Robledo; crime is off-stage
- [ ] Framed as a crime, not a battle
- [ ] Content warning before either path
- [ ] Hear-only path still sets `corpes_news` and plays Félez’s report
- [ ] Fact cannot be skipped
- [ ] No sexualization; no camera on bodies
- [ ] No interactable bodies; no beauty-shots of injury
- [ ] Elvira and Sol are alive in Valencia after the report
- [ ] No Puy du Fou staging, no Santa Gadea, no dead Cid on Babieca
- [ ] Spanish display strings; loc keys in English
