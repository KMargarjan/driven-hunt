# Task 219 -- the legendary boar

Task: 219
Round: 2
Base: 43a7d3d
Code commit: ebc9710

Karen, 2026-10-10: *"Legendary animals: one or a few, e.g. a legendary boar"*, and 2026-10-11:
*"legendary animals worth more"*. Task 160 wrote `POINTS.KIND.legendary = 25` as a price with no
animal behind it. This is the animal, and the price did not move.

## Round 2: the four blocking findings, and the Director's look

Every finding is accepted; I argued with none of them. What follows is what changed and how to check
it. The round-1 body below is kept because its claims are still the claims.

**1. The roll is the WORLD'S.** `self._legendaryRng = world.legendaryRng or Random.new()`, and the
specs that release a sounder with kinds ON pin `LEGENDARY.CHANCE_PER_DRIVE` to **0** -- which needs
no stream at all, because `NextNumber` returns [0, 1) so 0 is never, exactly. My round-1 comment
claimed *"no spec depends on it"*: true of the STREAM, false of the OUTCOME, and the Reviewer is
right that a green gate was one sample of a random variable.
*Blast radius checked rather than assumed (L-093):* eight specs call `spawnSounder`; exactly three
enable `KINDS` -- `boar_behaviour_live`, `boar_shot` (three worlds) and `boar_legendary` -- and the
other five cannot promote at all, because `_legendaryAllowed` returns false with the flag off. All
five kinds-on worlds are pinned. `boar_behaviour_live`'s `wanted` table also gains the fourth kind,
so if it ever did meet one it fails as a readable expectation instead of as nil arithmetic.
Check: `boar_legendary.spec`, *"cannot surprise a spec that pinned the chance, which is what round 1
could"* -- 0 and 1 are exact, and two runtimes built with the same `legendaryRng` seed answer the
same thing.

**...and the yearling (note 5), which is the same defect's other half.**
`SOUNDER.MAKEUP.YOUNG_MALE` is ALSO `"male"` at a 0.25 chance, so "the first male in the release"
picked a YEARLING walking behind its mother a quarter of the time. `Boar.promoteLegendary` now
refuses any release containing a SOW, which makes the research note's *"a release of sows and
piglets promotes NOBODY"* true as written. Check: *"NEVER promotes a yearling walking behind its
mother"*.

**2. The gathering.** `Body.displayCarcass` takes the kind's geometry and applies `Model:ScaleTo`
and the `SurfaceAppearance` tint -- the same two operations `Body.attachVisual` performs on the live
animal -- and `Runtime:displayCarcass` hands it in. Scaled BEFORE the pose, because
`Body.lyingCFrame` reads the mesh's size. Check: `boar_legendary.spec`, *"is laid out at the
gathering BIGGER AND DARKER, on the model branch"* -- it builds a runtime with `KINDS` and `MODEL`
on and a template carrying a `SurfaceAppearance` exactly as the bought asset does, then asserts the
drawn mesh is 1.35x the male's on two axes, that the trophy's coat is the tint and the male's is
white, and that it still rests on the ground. It also compares `SCENE.ANIMAL_SCALES` against the
boar's own scales, so the copied numbers the grey-box branch uses cannot drift from the animal.

**3. The fade.** `setFade` now writes the `Trophy` label's `TextTransparency`, named beside `label`.
It is a child of the CARD, not of an art frame, so the descendants walk could never reach it. Check:
the clock case is driven with a **legendary** payload now (with `buckPayload()` the tag was hidden
and empty, so the walk stepped over it -- which is why the defect this file was blocked for in round
2 of task 198 recurred on the next child added), and it names the tag rather than trusting the class
walk.

**4. The tag is off the animal.** Round 1 put a 14 px tag at plate y 76..90 inside an art box
spanning 8..88, in `BOAR_FILL` -- the animal's own ink -- above both the animal and the dots, and the
derivation written beside it was arithmetically false. The card grew six pixels (`CARD.HEIGHT`
138 -> 144) and the tag sits BELOW the plate, on the dark card, in the headline's own `LABEL_COLOR`.
**The cost, said out loud: an ordinary card now carries six pixels of empty band under its plate.**
Check: the hit-card case asserts the tag's top is at or below the art frame's bottom AND below every
pellet dot, as rectangles, and measures the text against the label's OWN box (round 1, note 6)
rather than the plate's width.

### The Director's look: the tint

