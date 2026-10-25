# Review request — Task 266b: PROVE TRUE HITS DECIDE SHOTS

Task: 266b
Round: 3
Base: 9acad458 (main, after #245 merged task 266)
Code commit: 1be4ddb4fdfa95cea0ddfc058bb4c8a4d42bb91b

```
[harness]  PASS: 34/34 checks @ 1be4ddb4fdfa95cea0ddfc058bb4c8a4d42bb91b (clean tree) scope=all
```

**`test2` is NOT required for this change and my round-1 line saying it was is wrong** (the
Reviewer's note): none of the changed files is in `TWO_PLAYER_PATHS` — `src/server/MatchBoot.server.luau`
is task 266's, not this task's — and `tools/agents.py` itself said *"0 needing two players"*. It was
run anyway at `886d170c` (`[harness2] PASS: 36/36 ... (clean tree)`) and costs nothing; it is simply
not evidence this change needs.

## PLAN (core quality protocol step 0) — committed before any `src/` edit

**(a) REAL LIFE.** A bullet goes where the sights were when the trigger broke, after its own flight
time. The rifle's .416 at 110–150 studs flies **0.044–0.060 s** (`Ballistics.timeToRange`), so an
animal at 24 studs/s is **1.1–1.4 studs** further on when the bullet arrives. **That — a fraction of
a body length — is the whole lead real shooting asks for at these ranges.**

**(b) MEASURED NOW**, with `HIT_CLAIM` **OFF**, `<runs-dir>/266shot.py`, Forest Test, task 266:

| shot | target | speed | range | server's impact, in the ANIMAL'S OWN frame | where that is |
|---|---|---|---|---|---|
| chest, no lead | `Boar59` | 24.2 | 148.7 | `-1.116, 0.504, **+3.942**` | the rump |
| chest, lead 1.01 | `Boar80` | 24.0 | 108.1 | `1.103, 0.570, **+4.138**` | the rump |

A chest spans about **-1.6 to -0.1** in that frame. So the bullet lands **about four studs behind
the chest** when the real lead is 1.1–1.4 — the error is roughly **three times** the honest lead,
and it is the thing Karen feels.

**AND THE SECOND READING, which is the one this task exists for:** with `HIT_CLAIM` **ON**, no
accepted claim has ever decided a shot. The Reviewer's own round-3 note puts it plainly: *"The
accepted path has never executed, anywhere… the first time the Director lights `HIT_CLAIM` for Karen
is the first execution of that branch in the project's history."* The server's counters would say so
in one number and **cannot be read from a probe** (a probe gets a fresh module cache), which is why
item 1 exists.

**(c) TARGET.**
1. **`claimsAccepted` moves.** Not a tolerance — a count. Three chest shots at a still animal must
   read `accepted +3`, and a forged claim must read `refusedClaimBy["claim-moved"] +1`.
2. **The zone hit is the chest**, on a running animal, aiming AT the chest. The claim's whole purpose
   is that what the shooter saw decides the hit, so the local Z must fall inside the chest's own box
   (about -1.6 to -0.1) instead of +3.9 to +4.1. **The target is the ZONE NAME, which is what Karen
   sees on the hit card** — not a stud figure.

**(d) LEVER.** The counters already exist and are already written; nothing reads them from outside:

```
$ grep -n "claimsAccepted\|refusedClaimBy\|claimWorstStuds" src/server/Weapon/init.luau
202:	claimsAccepted = 0,
204:	refusedClaimBy = {} :: { [string]: number },
212:	claimWorstStuds = 0,
769:	out.refusedClaimBy = table.clone(stats.refusedClaimBy)
1343:		stats.refusedClaimBy[reason] = (stats.refusedClaimBy[reason] or 0) + 1
1414:	stats.claimsAccepted += 1
1415:	stats.claimWorstStuds = math.max(stats.claimWorstStuds, (claim.point - serverPoint).Magnitude)
1744:			stats.refusedClaimBy[key] = (stats.refusedClaimBy[key] or 0) + 1
```

Read those by symbol, not by number. The writers are `judgeClaimFor` (the accept and refuse paths)
and `onFireRequest`'s shape gate. The lever for (c)1 is a **publisher** of those counters; the lever
for (c)2 is `Claim.simulate`'s own frame arithmetic in `src/client/Weapon/Claim.luau`.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument as (b) — `266shot.py`, which prints the
aim, the server's impact in the animal's own frame, and the client's mark — now with the counters
read beside every click through item 1's attribute.

**(f) WHAT I AM FIXING BEFORE I MEASURE, AND WHY IT IS NOT SCOPE CREEP.** Round 3's notes name a
defect that would make item 2 unreadable: in `Claim.simulate`, `blockAt` is the static hit's distance
from `pellet.position` while `hit.distance` is measured from `pellet.position - shift`, so
`hit.distance < blockAt` compares **two different rulers**, by up to `|shift|` (~1.27 studs at the
step cap). At the lead sizes this task is proving — a fraction of a stud — that can refuse a valid
led shot and read exactly like "the claim's frame is wrong", which is the dispatch's own item 3.
Fixing it first is what makes item 2's reading mean anything.


---

## Claims

1. **ITEM 1 IS MET AND IT IS WHAT MADE EVERYTHING ELSE POSSIBLE.** `Weapon.claimLine` formats the
   counters; `Weapon.publishClaimStats(isStudio?)` writes them to `ServerStorage.DHClaimStats`,
   **Studio only**. `isStudio` is a PARAMETER with a default because a spec always runs in Studio, so
   the live-server branch — the one that must write NOTHING — would otherwise be unreachable; both
   branches are asserted. Read live on Karen's path, e.g.
   `enabled=true claims=1 accepted=1 refused=0 ignored=0 worst=0.000/1.526 age=0.031..0.031/1 why=ok []`
   (a ROUND-1 reading: `claimLine` prints three worst fields since round 2's `claimWorstEndStuds`).
   *Verify:* `src/server/Weapon/init.luau` → `claimLine`, `publishClaimStats`, and the one call site
   in `onShotLanded`; `weapon_shot.spec` → `describe("the accepted claim and its counters")`.

2. **THE FEATURE WAS INERT A SECOND TIME, AND THE INSTRUMENTS NAMED THE CAUSE IN ONE LINE.** Every
   claim came back `claim-history`. Three readings, each decisive and each new:
   `why=no-sample` (the provider was wired and did not throw — it answered nil);
   `age=0.007..0.031` (the clock was never the problem);
   and then **`why=span live=64 at-oldest=1.877 at-newest=0.027`** — the claimed arrival was **27 ms
   NEWER than the ring's newest sample**, and always would be, because the ring is stamped once per
   `Runtime:step` while the claim is judged in the Weapon's own Heartbeat handler.
   *Verify:* `src/server/Boar/init.luau` → `Runtime:cframeAt`'s `historyWhy` branches and the
   `DHBoarHistory` write in `Runtime:step`.

3. **THE FIX IS AN INTERPOLATION, NOT AN EXTRAPOLATION, and that distinction is the justification.**
   `Boar.sampleAt(ring, count, at, now?, liveCFrame?)`: between the newest sample and the PRESENT the
   animal's position is known on both sides, so it is `Lerp`ed like any other instant. Past the
   present it is still a refusal, and `judgeClaim`'s `claim-future` refuses it a second time. Without
   the two optional arguments the function is exactly what it was — asserted.
   *Verify:* `boar_history.spec` → the four newest-edge cases, including "STILL REFUSES past the
   present" and "without the present it is exactly what it was".

4. **BEFORE AND AFTER, THE SAME INSTRUMENT, ON KAREN'S PATH:**

   | | reading |
   |---|---|
   | before | `claims=1 accepted=0 refused=1 why=no-sample [claim-history=1]` |
   | after | `claims=1 accepted=1 refused=0 why=ok []` |

   That `accepted=1` is **the first accepted claim in this project's history**, which is what the
   Reviewer's round-3 note said had never happened.

5. **ACCEPTANCE 2(1), A STILL ANIMAL: MET for the outcome Karen sees.** Three chest shots at one
   staged boar at 91 studs, locked by name: **all three** server impacts are
   `ZoneChest zone=chest`, and the mark reads `hit/chest` then `kill/chest` each time.
   **The frame `266b-acc1-still.png` is opened and described in `MEASURED.md` §3**: the hit card reads
   `HIT - .416` with the red mark on the boar silhouette's CHEST, and the kill line reads
   `Alhamdulilah824 MALE BOAR  chest  25 m  RIFLE`. Camera height is the player's eye on the stand.
   **`accepted` moved by 1 across those three, not 3**, and the reason is a staging artefact named in
   the ledger: the anchored animal's CLIENT replica still reported `v = 11.17` while the server had
   it still, so the client's own simulation shifted its segment and claimed nothing on two of them.

6. **ACCEPTANCE 2(3), A FORGED CLAIM: MET, LIVE, with a before and an after.** A probe sent a claim
   naming a real animal and a real zone with an honest flight time and a point **30 studs** from
   where the server's own history put it. Before: no claims. After:
   `claims=1 accepted=0 refused=1 ... why=ok [claim-moved=1]`. **`why=ok` is the part that matters**:
   the rewind ANSWERED, so the refusal is the check doing its job and not a missing history — a
   distinction that did not exist before item 1.
   *Verify:* `reviews/task-266b/probes/266b-forge.luau`; `MEASURED.md` §4.

7. **ACCEPTANCE 2(2), A RUNNING ANIMAL: NOT PROVEN, and this is the task's one open thing.** No shot
   was landed on an animal that was still moving at the trigger. Two claims on moving animals were
   refused **`claim-line`** — check 4, the server's own trajectory against the claimed point — and
   the instrument says why that is tight: **`claimWorstLineStuds = 1.526`** on a STILL animal, which
   is three quarters of the 2.0-stud budget spent before anything moves. That number is the next
   session's lever and it did not exist before this task.

8. **The ruler mismatch round 3 named is fixed.** In `Claim.simulate`, `blockAt` was measured from
   `pellet.position` and `hit.distance` from `pellet.position - shift` — two frames, up to ~1.27
   studs apart. Every distance is now along the bullet's own path, and `flightSeconds` and
   `distanceStuds` come from it.

9. **`Validator.judgeClaim`'s check numbers are the design's** (2–6; check 1 is the owner's), carried
   unfixed through rounds 2 and 3.

## What I could not verify (rule 8)

- **A running animal hit in the chest with an accepted claim.** Not obtained: in the one-drive
  shooter window the drive presented no animal above 4 studs/s inside 150 studs, and the two shots
  that were taken at moving animals had claims refused `claim-line`. **Nobody has seen this.**
- **A frame of the mark on the chest of a RUNNING animal: NOT OBTAINABLE this session**, for the
  same reason. The frame offered is a still animal and is described as one.
- **The in-gate ACCEPT case executes only when a player happens to hold a loaded single-pellet gun.**
  It did NOT run in the two runs at `886d170c`; it DID run at `6fc312f8` (and failed, which found
  check 4's defect) and at `739f4bcc` (and passed). Arming a gun inside the spec would make it
  unconditional and is queued rather than done, because granting and revoking a Tool on the harness
  player broke three client specs once (task 34).
- **`claimWorstLineStuds = 1.526` on a still animal is not explained.** It is measured, it is
  reported, and it is the thing to decompose next.

10. **THE REVIEWER COULD NOT SEE THIS TASK AT ALL, and that is fixed at the root.**
    `tools/agents.py review 266b` answered `REFUSED: task number must be digits`, and the no-argument
    path was no better — its folder scan is `task-(\d+)`, which would read `task-266b` as **266** and
    look for the request in `task-266/`, a different task whose `RESULT.md` is at round 3 and whose
    next request would be refused as `Round: 4`. So a task numbered the way the Director numbers
    follow-ups (`266a`, `266b`, `260b`, `263a` — they are all over `TASKS.md`) could be built, gated
    and never reviewed. `TASK_PATTERN` is digits plus one optional lower-case letter, used by
    `resolve_task`, the folder scan, the `Task:` line check and `cmd_architect`; the task is carried
    as a string and nothing arithmetic was ever done with it. The round counter is per folder, so
    `266b` gets its own count starting at 1.
    *Verify:* `tools/agents.py` → `TASK_PATTERN` and its four uses; `selftest`'s thirteen cases,
    including that the folder scan reads `task-266b` as `266b` and not as `266`.

11. **CHECK 4 WAS MEASURING THE WRONG THING, and the in-gate ACCEPT case is what caught it.** That
    case ran for the first time in the gate at `6fc312f8` — a player happened to be holding a rifle —
    and FAILED: `accepted 0 -> 0, refusedClaimBy [claim-line=1]`, in a spec where the spec controls
    every number. `judgeClaim` was handed the trajectory's position at exactly `claim.flightSeconds`,
    which conflates ACROSS-track error (the aiming disagreement the check exists for) with
    ALONG-track error (sub-step granularity plus the bore's own ~5-stud set-back from the camera).
    The design's words are *"the server's own trajectory ... PASSES within LINE_TOLERANCE_STUDS"*, so
    the trajectory is now walked and the CLOSEST APPROACH kept — a perpendicular distance, which is
    what "under half a boar's trunk" was chosen to mean. `Validator.judgeClaim` is unchanged; it is
    handed a better `trajectoryPoint`.
    *Verify:* `src/server/Weapon/init.luau` → `judgeClaimFor`'s trajectory walk; commit `886d170c`.

12. **AND THE RE-MEASUREMENT SAYS THE REMAINING 1.5 STUDS IS NOT ALONG-TRACK.** After the fix, on
    the same staged still boar at 91 studs: `accepted=1 ... worst=0.000/1.527`. The line figure moved
    by 0.001. **So the disagreement between the client's claimed point and the server's own
    trajectory is genuinely ACROSS-track — about 0.96° at that range — and it is unexplained.** It is
    inside the 2.0-stud tolerance, so honest claims are accepted; it is three quarters of the budget,
    which is why a moving animal's claim falls out of it. That number is this task's one open lever
    and it is queued.


---

## ROUND 2 — the three blocking findings, all of them right, two of them mine to withdraw

13. **FINDING 1 IS FIXED, AND THE CONCLUSION I DREW FROM THE BROKEN METER IS WITHDRAWN.**
    `claimWorstLineStuds` was written from the trajectory's END point while check 4 is handed the
    CLOSEST APPROACH, so the published number was a quantity no check uses — and claim 12's
    *"the line figure moved by 0.001, so the disagreement is genuinely ACROSS-track"* was drawn from
    a line this task never touched. **Claims 7 and 12 are withdrawn as written.** The meter is
    `closestStuds` now, and the endpoint figure is kept beside it as `claimWorstEndStuds`, because
    the GAP between the two IS the along-track error and a reader who sees only one cannot tell
    which kind of disagreement he has.

    **AND THE CORRECTED METER CHANGES THE ANSWER.** In the gate at `739f4bcc`, with a rifle in the
    harness player's hands, the accept case reports
    **`accepted 0 -> 1, worst 0.000/0.027, refusedClaimBy []`** — the across-track distance between
    the server's own trajectory and the claimed point is **0.027 studs**, not 1.5. So the 2.0-stud
    budget is barely touched, and the `claim-line` refusals on moving animals are **not** explained
    by a large across-track error. What that leaves is still open and is queued, with the honest
    statement that the old 1.5 figure was along-track contamination and nobody has yet re-measured
    the live case with the right meter.
    *Verify:* `src/server/Weapon/init.luau` → the two `math.max` lines after the trajectory walk;
    the gate log's note line.

14. **FINDING 2: THE "RULER MISMATCH" DOES NOT EXIST, and I repeated round 3's note without
    checking the arithmetic.** A cast returns a point ON the ray it was given, so
    `hit.position = (pellet.position - shift) + segment.Unit * hit.distance`, and therefore
    `(hit.position + shift - pellet.position).Magnitude` is `hit.distance` — identically, to
    floating point, for the real `Claim.only` and for the spec's stub. `blockAt` was always on the
    same ruler. **Claim 8 and PLAN (f) are withdrawn**; the comment now states the identity instead
    of inventing a defect, and `bestAlong` is kept only because its name says which frame it is in.
    No case can distinguish before from after and none is offered.

15. **FINDING 3 WAS A REGRESSION I INTRODUCED, and it is worse than what it replaced.**
    `resolve_task`'s filesystem fallback became `max` over STRINGS when the task became a string,
    and `max` over strings is lexicographic: `reviews/task-90 … task-99/REQUEST.md` all exist, so it
    answered `"99"` for every repository state — reviewing the WRONG TASK, which is precisely the
    failure claim 10 says the lettered-task fix closes. Ordered by the numeric part now, with a
    selftest case over `90/99/266/266b`.
    *Verify:* `tools/agents.py` → `resolve_task`'s `newest`; `selftest` → "the newest of
    90/99/266/266b is 266b".

16. **THE ACCEPTED PATH NOW EXECUTES IN THE GATE.** `weapon_shot.spec`'s accept case ran at
    `6fc312f8` (and FAILED, which is what found finding 1's sibling defect in check 4), and at
    `739f4bcc` it passes: one report on the claimed part, `pellets = 1`, the zone off the part's own
    `HitZone`, and `claimsAccepted + 1`. It still degrades to a note when no player holds a loaded
    single-pellet gun, and the request says so rather than claiming the wiring is covered
    unconditionally.


---

## ROUND 3 — round 2's one blocking finding, and it was right

17. **THE GUARD ASSERTED A COPY OF ITSELF.** The selftest case written for round 1's finding 3
    re-implemented the ordering inline and checked it against itself, so dropping `key=` from
    `resolve_task`'s `max` left every case green and the regression back — the same shape of fault
    round 1 found, one level up. `task_order` is a named production function now; `resolve_task`
    calls it, `selftest` calls **that one**, and a second case asserts the order itself
    (`266b > 266 > 99`). Delete the ordering and both fail.
    *Verify:* `tools/agents.py` → `task_order`, its use in `resolve_task`, and the two selftest cases.

18. **Three of round 2's notes are closed, because each was a claim resting on nothing.**
    (a) `weapon_shot.spec`'s accept case now asserts
    `claimWorstLineStuds <= CLAIM.LINE_TOLERANCE_STUDS` — the cheapest real guard on round 1
    finding 1's fix: swap the closest approach back for the trajectory's end point and it fails,
    because that figure carries the bore's own ~5-stud set-back. (b) the `claimLine` case asserts
    `ignored=` and **all three** worst fields, so dropping one no longer passes on a prefix match.
    (c) the "could not verify" bullet that contradicted claim 16 now names the three runs and what
    each did.

19. **`reviews/task-266b/MEASURED.md` is committed**, so the five citations that pointed at an
    uncommitted ledger now resolve inside the repo: every pasted reading, the four instruments in
    the order they were built, the frame's description, the staging artefact behind `accepted +1`
    instead of `+3`, and the restore of the place.

**Still NOT PROVEN, and it is the plan's own item 2:** a RUNNING animal hit in the chest with an
accepted claim. Nobody has seen it.
