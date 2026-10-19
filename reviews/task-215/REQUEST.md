# Task 215 — the lighting: a late-autumn morning, with one owner

Task: 215
Round: 2
Base: `120ce75` (main, the merge of #196)
Code commit: `e27bdb88ef1ae1ae6773763ab16a379d752817f3`

```
[harness] PASS: 33/33 checks @ e27bdb88ef1ae1ae6773763ab16a379d752817f3 (clean tree) scope=all
```

`[harness2]`: **N/A.** Not one path this task touches is in `TWO_PLAYER_PATHS`
(`tools/agents.py`): `src/server/Light/`, `src/server/LightBoot.server.luau`,
`src/shared/Flags/`, `src/shared/Lobby/`, `src/client/Hud/Style.luau`,
`src/client/Hud/init.luau`, `tools/studio_mcp.py`, `tests/server/light.spec.luau`,
`tests/client/hud_style.spec.luau`. The light looks the same to one player as to two.

## What changed

`Lighting` was place content nobody owned. `ServerScriptService.Light` is now its one writer, in
every world, from one frozen table that is the Designer's lighting spec, 2026-10-19, with the whole
look behind `AUTUMN_LIGHT` (born **ON**). Plus the spec's three lodge lamp numbers and, on the
Director's instruction, `Style.SLATE_T` 0.18 -> 0.14.

## Claims

1. **There is exactly one writer of `Lighting`, and it runs in every world.** `Light.apply` is the
   only function in the repo that touches the service; `LightBoot` is its only caller and has no
   `Map.EXPECTED_WORLD` guard, unlike `ArenaBoot` / `MatchBoot` / `ForestTestBoot`.
   *Verify:* `grep -rn "Lighting\." src/ tests/` and look at what is on the left of each `=`. Seven
   files MENTION `Lighting` and did before this commit — `src/shared/Horn/init.luau`,
   `src/shared/Shotgun/init.luau`, `src/server/Boar/init.luau`, `src/server/Match/Body.luau`,
   `src/server/Match/Scene.luau`, `src/client/Camera/Viewmodel.luau`,
   `src/client/Hud/ShopPanel.luau` — and **every one of them is a COMMENT reasoning about the
   ambient, not a write** (round 1 note (g) corrected this recipe; the claim it was meant to check
   is unchanged). The only assignment to the service or its children in the repo is `Light.apply`'s
   guarded `set`. `Light` never names `PointLight`, `SpotLight`, `Fire`, `Beam` or `Sky`: the
   lodge's six lamps stay `Lobby.Build`'s.

2. **`AUTUMN_LIGHT` is born ON by the DIRECTOR'S decision, and the repo now says so** (round 1,
   finding 1 — the only blocking one). `docs/design/feature-flags.md` section 11 step 1 births a new
   path `false`; the dispatch overrode it in those words, and they were outside the repo, so the row
   carried only the Builder's reasoning. The dispatch is now transcribed **verbatim** in `TASKS.md`
   row **215d** (marked as the Director's, which CLAUDE.md lets the Builder do for a dispatch that
   arrived outside the repo) and quoted in the `AUTUMN_LIGHT` row and in `Light`'s own comment. The
   default is unchanged — ON, as dispatched — and nothing in the tests depends on it: every
   `light.spec` case drives `plan` / `apply` by parameter.
   **`Flags.MAX_FLAGS` 13 -> 14 is a DIFFERENT Director call** (section 12) that the dispatch does
   not name; that line now says so and is queued as `TASKS.md` 215a item (a). Eight dark paths, under
   the twelve the cap is about.
   *Verify:* `TASKS.md` row 215d, the `AUTUMN_LIGHT` row's comment, `Flags.MAX_FLAGS`'s comment.

3. **The flag is read once, at the owner's boundary, and OFF means NOT WRITTEN.** `Light.ENABLED`
   is the only `Flags.isOn` call; it is passed inward as `Light.plan`'s first argument, and
   `plan(false, ...)` returns **nil**, so `apply` is never reached. Refused in the note (section 4):
   a restore-from-snapshot off-switch, because a snapshot taken after something else has written is
   a snapshot of the wrong thing.
   *Verify:* `light.spec` -> "the flag boundary is pure, and OFF means nothing is written".
   **And live, in the Forest Test with `DHFlag_AUTUMN_LIGHT=false`:** the place came back at its own
   `Amb=159,159,159 Out=125,155,200 B=3.00 CT=15.00 Lat=54.0 Exp=0.00 EDS=0.00`, `SunRays=true`,
   `DepthOfField=true`, `Blur=true` — untouched (`<runs-dir>/t215/cameras.json`, key `live_before`).