He is right that `219-pair-lit2.png` is a flat black silhouette, and the number he offered instead
would not have fixed it -- **the value is a MULTIPLIER on the artist's ColorMap, not a colour.**
RGB(70, 58, 48) is x(0.275, 0.227, 0.188): a quarter of the coat's brightness, fur included.
RGB(70, 62, 55) is x(0.275, 0.243, 0.216) -- the same quarter. The tint is now **RGB(150, 138, 125)
= x(0.588, 0.541, 0.490)**: a little over half, warmed down and slightly desaturated.

**Frame: `.screenshots/20261020T045958Z-219-r2-tint.png`**, the player's own first-person eye (root
y 5.15 over ground y 2.00), sun on the side facing the camera. The bristled coat, the pale muzzle,
the shoulder hump and the individual legs are all visible where round 1's frame had none of them.
**Please verify this frame yourself (L-086)** -- it is the one thing in this round only I have
looked at.

**AND READ THE FRAME'S CAVEAT, because it is not the pair you asked for.** The sow guard added for
note 5 means **DEV can no longer spawn a legendary at all**: its drive releases carry no composition,
so `sounderKinds` always makes member 1 a SOW, and a sow-led release now promotes nobody. Round 1's
DEV trophy *was* the yearling-in-a-nursery case, which is why it appeared then and cannot now. So
the frame shows the two operations the code performs -- `ScaleTo(1.35)` and the new
`SurfaceAppearance.Color` -- applied by hand to a live drawn animal beside an untinted one, and it
answers the tint question and nothing else. **It is not a legendary spawned by the drive.**

**THIS IS A REAL CONSEQUENCE AND IT NEEDS YOUR DECISION (queued as TASKS.md 219a(h)):** with the sow
guard, only a male-GROUP release can carry the trophy. The Forest Test has those
(`SOUNDER.COMPOSITIONS` rows 2 and 6 -- `{ males = 2 }` and the lone big male), so the real game
still produces one; **DEV's unstructured releases never will.** The alternative is to let the drive
release a lone male when a drive has drawn a trophy, which is a change to `Match.Phase`'s release
schedule -- a different owner and not a findings round's work.

## What changed

A fourth row in `Boar.CONFIG.KINDS` and the handful of things that row touches: the drawn rig is
scaled and tinted at the one place that welds it, the damage model takes an optional per-animal
armour, the Brain gets a per-kind config, the Runtime draws one rarity roll per drive, and three
screens learn the word. `tools/studio_mcp.py` gains the new spec file in the `boar` scope.

Note: `docs/research/2026-10-20-legendary-boar.md`.

## Claims, and how to check each

1. **The trophy is 1.35x the male in EVERY box and in the drawn rig, on his own bought asset.**
   `Boar.CONFIG.KINDS.legendary` (`scale`, `meshScale`, `model = "male"`). Check:
   `boar_legendary.spec`, *"is the male's own asset at 1.35, every box and the drawn rig"* --
   trunk, all four zone sizes and all four zone offsets against the male's times 1.35. Live, in the
   DEV place: the census read `kind=legendary boxZ=7.43 meshZ=7.43` against the male's
   `boxZ=5.50 meshZ=5.50` (7.43 / 5.50 = 1.3500), and from the client's own camera at the same
   23.8 studs the trophy drew **95 px tall against the male's 70** (ratio 1.357).
   Frame: `.screenshots/20261020T034543Z-219-pair-lit2.png` (the player's own first-person eye,
   root y 5.15 over ground y 2.00).

2. **`Model:ScaleTo` scales a skinned rig's BONES and `MeshPart.Size` does not -- MEASURED, and it
   corrects half of this repo's own comment.** `Body.luau`'s header has said since task 115 that
   *"`Size` and `Model:ScaleTo` move the mesh and not the bones"*. On the real published male in
   the DEV place, reading `Bone.WorldPosition` in the mesh's object space: `Size * 1.35` left the
   lowest bone at **-1.6264**, where it already was, and `ScaleTo(1.35)` moved it to **-2.1957**
   (exactly 1.3500); `hoof_f.L` Z went -0.7206 -> -0.9728, the same 1.3500. Check: the derivation
   is written out in `Boar.CONFIG.KINDS` and in `Body.attachVisual`, and the live frame above is a
   rig that is scaled and not torn.

3. **The clips scale with it, so `clipScale` is 1.35 -- measured in PLAY, because a clip cannot be
   measured in Edit.** 41 samples across the published walk clip: the scaled rig's `hoof_f.L`
   travelled 2.2152 studs against the male's 1.6409 (1.3500). The death clip held at
   `length - HOLD_EPSILON` leaves the lowest bone +0.0030 above the box's bottom plane against the
   male's +0.0022, so `deathLiftStuds` is 0. Check: `boar_legendary.spec`, *"plays the male's clips
   at the male's stride times 1.35, inside its own rate rails"*.

