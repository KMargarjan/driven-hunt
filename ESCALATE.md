## 2026-10-28, Task 305d -- two of the three dispatch items are refuted; a third defect was found

Every time below is a `date -u` reading. Measurements: `reviews/task-305d/MEASURED.md`.

**1. THE WALK DID NOT REGRESS.** `ray.luau` in Karen's place at 4.50 studs/s: a ray from the
shooter's eye through the DRAWN chest centre, translated by the rewind shift exactly as
`Weapon.Rewind` does, hits a zone part on **189 of 189 frames**. Real `FireRequest`s at that aim
read **4/5 on `5c444dbe`** and **4/5 on the fix** -- which is 305b's own 4/5. The Playtester's 1/5
is not reproducible on this build by geometry or by shots. **L-123 called this exactly** and it was
right: the instrument, not the gait code, was the first suspect.

**2. THE SEMI-AUTO IS NOT DIFFERENT FROM THE SHOTGUN.** `SemiAuto.CONFIG` holds `Shotgun.CONFIG`'s
own ammunition tables by reference; both read `muzzle=1752, t(125)=0.0763 s, lead=1.83 studs`. Back
to back, same rig, same session: on `5c444dbe` semiauto **1/5** and shotgun **4/5** at RUN, but at a
STANDING boar **2/5** and **3/5**, and on the fix **3/5** and **3/5**. The nose TIP is a ~50% aim
for every gun, because it is a point ON the box surface. The 0/3 on record is a five-shot sample of
a coin flip, not a broken gun.

**3. THE REWIND'S POSE PAIRING IS REAL AND SMALL.** The escalation assumed the client draws a
0.18 s-old pose. It does not: the box pose is a replicated PROPERTY, and a server-stamped attribute
read back on the client gives **0.0372-0.0797 s, mean 0.0556** over 234 samples. Only the trunk
POSITION carries the 0.18 s interpolation buffer. So the mismatch is the pose travel over 0.056 s:
**0.23-0.31 studs at RUN**, against boxes 0.32-1.76 studs across. Worth knowing, not worth a fix
ahead of anything else.

**4. WHAT WAS ACTUALLY WRONG, and is fixed in `472b8c68`:** `Body.gaitRig` picked each box's bone by
plain nearest rest distance over all 40 bones, and two boxes sit on the boar's BACK a stud above the
spine -- so **`ZoneBody1`, the slab over the shoulders, was skinned to `ear_1.L`** (d = 0.534, beating
`Neck` at 0.693) and `ZoneBody2` to `hip_1_f.R`. A paired bone moves with one side only. That box is
0.12 studs tall and was travelling **0.420 studs per replication lag at a run**, 3.5x its own height.
Now `Neck` and `Spine_01`, and 0.268 / 0.141.

**FOR THE DIRECTOR:**

a. **The click thresholds in the dispatch cannot be met by a Builder rig and I have not claimed
   them.** On the SAME build, the Playtester's real clicks read rifle RUN nose 9/10 where this
   `FireRequest` rig reads 4/10 and 305c's rig read 6/10. The rig has no screen-centre gate. Every
   count in `MEASURED.md` is used only as a before/after pair on one instrument. **The thresholds
   need the Playtester**, as the dispatch says.
b. **The red deer is NOT PROVEN.** `U8` reads 0/5 at the stag's nose with no before from this
   instrument. `carrier2.luau` (instance facts only) says the stag's TRUNK boxes are all on
   spine/neck bones, so the rule changes nothing there -- but its head cluster is inside that
   detector's blind spot, and `rig2.luau` cannot help because a fresh module cache returns the
   BOAR's zone table for `kind="stag"`. A deer-side reading needs a probe that can get the stag's
   own geometry.
c. **I cleared ONE flag override in DEV, and only DEV:** `DHFlag_RANGE=true` was set there and the
   harness refuses to start with any override. `python tools/flags.py clear` (DEV), recorded here so
   it can be put back. **Karen's Forest Test was never cleared** -- its thirteen rows were read
   before and after and are identical.
d. **The Forest Test's Rojo panel was switched from :34873 to :34874** to serve this build from
   `driven-hunt-294`, per the dispatch, and is **switched back to :34873 at the end of this
   session**. `driven-hunt-karen` was never touched. Panel shots:
   `<runs-dir>/305d-conn-crop.png` (34874) and `<runs-dir>/evidence/port-34873-*.png`.
