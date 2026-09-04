# Style sheet (issue #12 P2)

Approved greybox identity until dedicated mesh/texture art PRs replace CSG. Numbers live in `data/art/kits.json`.

## Silhouette

| Who | Read from isometric | Kit flags (`data/look/portraits.json`) |
| --- | --- | --- |
| Cid | Beard, mail, crimson cloak, kettle-scale pauldrons | `knight` + beard/mail/cloak |
| Álvar | Teal cloak, shorter beard | `knight` |
| Martín | No cloak, moss cloth | `knight` |
| Jimena / daughters | Veil + robe, no mail | `lady` |
| Townsfolk | Cloth only, no metal | `host` |
| Garrison | Leather + kettle, no cloak | `enemy` role `garrison` |
| Captain | Broader scale, darker cloth | `enemy` role `captain` |

Scale stays human: ~1.7–1.9 m capsules. Do not grow bosses.

## Palette (regional)

| Region | Earth | Stone | Wood | Accent | Sky |
| --- | --- | --- | --- | --- | --- |
| Castile (Vivar / Burgos) | wet earth | limestone | oak | iron | cool grey-blue |
| River camp (Arcas) | damp silt | river stone | weathered oak | linen | overcast |
| Cardeña | cypress shade | ochre plaster | dark oak | candle | dusk amber |
| Frontier (Castejón) | dry ochre | baked wall | scrub oak | rust | harsh pale |
| Tévar / Poyo | pine duff | granite | pine | moss | pine-shadow |
| Valencia | huerta soil | ceramic white | citrus wood | glaze blue | bright haze |
| Toledo | packed court | pale ashlar | walnut | seal gold | high cool |
| Corpes | muted earth | bare timber | grey oak | none | low overcast |

Hue is secondary. Shape + value carry identity (same rule as honor meters).

## Materials / lighting

- GL Compatibility only. One directional sun. No SDFGI, SSR, SSAO, glow, volumetric fog.
- CSG roughness 0.85–1.0. Unshaded only for HUD rings and nameplates.
- Contact: sun energy and ambient from the kit; MobileLook may lift phones, not desktop Envy.

## UI typography

- Iron panel `Color(0.18, 0.16, 0.13, 0.92)`, parchment `Color(0.91, 0.85, 0.72)`.
- Objective title 16, detail 13, toast 18/14, subtitles from settings (default 18).
- Meters: chest / seal / beard shapes; hatch / dots / chevron. Do not distinguish onores / honor / honra by hue alone.

## Camera

High three-quarter, locked. Foreground roofs/walls fade when they hide Cid. No orbit, no tourism drone.

## Provenance

Original CSG + Godot primitives + EB Garamond (already vendored). See [ART_LICENSE.md](ART_LICENSE.md). No Mixamo hero, no park/film stills.
