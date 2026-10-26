# Task 275 -- the two last causes of a missed led chest shot

Task: 275
Round: 1
Base: `0084d991` (`main`, after #253)
Code commit: `5847f412b17777a2b30f99a1f2028177023ea119`

```
[harness] PASS: 34/34 checks @ 5847f412b17777a2b30f99a1f2028177023ea119 (clean tree) scope=all
```

`test2` is **N/A**: `src/client/Weapon/Claim.luau`, `src/client/Weapon/Input.luau`,
`src/server/Weapon/` and `tests/server/weapon_shot.spec.luau` -- none in `TWO_PLAYER_PATHS`.

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

* `src/client/Weapon/Claim.luau` -- `simulate` and `forCamera` answer a REASON beside their nil:
  thirteen words covering every gate.
* `src/client/Weapon/Input.luau` -- writes that word to the Studio-only attribute `DHClaimWhy`.
* `src/server/Weapon/Validator.luau` + `init.luau` -- the self-block waiver's bound carries
  `displacementStuds`, the claimed animal's own travel over the swept lag.
* `tests/server/weapon_shot.spec.luau` -- four arms of that bound.

## ITEM 1 -- **MET, AND THE SUSPECT IS CLEARED**

The dispatch suspected 269a(b) -- *"no reload between two shots means no claim"*. **It is not that.**
Per-shot, live, with the reason read off `DHClaimWhy` (`<runs-dir>/275-a.log`, `275-b.log`):

| trial | shot 1 | shot 2 | shot 3 | shot 4 | shot 5 |
|---|---|---|---|---|---|
| A (led) | `claim` | **`static-blocked`** | `claim` | **`static-blocked`** | `claim` |
| B (unled) | **`static-blocked`** | `claim` | `claim` | `claim` | `claim` |

**Every no-claim shot in ten reads `static-blocked`: the CLIENT's own static pass found something
between the muzzle and the animal.** Not `no-ammo` (the instrument reloads before every shot, so
269a(b)'s case never arises here), not `refined-nil`, not `no-target`. The gate that closes is the
client's own line of sight, and it closes on the grass, a trunk or the ground in front of a deer
crossing low ground -- which the zones of those same shots corroborate: `Trunk(nil)` and
`Boar66(body)` where the server's own bullet went.

**269a(b) remains real and remains unfixed** -- a second shot without cycling still builds no claim,
and `no-ammo` is now the word it leaves behind -- but it is not what cost task 274 its two shots.

## ITEM 2 -- **ONE CHECK, NOT TWO, AND IT IS FIXED**

**`claim-line` was already judged at the swept instant** (the PLAN's (b2), by reading:
`serverPoint` and `trajectoryPoint` are both `candidates[index]`'s), and task 274's `took=1 best=1`
confirms it from the other side. **`claim-blocked` was not**: it is given `reachedStuds`, the
SERVER's own flight's reach at the SERVER's instant.

The fix adds `displacementStuds = part.AssemblyLinearVelocity.Magnitude * lineLagSeconds` to the
self-block waiver's bound, and to nothing else. Both factors are the server's own: the part's
measured speed, and the lag the server's own sweep chose inside a window the server owns.

**MEASURED, same instrument, before and after:**

| | `claim-blocked` refusals |
|---|---|
| task 274 (before) | 1, `worst 7.275/1.000 (reached 38.79 of 46.07, stopped by Boar147.ZoneChest)` |
| 275 trial A (after) | **0** |
| 275 trial B (after) | **0** |

Ten shots, no `claim-blocked` at all; every refusal in both trials is `claim-line`.

## ITEM 3 (CORE) -- **NOT MET. This is still unproven at the rate Karen would need.**

| trial | chest | accepted | refusals |
|---|---|---|---|
| A, 5 LED shots | **0 of 5** | 2 of 3 claims | `claim-line` 4.403/2.000 |
| B, 5 UNLED shots | **2 of 5** | 3 of 7 claims | `claim-line` 4.668/2.000 |
| **both, 10 shots** | **2 of 10** | | |

Target 8 of 10. **Measured 2 of 10.**

### And the strongest remaining signal, measured on one build in one session

**0 of 5 when the shooter leads; 2 of 5 when he does not** -- and the accepted claims of trial A
named `ZoneRear(rear)` while trial B's named `ZoneChest(chest)`. `Claim.simulate` already advances
the animal to the instant the bullet arrives (task 270), so **a shooter who also leads by
`v x flight` applies the lead twice and his own simulated bullet meets the animal's rear.** That
was 269b's hypothesis; this is the first trial that puts both arms side by side on the same build.

**If that reading is right, the dispatch's own target is testing the wrong input**: with the claim
path on, the correct aim is AT what the shooter sees, and the instrument's `--lead` is a second
compensation the game has already made. **I am not asserting it as proven** -- 2 of 5 is not a
rate either, and the remaining refusals are `claim-line` at 4.4-4.7 of 2.0 with `took=1 best=1`,
which is task 272's finding unchanged: no instant in the window brings the server's own trajectory
within 2.0 studs of the server's own animal.

## CLAIMS

1. **Every no-claim shot in ten reads `static-blocked`**, per shot, from `DHClaimWhy` -- a
   Studio-only attribute written by `Input.fire` and gated on `RunService:IsStudio()`.
2. **The reason is returned, not stored**: `Claim.simulate` and `Claim.forCamera` answer it beside
   their nil, so the module still holds no state and writes no Instance -- its own header's rule.
3. **`claim-line` was already at the swept instant** and `claim-blocked` was not, by reading, with
   the two `facts` lines cited in the PLAN.
4. **The displacement bound is driven from four sides** in `weapon_shot.spec`: accepted with the
   displacement, **refused without it at exactly 7.275** (the live number), refused when a TREE
   stopped the bullet however large the displacement, and refused for a nil, negative or NaN
   displacement. **The first arm fails on the commit before this task**, where the bound had no
   third term.
5. **`claim-blocked` went from 1 refusal to 0 over ten shots**, same instrument, same place.
6. **Item 3 is NOT MET: 2 of 10.**
7. **The Forest Test is as it was found.** Twelve attributes before, twelve after; `HIT_CLAIM` ON
   for the trials and OFF again (rule K); `flags.py --place forest clear` never run; `DHTestOwns`
   added and removed by name. Play stopped and the window closed before the harness ran -- only DEV
   was open.

## WHAT COULD NOT BE VERIFIED

* **The double lead.** 0 of 5 led against 2 of 5 unled is a signal, not a proof, and I have not
  changed the instrument's default on the strength of it. **The next task is one trial of ten
  unled shots against ten led**, which settles it; if unled wins again the target itself should be
  restated as "aimed at what the shooter sees".
* **`claim-line` at 4.4-4.7 of 2.0 with `took=1 best=1`** -- unchanged by this task and not
  addressed by it.
* **No frame was taken this task**: the two chest hits were in trial B, which ran with `--frame`
  set, but neither is offered here because I did not open them. `NOT CITED` rather than cited
  unopened.