e. **`Range.gapStuds` still misleads and three sessions have now leaned on it.** It measures the
   ray's END POINT against the target's present X, so a shot that passes a hair wide carries on to
   the berm and prints the berm's offset: that is where "19.3 m behind" and "2.8 m ahead" come from.
   305b queued it; it is still open and it is still the number the Playtester and Karen read.

## 2026-10-28, Task 305c -- the cause is found and fixed; the CLICK INSTRUMENT disagrees with itself

**The cause is measured and the fix is proved geometrically on the moving animal.** The zone boxes
were welded at the offsets task 284 fitted to the mesh's REST pose, and a skinned MeshPart never
raycasts its deformed pose -- so at a run the DRAWN boar sits 0.14-0.65 studs under its rig (the
snout 0.28-0.64 in one run clip and **1.65-1.82** in the head-down one) and the drawn nose was
inside a zone part on **0 of 83-99 frames**. With each box skinned to its nearest bone it is
**86/94 server-side**, with no box resized, and air ahead of the animal still misses.
Numbers: `reviews/task-305c/MEASURED.md`.

**What is NOT proved, and why the Director has to decide:**

1. **The click rig disagrees with its own earlier self.** `reviews/task-305b/MEASURED.md` reads
   **9/10** for drawn chest + `Ballistics.leadStuds` at RUN. The same aim rule, in her place, in
   this session, on the fixed build, reads **4/10**. And 305b's OWN rig
   (`<runs-dir>/305c/z-run-rifle-nose.luau`, changed only in the aim point) reports
   `testedAt-firedAt` **-0.078..-0.095** where 305b measured **-0.126** on the same shipped
   constants. Until that control is restored, **no click count from this session is evidence of the
   game's hit rate**, mine included: rifle RUN nose = 6/10 against the 8/10 asked, and I am not
   claiming it as the game's number. Candidate (b) of the dispatch -- "the rewind over- or
   under-shoots" -- is therefore **NOT ruled out**, and it is now the first thing to measure.
2. **Slug, semi-auto, lever and the red deer at the nose were not fired at all.** The session went
   on finding the cause and three geometry cycles.
3. **`DHFlag_ZONES_FOLLOW_GAIT=true` IS STILL SET ON KAREN'S FOREST TEST**, on purpose, so the
   Playtester can re-run the proof without a Director round trip. Her eleven other overrides were
   read before and are untouched; `flags.py --place forest clear` was never run. If the Director
   wants her place back at the shipped build: `python tools/flags.py --place forest set
   ZONES_FOLLOW_GAIT off` in **Edit**, and nothing else.
4. **The Forest Test worktree is left at the code commit.** `driven-hunt-karen` has `src/` and
   `tests/` checked out from `d375ba70` path-wise (no branch switch, so `rojo serve` :34873 was never
   at risk). `git -C driven-hunt-karen checkout a627663d -- src tests` puts it back.
5. **A harness fault, per rule 6.** With a SECOND Studio in Play, `python tools/studio_mcp.py test`
   fails its input replay with `UserMouseInputTool.SendUserInput ... Target is not reachable
   (DMN_ID_PLAYCLIENT) ... Sender: DMN_ID_STANDALONE` -- four consecutive runs, three different
   commits, and it reads exactly like a code defect. Stopping the other Studio's Play made the same
   commit read 34/34 at once. Worth a guard in the harness: refuse, or name the other Studio.

6. **The Reviewer's biggest note, and I agree with it.** `AIM_REWIND` translates the ray and casts
   it against PRESENT geometry, so with both flags lit the rewound test pairs a 0.18 s-old TRUNK
   POSITION with a PRESENT-pose BOX -- an error of the same order (0.3-1.8 studs) as the one this
   task fixes, and in Karen's place both flags are on. Measure that first, after the click control.

## 2026-10-28, Task 305b -- the premise is refuted, and four things are the Director's

**The dispatch said "as if no rewind" in her place. It is not true, and the numbers are in
`reviews/task-305b/MEASURED.md`.** In Karen's Forest Test, on `2b77716e`, with her own overrides
untouched: the rewind runs (`DH305Rewind` = `why=rewound rewind=0.181 cands=1 hit=true`), ownership
is pinned to the server, the candidate is found, the ring has no misses, and the effective look-back
(0.182-0.190) matches her client's drawn lag (0.185-0.205).

