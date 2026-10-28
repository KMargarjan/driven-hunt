# ESCALATE -- Task 305 (a shot hits what the shooter sees)

Written 2026-10-28; every time below is a `date -u` reading, not an estimate. Builder session
`5296d523`. **CORRECTION TO THIS FILE'S FIRST REVISION**: its header read "12:20 UTC" when `date -u`
said 10:22 immediately after it was written. V283: never state a time from memory.

## 0. WHY THIS IS HERE: round 2 returned FINDINGS, and the dispatch caps this task at 2 rounds

Round 1 (`fe8b589e`, 10:40 UTC): FINDINGS, four, all fixed in `bbba8b40` / `6b0d2271`.
Round 2 (`433cb7cd`, 11:21 UTC): **FINDINGS, two.** The dispatch says *"Review: max 2 rounds;
FINDINGS on round 2 -> ESCALATE.md and stop."* So this is the stop.

**BOTH ROUND-2 FINDINGS ARE TEST-STRENGTH AND PAPERWORK, NOT THE GAME. No `src/` line is named by
either.**

1. `weapon_rewind.spec` -- the nearest-candidate case could not fail: the injected answers FELL
   (9, 8, 7), so under a cap of 2 the last call asked was also the nearest and nearest-wins and
   last-wins gave one number. The Reviewer is right.
2. `weapon_rewind.spec` + claim 7 -- the `nil`-ping branch, the one `onFireRequest` itself takes,
   was still uncovered while the request asserted it closed. The Reviewer is right.

**I have fixed both in the tree and have NOT reviewed the fix** (the answers now RISE, 5 then 6, so
the selection rule decides the assertion; and one line calls `Weapon.rewindFor(nil, nil, CONFIG)`).
The request says of each, on the line itself, that it was added after the round-2 verdict and is
unreviewed. **Nothing is merged on that basis.**

**AND MY OWN FIX FIRST SHIPPED A RED SUITE, which is worth more than the fix.** `cd23e2bb` read
`[harness] FAIL: 32/34 checks @ cd23e2bbdff5e3d32cd3be01f6fe888c4d356093 (clean tree) scope=all` --
`weapon_rewind.spec:67 Expected value to be near 5.000000 but got 6.000000`: `seen` is incremented
before the answer is built, so `5 + seen` gives 6 then 7, not 5 then 6. **That is the second time in
one task that a number I wrote into a case was not the number the case produces, and it is exactly
the class of mistake round 2 found.** Corrected in `a502ccd1`, which is green:

    [harness] PASS: 34/34 checks @ a502ccd1210879bb4144a867d6d38c706f89a010 (clean tree) scope=all

So the tree the Director is deciding about is green and the two unreviewed changes are a test
assertion and a sentence. `reviews/task-305/REQUEST.md` still names `29476a77` as its `Code commit:`,
because that is the commit round 2 was run against; an authorised round 3 should name `a502ccd1`.

**WHAT I AM ASKING THE DIRECTOR FOR: the single extra round CLAUDE.md already provides for.** Its
condition is met exactly -- *"The Director may authorise a single extra round when the last round's
findings were documentation-only"* -- and both findings are a test assertion and a sentence. The
mechanism is an `ESCALATE.md` entry for **this task and this round** plus
`DIRECTOR_MAX_ROUNDS=3 powershell -ExecutionPolicy Bypass -File tools/review.ps1 305`, never
committed. I have not set it and will not without that authorisation written here.

## 1. THE FIX HAS TWO HALVES, BUILT BY TWO SESSIONS ON ONE BRANCH, AND BOTH ARE NEEDED

Two Builder sessions were dispatched task 305 on `task-305-aim-what-you-see`: `5296d523` (this one)
and `9d5b3ff8`. We measured the same defect from two distances and got **opposite signs**, which is
itself the finding.

| half | commit(s) | what it does |
|---|---|---|
| **the rewind** (`5296d523`) | `605e1f6d`, `bbba8b40`, `6b0d2271` | the server resolves a shot against each animal **where the shooter drew it**, 0.180 s back (measured), for every weapon. Behind `AIM_REWIND`, **dark** |
| **the ownership** (`9d5b3ff8`) | `97d67896` | re-pins the trunk to the server in `Body.attachVisual`, after the weld loop that rebuilds the assembly and reverts it to AUTO. **No flag** |

`Boar.Body.create` already calls `part:SetNetworkOwner(nil)`. `attachVisual`'s welds undo it, so the
engine hands a NEAR animal to the nearest player, the client simulates it, and the server's copy --
the one every shot is cast against -- is the stale one. **That is why the required lead flips sign
with the shooter's distance and cannot be learnt.** Measured, `reviews/task-305/MEASURED.md`:

| where | distance | pace | view lag |
|---|---|---|---|
| Karen's Forest Test, her range, her build | 126 studs | run 23.5 | +4.18 studs = 0.174 s, client in the **FUTURE** |
| DEV, the range, player on the mat | 123 studs | run 24.2 | -4.38 studs = 0.176 s, client in the **PAST** |
| DEV, boar at 115 studs (`<runs-dir>/305lag.py`, this session) | 115 studs | walk 2.6 | +0.180 s, client in the **PAST**, residual 0.011 studs |

The control for the last row is **moving and client-owned** (the player's own pushed
`HumanoidRootPart`, -0.170 s): a clock skew biases both recordings the same way, so opposite signs
of near-equal size cannot be skew. That is Learning Agent L-112's requirement, and it is what task
265 round 3 lacked.

**Neither half alone works, measured** (`MEASURED.md`, rifle, range run pace, 10 real `FireRequest`s
aimed at the client's own rendered chest plus `Ballistics.leadStuds` alone):

- (a) both dark -- **0/10**
- (b) ownership only -- **VOID**, 9 of 10 refused `no-ammo`
- (c) rewind only -- **0/6** (and that was round 1's finding 1: the range's own runtime was not in
  the provider seam, so the bullet went through the drawn animal, caught geometrically 0.05 studs
  from the chest and carrying on to the berm)
- (d) **both** -- **10 hits in 11 shots that flew**, chest x6 body x4, 6 for 6 at pace >= 15 studs/s,
  impacts 0.02-0.15 studs from the aim point

## 2. DECISIONS THE DIRECTOR OWNS

1. **The single extra review round** (section 0). Without it neither half can be merged: the gate
   wants `RESULT.md` line 1 = `PASS`.
2. **The order.** `97d67896` (ownership) is unflagged and ships lit; `AIM_REWIND` ships dark. **That
   combination has no hit-rate measurement anywhere** -- case (b) is exactly that build and is void.
   So merging the ownership half alone gives Karen a sign flip at close range that nobody has shot
   at. Either measure (b) properly first, or merge both and light the flag together.
3. **Whether `AIM_REWIND` is lit, and where.** The dispatch said *"born ON for the range"*; it ships
   `default = false` because round 1 finding 2 was right that this half alone is wrong while
   ownership is auto. With `97d67896` in, that objection is gone and lighting it is one line. Karen's
   own place needs the override set, not the default, until a merge.
4. **An Architect run on `docs/design/ballistics.md` BEFORE the flag is lit.** Section 1.3 says
   *"No shot is resolved against a rewound world by raycast"*, which this change contradicts, and
   the public-surface list omits `addHistoryProvider`, `setRewindWorld`, `setRewindPolicy`,
   `rewindFor` and `castWithRewind`. The Builder may not write designs (CLAUDE.md roles table), so
   this cannot be closed from here.
5. **A frame-time number before the flag is lit.** With it on, each pellet sub-step costs one
   `GetPartBoundsInRadius` (`MaxParts = 800`), one `table.clone` and a sort, plus up to
   `MAX_TARGETS` rays -- up to `FLIGHT_MAX_SUBSTEPS` x 9 for buckshot. Nothing in the repo measures
   it. The Reviewer asked for it as a note; it is a real question and it is not mine to answer with
   the Studio held.

## 3. NOT PROVEN, named rather than implied (rule 8)

- **Nothing of either half has been seen in KAREN's place.** Every proof row is DEV. Her own reading
  is of her SHIPPED build, which has neither half. **Rule 5 is not met for this change**, and the
  Playtester playing her place is what closes it.
- **This session never landed a shot of its own.** In the DEV arena the request is refused before
  anything is cast -- `REFUSED off-stand` (`Rules.OFF_STAND`), caught verbatim off `StateChanged`,
  because no drive had assigned the man a stand. The range mat is the door and the other session had
  the rig there. Written at the hard stop, per V280, not worked around.
- **The shotgun slug is 4/6, BELOW the >= 8/10 target**, and two of its shots produced no impact at
  all, unexplained.
- **The walk and trot rows (6/6 and 4/4) do not discriminate**: both were read at low drawn speeds
  where the whole demanded lead is under half a stud, so a build with no fix would pass them. RUN is
  the only row that carries the claim. That caveat is the measuring session's own.
- **NOT RUN at all**: the lever, the semi-auto, buckshot, and any HUNT animal (boar or deer in a
  drive). Every row is the range's own target.
- **The discriminating live row was taken at `97d67896`**, which carries the chained-provider shape,
  not the shipped `Weapon.addHistoryProvider` one. The suite is green over the new seam and the two
  answer the same question for a range shot, but the Playtester should re-run the run pace on the
  merged head.