4. **One rate rail had to move, and it is arithmetic.** `Body.gaitBands` gave every animal
   `MAX_RATE / clipScale`, which is only safe below 1: the worst ask (the trot clip at the top of
   its own band) is scale-INVARIANT at 2.733, so at 1.35 the ceiling would have been 2.074 and a
   third of the animal's feet would slide. It is `MAX_RATE / math.min(clipScale, 1)` now. Check:
   the case above asserts the legendary's ceiling IS `MAX_RATE`, that `MAX_RATE / 1.35` would have
   been below the ask, and that the male's 2.8 and the cub's 6.40 are unchanged --
   and `boar_kinds.spec`'s existing sweep now walks four animals, not three.

5. **Harder to kill is the DJV's `Schild`: a divisor on NON-VITAL damage only, never a second
   health pool.** `Wound.damageFor(..., toughness)` divides unless `Wound.hitClass` says the zone
   is `vital`. Check: `boar_legendary.spec`, *"is armoured everywhere but the vitals"* and *"dies
   to the chamber or the head and shrugs off a body shot, which a male does not"* -- a head or
   chest slug is `lethal` on both animals, a body slug is `mortal` on a male and a `graze` on the
   trophy, a rump slug no longer cripples it, five buckshot pellets become ten. The last case
   asserts the pair *side by side*, so the change cannot be read as "it got tougher everywhere".
   A bigger `LETHAL`/`MORTAL` was refused because it also scales the span `Wound.flightStuds`
   tapers the run across; the same case shows two body slugs run it exactly as far as one runs a
   male.

6. **Wary is two multipliers, and `Boar.kindConfig` is the IDENTITY for every other animal.** It
   returns the config TABLE ITSELF when a kind has no `wary` row. Check: *"notices further out and
   runs faster, and no other animal moved"* -- `expect(Boar.kindConfig("male", on)).to.equal(on)`
   for all three kinds, for `nil` and for an unknown kind, plus `Brain.noticeRadius` /
   `Brain.fleeRadius` answering larger numbers for the trophy's config and the run clip still
   inside its own ceiling at the faster speed.

7. **At most ONE per drive, with a chance per drive, and the cap is structural.** The roll is drawn
   once on a drive's first release, out of the Runtime's OWN `Random` so no existing spec's stream
   shifts; the permission is spent only when a male was there to promote, and `Runtime:clear`
   resets both. Check: *"promotes exactly ONE male, and nobody in a nursery"* (pure), and
   *"puts AT MOST ONE in a drive however many releases it has, and a new drive gets a new one"* --
   four lone-male releases in one drive produce exactly one trophy, a sounder afterwards adds none,
   and after `clear("driveOver")` the next drive gets its own. The lone-animal path (`size == 1`)
   is in that case on purpose: it returns early and was the first thing this task got wrong.

8. **The Studio-only forcing switch cannot change a live server, and a left-on switch fails the
   harness.** `Boar.legendaryForced` reads an attribute only under `RunService:IsStudio()`. It is
   deliberately NOT a `DHFlag_*`, which the harness WOULD have guarded -- so the guard is a spec:
   *"leaves the Director's forcing switch OFF, and fails the harness if it is not"*, which names
   the attribute and prints how to clear it.

9. **The screens name it, and two label widths were MEASURED rather than eyeballed.**
   `LEGENDARY` is 55.0 px in what was a 56 px report cell (Oswald Medium 17), so the ANIMAL column
   went 56 -> 78 and GUN 110 -> 88, still summing to `WELL_INNER`; `LEGENDARY - BUCKSHOT 4/9` is
   167 px in a 164 px hit-card label, so the card names the animal on its PLATE (104 px) instead.
   Check: `report_panel.spec`, *"names the LEGENDARY boar in the ANIMAL column, and the word fits
   the cell"* (it measures the string with `GetTextBoundsAsync` against the column's own width) and
   *"counts a legendary in the MALE column"*; `hit_card.spec`, *"names the LEGENDARY BOAR on the
   plate, and nothing else wears that tag"* (including that the tag is GONE on the next ordinary
   shot). The drive report's wire carries `byKind.legendary` as its own count rather than as an
   `unknown`, so "a kind typo shows up as a number" still means something.

10. **It is worth 25 points through the table task 160 already wrote, and the kill record carries
    the kind.** Check: *"is worth 25 points and 2.5 males, through the table task 160 already
    wrote"* drives `Match.Score.kill` and asserts the award's reason is `kill-legendary` and not
    `kill-unknown`; *"carries kind = legendary on the kill record"* drives `Wound.killRecord`.