**The 1/10 was the aim rule, not the game.** Same build, same rig, same lane, back to back:
drawn chest + `Ballistics.leadStuds` = **9/10** at RUN; drawn chest + **zero lead** = **0/10**.
The Playtester's brief specified zero lead. `src/client/Weapon/Input.luau` sends the camera's own
`LookVector`, so a real click and the rig send the same ray.

Reviewer: **PASS round 2** (`reviews/task-305b/RESULT.md`), one round-1 finding fixed.

**For the Director:**
1. **Is the required lead right?** The game demands exactly `Ballistics.leadStuds` -- 1.2 studs at
   125 studs on a 24 studs/s boar. Karen's *"I need to aim in free space"* is that lead. Real
   ballistics is her own standing ask; whether a boar's CHEST zone should be wide enough that the
   ballistic lead still lands in it is a FEEL decision and is hers.
2. **The range board's `MISS GAP` misleads.** It reads `1.3 m behind` for a shot that missed by
   1.2 studs, because it measures against the server's PRESENT position -- always one view lag
   ahead of what the shooter drew. It is the instrument the Playtester and Karen both read. Queued
   as 305c; worth its own small task.
3. **The flag.** `AIM_REWIND` still ships OFF, so this commit changes nothing Karen can judge.
   Round 3 of task 305 already queued an Architect run on `docs/design/ballistics.md` section 1.3
   before it is lit; that precondition is unchanged and this task did not satisfy it.
4. **The Forest Test worktree** (`<desktop>/driven-hunt-294`, Rojo :34874) was re-synced by this
   Builder session five times to measure, and is left at the reviewed **code commit `ea72ffc9`**, so the
   Playtester can re-run on this build without a resync. The Director owns that worktree; say if it
   should be put back to `main` instead.

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

**I have fixed both in the tree and have NOT reviewed the fix** (the answers now RISE, 6 then 7, so
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

## Task 305 round 3: Director authorisation

**Transcribed verbatim from the Director's dispatch of 2026-10-28 (the Director's words, not the
Builder's):**

> [DIRECTOR -> BUILDER] TASK 305 ROUND 3 -- AUTHORISED by the Director, 2026-10-28 11:50 UTC
> (MAX_ROUNDS 3; this is round 3, not a 4th). Transcribe this paragraph verbatim into ESCALATE.md
> under a heading "Task 305 round 3: Director authorisation", marked as the Director's, in your
> first commit. Same branch task-305-aim-what-you-see, same reviews/task-305/ (Round: 3).

**OUTCOME, 2026-10-28 12:12 UTC: round 3 is a PASS.** `reviews/task-305/RESULT.md` line 1 reads
`PASS (items 3, 4, 5, 6 NOT PROVEN)` at `5e08263a`, with twelve non-blocking notes queued as
TASKS.md 305a. Both round-2 cases were shown RED against a broken producer
(`[harness] FAIL: 32/34 @ 9a996b38`, naming `weapon_rewind.spec:68` and `:113` and nothing else)
before being called fixed, and the restored commit is
`[harness] PASS: 34/34 checks @ 71475766275fc7aa36da3232c324e7e780b6f403 (clean tree) scope=all`.

**AND THE FLAG QUESTION THE DISPATCH ASKED IS ANSWERED: case (b) is 0/10 at run, 1/10 at trot and
0/10 at walk, so it is NOT >= 8/10 at any pace and `AIM_REWIND` must NOT stay dark.** The same rig,
the same session, one override changed, reads **7/10** with the rewind on. With it off the impacts
land ~1.4 studs BEHIND where the client DREW the animal; with it on `impact-aim` is within +-0.5
studs on 5 of 7. **7/10 is itself one shot below this task's own >= 8/10 target**, and the shotgun
slug stands at 4/6 -- both said on the record rather than rounded up. Decisions 2, 3, 4 and 5 below
are still the Director's.

So section 0's request is granted. This round does three things and nothing else: make each of the
two round-2 cases FAIL when its producer is broken (red run, then green), MEASURE case (b) for real
(ownership fix on, `AIM_REWIND` off, rifle at run then trot then walk, refilling ammo), and record it
in `MEASURED.md`. The remaining notes stay queued as 305a.

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

## 2b. SESSION `9d5b3ff8` HAS ENDED (confirmed ~11:43 UTC: its inbox is gone, `ListAgents` no longer
lists it). So decision 2's missing number -- a hit rate for the ownership-only build, case (b) --
will NOT arrive from it. It is reported to the Director by that session separately; its evidence is
`reviews/task-305/MEASURED.md`, committed on this branch.

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
