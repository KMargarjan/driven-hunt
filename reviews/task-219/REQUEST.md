# Task 219 -- the legendary boar

Task: 219
Round: 1
Base: 43a7d3d
Code commit: 125926d

Karen, 2026-10-10: *"Legendary animals: one or a few, e.g. a legendary boar"*, and 2026-10-11:
*"legendary animals worth more"*. Task 160 wrote `POINTS.KIND.legendary = 25` as a price with no
animal behind it. This is the animal, and the price did not move.

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

```
[harness] PASS: 33/33 checks @ 125926dc5925b9573d78e3de943bdd6ed3c3cf0d (clean tree) scope=all
```

`scope=all`, so it is FULL evidence: `src/shared/Report/`, `src/server/HitLog/` and
`src/shared/Drive/` map to no `BLAST_RADIUS` row, and `--scope auto` therefore ran the whole suite.
The run before it (31/33 at `e13f015`) is what found two of this task's three faults, and the third
was found by looking at a live server afterwards.

`test2` is NOT run here: the change touches `src/server/Match/init.luau`, which IS in
`TWO_PLAYER_PATHS`, so it is the Director's run. Stopped for it.