## What I could not do, and what I got wrong

* **The tusks.** The brief asked for "pale tusks a bit longer if the rig allows". It does not: the
  rig is one skinned mesh with no separate tusk geometry and the tusks are painted into the
  `ColorMap`, so that needs a second mesh welded at the jaw or a reworked upload -- an asset task.
  They are drawn 35 % bigger with the rest of the animal and that is all this task delivers there.
* **The start card does not name it, and that is deliberate.** `START_CARD_ROWS_MAX` is 4 with the
  Designer's own reason on it, and the four are male, female, piglet and the PERSON row. A fourth
  quarry kind would have silently pushed the person row off a fixed-height card, so
  `Match.CONFIG.QUARRY` keeps three kinds and the spec asserts the absence
  (`quarryKinds + 1 == START_CARD_ROWS_MAX`). A fifth row is the Designer's call.
* **No toast when a legendary is in the drive.** The brief called it optional; it is not built.
* **THREE FAULTS THIS TASK MADE, ALL FOUND BEFORE THE REVIEW, two of them by the gate and the
  worst of them by looking at a live server.** (1) `Runtime:_modelTemplate` resolved the asset key
  through `Body.kindRow`, which answers the DEFAULT row while `KINDS.ENABLED` is false -- so in a
  MODEL-on, KINDS-off world every kind asked for "male" and `displayCarcass` would have drawn a
  male for a dead sow. (2) My own spec parented its boars to ServerStorage, where `SetNetworkOwner`
  is refused. (3) **`BoarAssetsBoot` asserted at boot over `pairs(KINDS)` with three names skipped
  by hand, so the two fields this task added killed that script and NOT ONE BOAR IN THE GAME WAS
  EVER DRESSED.** A full 33/33 gate said nothing, because no spec runs a boot script. The loop
  walks `KINDS.ORDER` now, and `boar_legendary.spec` holds the invariant that boot depends on
  (*"wears a model the composition root can actually find an asset for"*).

## Live, in the DEV place (`BOAR_MODEL` + `QUICK_TEST` + the forcing switch on, all three cleared and READ BACK afterwards -- `ServerStorage` carries no attributes at all now)

Three drives, each with the switch on, each produced exactly ONE legendary; a release of a sow and
two piglets promoted nobody and left the drive's permission unspent, which is the rule.

* **The animal.** `kind=legendary boxZ=7.43 meshZ=7.43 tint=0.2745,0.2275,0.1882` beside a
  `male boxZ=5.50 meshZ=5.50 tint=1,1,1` (7.43 / 5.50 = 1.3500). Read from the CLIENT's own camera
  with both at the same 23.8 studs: the trophy drew **95 px tall against the male's 70** (1.357).
* **The frame** (rule 5, rule F): `.screenshots/20261020T034543Z-219-pair-lit2.png`, the player's
  own first-person eye (root y 5.15 over ground y 2.00), sun on the side facing the camera. The
  trophy reads near-black with a heavy shoulder hump; the male beside it shows its ordinary brown
  coat in the same light.
* **On the ground** (rule E): measured UNSTAGED, while both were running in the field -- the lowest
  visible mesh point against the ground under them was **-0.033** (legendary) and **-0.032** (male).
  Feet planted, and the two agree. The staged frame reads 0.000 for both, which is true *by
  construction* (the box bottom is placed on the ground and `Body.visualOffset` puts the mesh on the
  box), so it is NOT independent evidence and is not offered as any.
* **The kill.** Shot from a stand at 22 studs: **down on shot 1**, one chest slug -- the vitals are
  not armoured, which is the whole rule.
* **The report, end to end from that kill.** The real server's list payload carried
  `byKind.legendary = 1` and `unknown = 0` (its own count, not an unknown), and the detail payload
  `kind = "legendary"`. Drawn: `.screenshots/20261020T040526Z-219-report-tab.png` shows
  `MALE 1  FEM 0  CUB 0  KILLS 1  POINTS 25`, and
  `.screenshots/20261020T040541Z-219-report-detail.png` shows the row
  **`LEGENDARY   DOWN   chest   4 m   SHOTGUN   1`** -- the full word, untruncated, in the widened
  column.
* **The hit card drew, and the tag stayed OFF for an ordinary animal**: a male shot on the same
  stand gave `label="H I T   -   S L U G" trophyVisible=false trophyText=""`.

### WHAT I DID NOT CATCH LIVE, and I am not implying otherwise

