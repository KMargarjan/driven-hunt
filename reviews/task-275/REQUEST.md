# Task 275 -- the two last causes of a missed led chest shot

Task: 275
Round: 1
Base: `0084d991` (`main`, after #253)
Code commit: (filled in with the harness line)

## PLAN

### (a) REAL LIFE

A hunter who puts the crosshair on a running deer's chest and squeezes expects the chest, every
time -- not one shot in five. At 28 studs/s a deer covers 4.5 studs in the 0.16 s between the
picture he shot at and the server's own clock, which is most of its chest-to-flank width.

### (b) MEASURED NOW -- task 274, five led shots, Karen's place, `HIT_CLAIM` on

`<runs-dir>/274-core.log`: **1 of 5 chest.** The four that were not split exactly two ways:

* **2 sent NO claim at all** -- `claims=6` over a trial whose `ShotLanded` count was higher; the
  client's own simulation found nothing to claim.
* **2 refused `claim-line` at 4.090 of 2.000**, still the ~0.16 s along the animal.

### (b2) AND ONE HALF OF THE DISPATCH'S ITEM 2 IS ALREADY REFUTED BY READING, BEFORE ANY SHOT

`claim-line` **is** judged at the swept instant. `judgeClaimFor` picks the instant
(`Validator.pickViewInstant`), sets `local serverPoint = candidates[index].point`, and hands the
judge `serverPoint = serverPoint` and `trajectoryPoint = closest` -- both of them the SWEPT
instant's (`src/server/Weapon/init.luau:1784,1786`). Task 274's own reading confirms it from the
other side: `took=1 best=1@4.090` on the refusals -- the chosen instant WAS the best one -- and
`took=12 best=12@0.767` on the accepted chest shot.

**`claim-blocked` is the one that is NOT.** It is given `reachedStuds = res.reachedStuds`
(`:1787`) -- how far the SERVER's own flight got, resolved against the animal at the SERVER's
instant, not the swept one. Task 274 measured exactly that: `claim-blocked worst 7.275/1.000
(reached 38.79 of 46.07 studs, stopped by Workspace.Boars.Boar147.ZoneChest)` -- **the server's own
bullet stopped on the claimed animal's own chest 7.3 studs short**, because on the server's clock
that animal is 7 studs nearer the muzzle than the shooter saw it.

So item 2 is one check, not two, and it is `claim-blocked`.

### (c) TARGET

* **Item 1:** for each of five shots, the gate that decided whether a claim was built -- the
  character, the tool, the muzzle, the row, the ammo, the pellet count and the simulation's own
  answer -- read live. One line per shot, naming the gate that returned.
* **Item 2:** `claim-blocked`'s shortfall is judged against the animal at the swept instant, so a
  bullet the server stopped on the CLAIMED animal is never counted as blocked by the animal's own
  displacement. A forged claim is still refused: the sweep's window bounds how far back the
  displacement may be credited.
* **Item 3 (CORE):** **at least 4 of 5, and 8 of 10, led shots accepted and chest-named with the
  mark on the chest.**

### (d) LEVER

```
src/server/Weapon/init.luau:1787:		reachedStuds = res.reachedStuds,
src/server/Weapon/init.luau:1796:		stoppedByClaimedTarget = stoppedBySame,
src/server/Weapon/Validator.luau:  (check 5)  if not waived and facts.reachedStuds + limits.REACH_SLACK_STUDS < facts.claimedStuds then
src/client/Weapon/Claim.luau:277:function Claim.forCamera(cframe: CFrame, snapshot: any?, firedAtView: number?): Shotgun.HitClaim?
```

`reachedStuds` is the one number check 5 compares and the owner is its only writer;
`Claim.forCamera` is the one gate chain that decides whether a claim exists at all.

### (e) HOW IT WILL BE MEASURED AFTER

The same instrument: `<runs-dir>/268kill.py` + `proof268.py` (`DHTestRelease` stages the hind
party, the tracked led hold, `aimshot`'s real focused clicks through `click.ps1`), `DHClaimStats`
read as a live `ServerStorage` attribute (L-026), plus a client-side gate probe for item 1.

### On L-088

Started **2026-10-26T09:55:01Z** (`<runs-dir>/275-start.txt`, the literal `date -u` output); the
2.5 h mark is **12:25:01Z**.

## WHAT CHANGED

(filled in)

## CLAIMS

(filled in)
