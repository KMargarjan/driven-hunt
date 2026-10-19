# Task 215 — the lodge, after the Director's look before merge

Task: 215
Round: 1
Base: `120ce75` (main, the merge of #196)
Code commit: `f228a425ad6d686482f2fed4b5bcfaa1947bf2b4`

```
[harness] PASS: 33/33 checks @ f228a425ad6d686482f2fed4b5bcfaa1947bf2b4 (clean tree) scope=all
```

`[harness2]`: **N/A.** The only code files this round touches are `src/shared/Lobby/init.luau` and
`tests/server/light.spec.luau`; neither is in `TWO_PLAYER_PATHS` (`tools/agents.py`). Six lamps in
one room look the same to one player as to two.

The earlier rounds of task 215 passed review (`RESULT.md`, round 3, commit `1ba5b5b`). The Director
then looked at the frames before merging and rejected ONE scene: *"D (lodge from the door): NOT
Karen-ready. The whole room is a saturated ORANGE wash: logs, floor, stone and the counter are all
one orange; the ceiling lanterns are glowing yellow blocks; it reads as a colour filter, not warm
wood."* C and B he kept. This round is that fix and nothing else.

## Claims

1. **The orange was the LAMPS, and that is a measurement rather than a guess.** `LOG_COLOR` is
   already `#4A3826` and the hearth stone is a NEUTRAL GREY `#5A5750`, and the stone was still
   rendering saturated ochre — so the albedo cannot be the cause. Proved live at one camera: with
   every `PointLight` and the `Fire` disabled the room renders **black**, so nothing but the lamps
   lights it (`Ambient 44,40,34` contributes effectively nothing indoors, which is what it was
   chosen to do).
   *Verify:* `<runs-dir>/t215/diag-V0-no-lamps-no-fire.png` and `diag-V1-no-lamps-fire-only.png`.

2. **The grade is NOT what oranges the wood, tested on its own lever, and so it is unchanged.** The
   Director asked me to check `ColorCorrection.Saturation`. Lamps held at the new values, grade
   moved 0.14 → 0.06 → 0.00 at one settled camera: the lit log wall goes **luma 44.4 → 43.5** and
   blue-over-red **0.04 → 0.08**; the three frames are indistinguishable. `Saturation` stays at the
   Designer's **0.14** and `ExposureCompensation` at **0.15**, so **B and C cannot have moved** —
   one lever for one defect (L-012), and the lever is six lamps inside a building 800 studs from
   the drive.
   *Verify:* `<runs-dir>/t215/diag-S14-designers-grade-D.png`, `diag-S06-less-sat-D.png`,
   `diag-S00-no-sat-D.png`; the numbers in `lodge-measure.txt`.

3. **What changed, all of it in `Lobby.CONFIG.LODGE`:**
   `LANTERN` **1.25 / 20 / 255,186,116 → 0.85 / 14 / 255,214,170** (the Director's own colour),
   `FIRE_LIGHT` **2.40 / 30 / 255,176,104 → 2.40 / 20 / 255,190,136**, and
   `LANTERN.GLASS_COLOR` **240,186,118 → 208,160,104**. The fire keeps its brightness and stays the
   brightest thing in the room, which was his condition.
   *Verify:* `light.spec` → "carries the lamp numbers the Director's look settled on", "keeps the
   lamps warm but not ORANGE", "leaves a lantern's pool smaller than the room", "keeps the fire
   reaching further than a lantern".

4. **The glass needed its own change because no lamp number can reach it.** The pane is
   `Enum.Material.Neon`, which ignores the light in the room and renders at roughly its own colour
   — so taking the room DOWN made the lantern read brighter against it, not dimmer, which is the
   Director's *"glowing yellow blocks"* exactly. Tested at his camera against 176,134,86: at
   **208,160,104** the pane reads as a warm amber lamp with its four iron corner posts visible
   against it, and it sits further under `Bloom`'s 1.6 threshold; 176 is dimmer with nothing
   gained. Only the inside and porch lanterns read this constant — the window glass has its own
   (`#8096A2`).
   *Verify:* `<runs-dir>/t215/diag-G240-as-built-D.png`, `diag-G208-D.png`, `diag-G176-D.png`.

5. **At the Director's own camera, measured: the room is much darker and the gradient is real.**
   Rejected build against committed build, same camera, same session shape:
   | | rejected | now |
   |---|---|---|
   | lit log wall | `#B34001` luma 91.1 | `#832B01` luma **64.7** (−29 %) |
   | hearth stone | `#B76413` luma 115.4 | `#8C4B17` luma **88.7** (−23 %) |
   | floor | `#D35601` luma 113.8 | `#892E01` luma **67.7** (−41 %) |
   | the dark end of the room | `#792002` luma 55.5 | `#250601` luma **14.7** (−73 %) |
   *Verify:* `<runs-dir>/t215/final-pair-D-lodge-from-the-door.png`, looked at.

6. **The trophy scene is the one that is unambiguously fixed.** Rejected: a flat bright ochre sheet
   of stone with a pale head on it. Now: the breast reads as dark GREY-BROWN stone with its mortar
   and relief visible, the head is dark with a warm lit snout and tusks, and the `KEILER` plaque is
   the brightest thing under it. That is the Director's *"stone as grey-brown stone"* met.
   *Verify:* `<runs-dir>/t215/final-pair-E-boar-on-the-stone.png`, looked at.

7. **The boar in shade did not move, and the strongest evidence is the GRASS.** Same camera, same
   staged boar on the same shaded grass: the grass measures **luma 15.25 before and 15.27 after** —
   the outdoor light is unchanged to two decimal places, as claim 2 says it must be. The boar's own
   box reads 5.40 → 6.05, so the separation is **2.82 : 1 → 2.52 : 1**. That delta is the ANIMAL,
   not the light: it is anchored but not frozen mid-pose, and across four sessions at this camera
   the same build measures between 2.52 and 3.05. **So the honest answer to "is it still ≥ 2.91" is
   no — it is 2.52 at this frame, and it was never stably 2.91**; what did not change is the
   lighting.
   *Verify:* `<runs-dir>/t215/final-pair-C-boar-in-shade.png` and the four C frames
   (`after-`, `fix-`, `fix2-`, `final-`).

8. **The pools are real now, and 215b is answered in part.** With the new ranges, of 1,681 floor
   samples **122 (7 %) are reached by NO lamp** and **442 (26 %) by exactly one** — against **0 %**
   and **2 %** on the rejected build. No lamp reaches the far wall of the 34.8 × 24.8 room any
   more. The three lanterns still OVERLAP down the centre walk (10 studs apart, ~13.6 studs of
   floor reach each), so "dark boards between the pools" is true at the edges and not down the
   middle — and `light.spec` says so in the file rather than claiming otherwise.
   *Verify:* the coverage line in `<runs-dir>/t215/cameras.json` (`cover_final`); `light.spec` →
   "leaves a lantern's pool smaller than the room".

9. **How dark is too dark was measured, not guessed, and it set the floor.** Four lamp levels at
   the shop counter: on the committed numbers the keeper reads as a dark figure with his hat and
   the counter edge visible; one step darker (0.65 / 12) and he is a shape; two (0.45 / 11) and the
   counter is black. That is why the numbers stop here and not lower.
   *Verify:* `<runs-dir>/t215/diag-W5-shipped-S.png`, `diag-W2-committed-S.png`, `diag-W6-mid-S.png`,
   `diag-W3-half-S.png`.

10. **Gate and rules.** `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both pass
    (rule G). One spec assertion of mine was wrong and the harness caught it — the first version
    asserted `2 × range < room length` for BOTH lamps and the fire failed it, because the fire is
    built against the WEST WALL and only ever reaches one radius in; the config was right and the
    assertion was fixed (`8a473d7`).

## What I could not verify, and what I got wrong

* **The lodge is better but it is NOT "brown wood and grey-brown stone" at the wide camera, and I
  will not claim it is.** Claim 5's numbers are real and claim 6's frame is a clean win, but at the
  Director's own framing the room still reads as a warm orange room rather than brown wood. The
  reason is measurable and no lamp or grade number fixes it: at these light levels the BLUE channel
  has almost nothing to work with (the lit wall is blue-over-red **0.04**, against a lamp colour of
  0.67), so every interior surface renders warm whatever its albedo. Getting a genuinely neutral
  stone would need a cool fill light in the room or a much less warm lamp — both design decisions
  past the three levers the dispatch named. **If that is still not Karen-ready, the next step is a
  decision, not another tweak.**
* **Two darker variants are already shot and are a one-line change each** if the Director wants to
  go further knowing the cost to the shop (claim 9): `W6` = 0.65 / 12 / 255,220,182 with fire
  2.00 / 17, and `W3` = 0.45 / 11 / 255,222,190 with fire 1.60 / 15.
* **A mistake of mine, named.** My first comparison sheet concluded the fix worked by putting a
  CLOSE frame beside two WIDE ones — the first capture of a Studio session comes back at a wider
  framing than the ones after it, and at the lodge the camera is third-person (wide) or first-person
  (close) depending on how many transitions it has been through. That is not a comparison (L-021),
  and every pair in this request is now same-framing, with a thrown-away warm-up capture before it.
* **I did not shoot the Director's frames for him.** Every frame here is mine, which is the thing
  L-086 says has never been checked independently. The Director's own camera numbers are in
  `<runs-dir>/t215/cameras.json` and `reshoot.py` takes a label, so `python reshoot.py <name>`
  reproduces D, E and C from his side.
* **Time box:** 60 minutes asked, about 100 spent. The overrun is the two extra live sessions that
  found the framing mistake and the Neon glass.