**The `LEGENDARY BOAR` tag on the hit card itself.** The card holds 3 s and my first read arrived
after it had faded; by then the drive's one legendary was dead, and the role rotation (task 217) put
the player on Drivers, so the next chance was two drives away. What covers it is
`tests/client/hit_card.spec.luau`, which drives the REAL renderer with a legendary payload, reads
the DRAWN label (`Trophy`, through `Style.unspaced`), checks it against the plate's width and
asserts it is gone again on the next ordinary shot -- and the live NEGATIVE half above. To catch it
live: wait for an armed Shooter turn with the switch on, then fire and poll `card.Visible` inside
ONE client call (`driven-hunt-runs/t219-fire-read.luau` does exactly that; it is what caught the
male's card).

### Three things the game refused, all correctly, and none of them this task's defect

A staged player off his stand could not shoot (task 171). A player the rotation had moved to Drivers
could not either (task 217). And `execute_luau`'s `require` returns a SEPARATE COPY of a server
module, so a Tool granted through a probe's `Weapon.refreshArming` is a ghost the real module never
tracked -- the real server logged `shots=0, refused=0, badRequests=0`, which is `stateOf` answering
`untracked` before any counter moves. Worth knowing before the next live weapon probe.

## Harness

BOTH LINES, at the same commit, on a clean tree:

```
[harness]  PASS: 33/33 checks @ ebc97103617413543a7dae7882544c2775746771 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ ebc97103617413543a7dae7882544c2775746771 (clean tree)
```

Both at the SAME commit, both on a clean tree. The two-player line is the **Director's**
(2026-10-20, first try) -- `test2` needs a human click StudioMCP cannot make; `ESCALATE.md`'s round-2
entry records that stop as resolved. On L-055, which was raised against this task because it is a
`Match`/`Score` case: it cannot apply to `test2`, which is a DEV-place mode BY CONSTRUCTION --
`HARNESS_PLACE_ID` is the DEV id and the mode's own `[<side>] report comes from the DEV place` check
compares the report's `placeId` against it on both sides, so a run that landed elsewhere would fail
rather than pass quietly. There is no Forest Test leg to fall back from. I verified that semantics
and that the sha and clean-tree marker match the code commit; I did not run it, and say so.

**The Director also looked at the tint frame** (`.screenshots/20261020T045958Z-219-r2-tint.png`) and
accepted it: *"the legendary now reads as a dark, grizzled boar with fur"*.

ROUND 1's PAIR, now superseded by the commit above:
```
[harness]  PASS: 33/33 checks @ 125926dc5925b9573d78e3de943bdd6ed3c3cf0d (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 125926dc5925b9573d78e3de943bdd6ed3c3cf0d (clean tree)
```

**THE FIRST ROUND-2 GATE FAILED AND IT WAS ALL MINE**, reported because a clean line on its own
hides the work: `FAIL: 31/33 @ 4707c2d (DIRTY TREE (1 paths))`. Two failures, both in the spec this
round ADDED -- the promote case still led with a SOW and expected the third member taken, which is
the yearling-behind-its-mother that note 5 is about written down as an expectation; and the new
display case's fake template was UNPARENTED, and `Runtime:_modelTemplate` only reuses a held
template while `held.Parent ~= nil` with re-asks rate-limited to once a second per key, so it
answered `male` and nil to `legendary` (the same "male" key) for a reason with nothing to do with
the trophy. The DIRTY TREE was mine too: I edited this file while the run was going.

The one-player line is mine; the **two-player line is the Director's** (2026-10-20, first try) --
`test2` needs a human click that StudioMCP cannot make, which is what this task stopped for and what
`ESCALATE.md`'s entry records as now resolved.

`scope=all`, so the one-player line is FULL evidence rather than a review-round-only
`scope=auto:...`: `src/shared/Report/`, `src/server/HitLog/` and `src/shared/Drive/` map to no
`BLAST_RADIUS` row, so `--scope auto` ran the whole suite. The run before it (31/33 at `e13f015`) is
what found two of this task's three faults; the third was found by looking at a live server
afterwards.

**Why `test2` was required at all:** the change touches `src/server/Match/init.luau`, which is in
`TWO_PLAYER_PATHS`. **And why the DEV-fallback flake cannot apply to it** (the Learning Agent's
L-055, raised against this task because it is a `Match`/`Score` case): `test2` is a DEV-place mode
*by construction* -- `HARNESS_PLACE_ID` is the DEV id, and the mode's own check
`[<side>] report comes from the DEV place` compares the report's `placeId` against it on both sides,
so a run that had landed anywhere else would have failed rather than passed quietly. There is no
Forest Test leg in `test2` to fall back from. What I verified is that semantics and that the sha and
the clean-tree marker match the code commit; I did not run it, and say so.