4. **`apply` adopts, never duplicates, and never throws.** It takes the first child of each class
   that is there and creates one only when there is none; it never creates a `SunRaysEffect`,
   `BlurEffect` or `DepthOfFieldEffect` (`create = false`), only switches one off; a second instance
   of an owned class is **reported and not touched**; every write is guarded and a refusal is
   counted, not raised.
   *Verify:* `light.spec` -> "apply adopts, never duplicates, and never throws" (five cases, each on
   a parentless `Folder`, so no case touches the real service). **Live, and the two places differ
   exactly as they should:** the Forest Test has all six classes, so its line reads
   `30 property(ies) written ... adopted=Atmosphere,ColorCorrectionEffect,BloomEffect,SunRaysEffect,BlurEffect,DepthOfFieldEffect`;
   DEV has no `BlurEffect`, so its line reads 29 written, five adopted and `absent=BlurEffect`
   (round 1 note (g) — the round-1 request printed the Forest Test's line for both). **Nothing is
   created in either place**, which is the half of the claim that matters.

5. **The numbers are the Designer's, and three deviations are named.** `Light.CONFIG` carries every
   value of the spec's §1, §3 and §4, asserted one by one.
   (a) **`Technology` is not written** — this engine refuses even to *read* it from a script
   (*"lacking capability RobloxScript"*, probed 2026-10-19), so the `ShadowMap` row is a comment.
   (b) **`SunRays` (spec §4: not used), `Blur` and `DepthOfField` are switched off** — the Forest
   Test was running all three, and the spec never saw the last two.
   (c) **Fog is left alone**, as the spec asks.
   *Verify:* `light.spec` -> "carries the exact numbers of the lighting spec, 2026-10-19",
   "never names Technology...", "never names the fog...".

6. **A boar stays visible in shade, checked twice: on the spec's own arithmetic, and on pixels.**
   *The arithmetic, re-derived rather than quoted:* BT.601 reproduces §2's boar (72) and dirt (47)
   to the digit, and its GRASS row does **not** — `112,124,72` under `OutdoorAmbient` renders luma
   **51.0, not the 45 printed**, so the spec's advertised 1.6 : 1 is really **1.43 : 1**. The spec
   is not patched; `light.spec` records the corrected figure as a number so nobody derives it twice.
   *The pixels, same camera, same staged boar on the same shaded grass, the flag the only
   difference:* boar luma **5.2** on grass **15.3** after; **39.4** on **53.9** before — the boar
   separates from its ground **2.91 : 1 after against 1.37 : 1 before**.
   **The dispatch's "ratio >= 1.5" cannot be met as literally written and never could be:** the real
   boar's mesh is DARKER than grass, so it was 0.73 : 1 before this task touched anything. Read as
   separation — brighter over darker, which is what `Light.ratio` computes and what a hunter
   actually reads off a silhouette — it is 2.91 : 1 and better than before.
   *Verify:* `light.spec` -> "a boar stays visible in shade" (five cases); and
   `<runs-dir>/t215/measure.py` against `after-C-boar-in-shade.png` / `before-C-...` /
   `pair-C-boar-in-shade.png`, with the sample boxes drawn on the frame and looked at.

7. **The spec's own rescue knob was tried live and makes things worse, so the numbers ship as
   written.** Five variants at one camera on one staged boar (`<runs-dir>/t215/knobs.py`):
   as-written boar 5.2 / sep **2.91**; `Ambient`->54,49,43 (the spec's §2 knob) 5.8 / sep 2.65;
   `Contrast` 0.10 -> 9.8 / sep 2.06; both -> 8.9 / 2.27; `Ambient` 70,64,56 + `Contrast` 0.12 ->
   7.6 / 2.47. The spec's values have the best separation of the five.
   *Verify:* `<runs-dir>/t215/knob-*.png`, five frames, looked at.

8. **The slate moved to 0.14 on the Director's instruction and the measurement did NOT ask for it.**
   Spec §6 makes the change conditional on the sky measuring brighter than `#B4CFE4`. Measured over
   82,945 real sky pixels in two Forest Test frames: with the flag on the brightest sky is
   **`#94B9D3` (luma 176.9)**, DARKER than `#B4CFE4` (201.3) and darker than the same frames with
   the flag off (`#ACBECC`, 186.2). It is kept because it is strictly safer: over §2's own tested
   ground the tightest colour, `BLAZE_HI`, goes **4.66 : 1 -> 5.18 : 1**, and every other colour
   gains. Reverting it is one line in `Style.luau` plus one in `hud_style.spec`.
   *Verify:* `Style.SLATE_T`'s comment, `hud_style.spec` -> "keeps the four over-the-world
   opacities...", and `<runs-dir>/t215/measure.py` (its 4.66 reproduces `Style.luau`'s own recorded
   figure, which is the check that the arithmetic is right).

9. **The cost, measured at one fixed camera, 8 s of `RenderStepped` each.** With the flag on:
   **26.3 ms mean (38.0 fps)**; off: **23.3 ms (42.8 fps)**. **+3.0 ms**, against the spec's
   predicted +0.55. Measured once per pass on a Studio Play session, so it carries Studio's own
   noise — the worst frame moved 42.5 -> 77.0 ms. **Not verified as a phone figure**, and §8's first
   cut if it matters is `Bloom`.
   *Verify:* `<runs-dir>/t215/cameras.json`, keys `frame_after` / `frame_before`.

10. **The four scenes, before and after at identical cameras, looked at.** Lodge from the door;
    the boar on the stone; a stand on the line; the forest as a beater. `<runs-dir>/t215/pair-*.png`.
    **Smoke PASS (rule A), on the round-1 code (unchanged outside two comment blocks and a
    `MAX_FLAGS` comment since):** `lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0
    errorLines=0 | waves=9`, and `[LightBoot] AUTUMN_LIGHT is on: 30 property(ies) written...` in
    that same console. `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both pass
    (rule G).

## What I could not verify

* **The frame cost is a Studio number, not a phone number.** +3.0 ms is measured, but on one
  machine, once per pass, inside Studio Play; the spec's per-item phone budget (0.1 / 0.05 / 0.4 ms)
  is the Designer's and is **not** confirmed here. I did not isolate which of `Atmosphere`, the
  grade and `Bloom` costs what.
* **The spec's §7 promise that lit grass "loses its summer lime and goes dry ochre" does not happen,
  and cannot from this change.** `ColorCorrectionEffect` has no hue control, and the grass is lime
  because its ALBEDO is (the terrain's `MaterialColors`, the map's property, not the light's). The
  beater frame still shows summer-green grass. Raising saturation makes it MORE lime, not less.
* **Whether this is the right darkness is Karen's call, not a measurement.** The deep-shade boar
  renders at luma 5.2 — readable as a silhouette (I looked at five frames of it), separating
  2.9 : 1 from its grass, but dark in absolute terms. `python tools/flags.py set AUTUMN_LIGHT off`
  is the switch, and in the Forest Test it is `DHFlag_AUTUMN_LIGHT` on that place's own
  `ServerStorage`, because `flags.py` writes DEV's.
* **The seven round-1 notes are queued as `TASKS.md` row 215a**, not fixed here, per CLAUDE.md step
  5. Two of them were factual errors in the round-1 request itself and ARE corrected above (claims 1
  and 4's verify recipes), because a request has to be true.
* **A harness fault, reported (rule 6).** Three times during this task the DEV Studio's StudioMCP
  connection dropped for a few seconds and an unscoped call fell through to the **Forest Test**
  window while the banner still printed *"defaults to Driven Hunt DEV (placeId: 136410205938347)"*.
  The run that did it failed correctly — `FAIL Studio has the DEV place open (130094961655666 vs
  136410205938347)` — so nothing ran in the wrong place, but the banner is misleading and the
  listing's `name` can disagree with the connection actually used. Each settled on its own within a
  few seconds and a re-run passed. Not fixed here.
