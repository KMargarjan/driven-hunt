# Task 256 part 1: real-life shooting -- the lead with the ping taken out, and the hit mark on the animal

Task: 256
Round: 2
Base: 4ad1af8c (main)
Code commit: 9a3e8642dabae84840403a230c88dfea04dedf9d

Harness, clean tree, full suite:

```
[harness] PASS: 34/34 checks @ 9a3e8642dabae84840403a230c88dfea04dedf9d (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched, and `tools/agents.py` said so
itself in round 1 -- *"6 code file(s) changed, 0 needing two players"*. No `src/*/Match/`, no
`src/shared/Drive/`, no `Role.luau`, no `match_*`/`outfit_client`/`zz_tie`/`zz_drive_boundary` spec.
Weapon work takes the one-player line for the review round and for the PR to main
(Director, 2026-10-03).

**Why the code commit moved from round 1's `adc22d8e` to `9a3e8642`, which is a PAPERWORK point
worth one line:** the two Architect runs below amended `docs/design/shotgun.md` and
`docs/design/ballistics.md`, and `is_paperwork` in `tools/agents.py` does **not** list
`docs/design/` -- only `reviews/`, `ESCALATE.md`, `TASKS.md`, `PLAYTEST.md` and
`docs/architecture/audit-NNN.md`. So leaving the round-1 line in place would have made
`.agent-evidence/paperwork-after-code-commit.txt` read NOT OK and would have been a blocking finding
by git workflow step 4. The harness was therefore re-run at the commit that INCLUDES both design
amendments; nothing under `src/`, `tests/` or `tools/` changed between `adc22d8e` and `9a3e8642`, so
the suite result is identical and the line now covers HEAD. Only this request follows it.

## What changed, and why it is smaller than the dispatch

The dispatch asks for six things. **Four were already built and shipped**, so this task MEASURED
them and changed code for the two that were wrong. Split as the dispatch allows: **part 1 is items
1, 2, 5 and 6**; items 3 (the true scope) and 4 (the kill zones) are part 2, a separate session
after part 1 merges (Director, 2026-10-24).

Note: `docs/research/2026-10-24-real-shooting.md` (sections 0 and 11 are the map).

| item | verdict | code? |
|---|---|---|
| 1 time of flight | built (task 185). **Its lag compensation was missing** | **yes** |
| 2 no drop | built (`GRAVITY_SCALE`, 189/224); measured at <= 1.6 cm inside 60 m | no |
| 3 true scope | part 2. Two causes ruled out by measurement (note section 6) | no |
| 4 kill zones | part 2. Audited against the doctrine (note section 7) | no |
| 5 hit mark | **wrong: the dust was world-space while the animal ran** | **yes** |
| 6 slug vs buck | built (204/244); measured against the real cartridges | no |

## Claims

**1. The lead carried the player's ping, and nothing in `src/` knew about latency.**
Verify: on the BASE commit, grep `src/` for `GetNetworkPing`, `latency`, `ping` -- no hit in the
weapon system. The server launched at the request's arrival and `Flight.advance` resolves against
live positions, so the required lead was `tof*v + roundTrip*v`. Note section 5.1 derives it; 5.3
measures it at **64 cm on a sprinting boar at 60 ms against a true lead of 91 cm at 60 m**.

**2. It is fixed by forward prediction, and rewinding is refused with a reason.**
Verify: `Shotgun.CONFIG.FLIGHT_CATCHUP_MAX_SECONDS` / `FLIGHT_CATCHUP_PING_FACTOR`,
`Weapon.catchUpFor`, `Flight.launch`'s fourth argument, `live.catchUp` spent in `Flight.advance`,
and the new pure `Flight.substeps`. Valve's hitbox rewind is refused **by name** -- a per-animal
position history is a second store of a fact `Boar.Body` owns. No new mechanism: `Flight.advance`
already steps over an injected `dt` through an injected segment cast, so the catch-up is that step
taken once more.

**3. The catch-up is bounded, spent once, and cannot tunnel.**
Verify: `weapon_hits.spec`, `describe("lag compensation")` -- "IS CLAMPED AT THE CAP, and a negative
or a NaN is zero" (`-1`, `0/0` and `nil` all give 0; clamped at the one door in `Flight.launch`),
"IS SPENT ONCE, however many frames the shot lives for" (first frame 4 casts, second 1), "CANNOT
TUNNEL: a wall between the muzzle and the animal still stops the caught-up shot", and "A SHOT THE
GLOBAL CAP REFUSED IS GRANTED NOTHING".

**4. Zero is bit-for-bit today's flight, so the failure mode is "yesterday's game".**
Verify: "ZERO IS BIT-FOR-BIT TODAY'S FLIGHT" traces every cast's origin and direction for 30 frames
with `nil` and with `0` and compares to 1e-9. Every call site written before this task passes
nothing.

**5. THE CORE CLAIM, measured live: the TRUE lead now hits what it used to miss.**
Verify: harness notes from the run above --
```
[catchup] rifle at 357 studs (100 m): true lead 5.6 st; 100 ms round trip costs 3.8 st, so the true lead MISSED; with the catch-up it HIT
[catchup] rifle at 536 studs (150 m): ... MISSED; with the catch-up it HIT
[catchup] rifle at 714 studs (200 m): ... MISSED; with the catch-up it HIT
```
Same aim, same animal, same stepper; the only difference is the fourth argument.

**6. The limit was found by MEASUREMENT, not reasoning, and is stated rather than hidden.**
Round 1's first spec asserted a hit at every range and **failed** (expected 1, got 0): forward
prediction can only give back time the bullet actually spends in the air.
Verify: "CANNOT GIVE BACK MORE PING THAN THE BULLET SPENDS IN THE AIR", and its note:
```
[catchup] LIMIT at 179 studs (50 m): flight 71 ms is SHORTER than the 100 ms round trip, so the catch-up cuts the miss from 4.26 to 1.73 studs and cannot clear it
```
Note section 5.5 is the table. The core case asserts `timeToRange > roundTrip` at its three ranges,
so it cannot silently start depending on the limit.

**7. ROUND 1's HIT-MARK FIX DID NOT MOVE THE PICTURE, AND THE REVIEWER WAS RIGHT. It does now.**
This is the round's most important claim and the finding was correct in full. Round 1 parented the
`Attachment` to the struck part, which moves only where the NEXT grain would be BORN:
`Effects.puff` emits all seven in ONE burst (`Enabled = false`, then `Emit(COUNT)`), and a
`ParticleEmitter` simulates emitted particles in **world** space unless `LockedToPart` is true --
which defaults to false. So the attachment rode the boar and the dust still hung in the air at the
point the anchored host had used.
Verify: `Effects.puff`'s `attachTo` branch now sets `emitter.LockedToPart = true`, and
`weapon_client.spec`'s riding case asserts it. Note section 8.2 records the whole mistake, including
that it is `docs/PROJECT_CONTEXT.md`'s own founding failure mode -- *"things measured correct and
looked wrong"* -- reproduced in the task whose subject is a thing Karen sees.

**8. The assertions that could not fail are gone, and the ones that replaced them can.**
Also the Reviewer's finding 2, correct. `attachment.WorldPosition` after a move and
`WorldCFrame.UpVector` after a turn are properties of `Attachment` itself (`WorldCFrame` **is**
`parent.CFrame * attachment.CFrame`), so they held for any attachment on any part.
Verify: the riding case now asserts `emitter.LockedToPart == true`, the static case asserts it is
`false` (world space, the picture the ground has drawn since task 249) -- so the two paths cannot
drift into one answer -- and the harness note no longer claims "the mark followed" when only the
attachment did. The creation-time `UpVector == normal` assertion is KEPT: it really does test the
`ToObjectSpace` composition, and the Reviewer said so.

**9. The hit mark was world-anchored and the animal ran out from under it.**
Verify: on the BASE commit, `Effects.puff` sets `host.Anchored = true` into
`Workspace.WeaponEffects`. With `IMPACT.LIFETIME` 0.22-0.38 s and `SPRINT_SPEED` 38 studs/s that is
**11.4 studs -- two of the animal's own 5.5-stud `BODY_SIZE` -- before the grains fade** (note 8.1
tabulates walk/run/sprint). Harness note:
```
[mark] body moved 11.4 studs; the emitter followed to within 0.0000 studs AND its grains are LockedToPart, so the dust rides the animal (before task 256 the puff was an anchored world point and was left 11.4 studs behind)
```
The server sends only the Instance (a fourth `parts` array on `ShotLanded`, `false` as the
index-alignment placeholder for the same reason task 249's `normals` uses `Vector3.zero`); the
offset is derived on the client, because the client's own copy of where the animal is NOW is the
frame the player can see. `Effects.ridesWith` is the one decision and says out loud that it rides
ANY unanchored BasePart, which is the right answer for all of them.

**10. FINDING 3 IS RESOLVED BY THE DIRECTOR AND BOTH DESIGNS NOW MATCH THE CODE.**
The Reviewer was right that the shipped mechanism contradicted both designs and neither was amended.
The Builder may not write `docs/design/`, so it was escalated; the Director decided **option (b)**
on 2026-10-24 and the decision is carried verbatim in `reviews/task-256/BRIEF.md` section 1:
forward prediction by the shooter's measured one-way delay is **ALLOWED because it preserves the
lead**; what the designs forbid and still forbid is **REWINDING targets**, which deletes it.
Verify, and note these are **two** runs because `cmd_architect` writes exactly one
`docs/design/<system>.md` per invocation:
- `tools/architect.ps1 design shotgun --task 256` -> **PASS**. `docs/design/shotgun.md` gains
  section 11.1, which quotes the superseded paragraph in full, credits it for calling both the
  complaint and the number (~3.8 studs at 100 ms RTT -- which note 5.1 derived independently and
  got the same answer), and sets out the owner. Plus sources J, K (Valve, mechanism REFUSED) and L
  (Unreal, ADOPTED).
- `tools/architect.ps1 design ballistics --task 256` -> **PASS**. Section 1.2's blanket
  *"No lag compensation"* becomes **"No REWINDING of targets, and no position history of one"**, so
  the prohibition keeps its force and its reason; source B is retitled *"the REWIND, named and
  deliberately not adopted"*; sections 2.2 and 5.1 are new. **It also fixes the two stale module
  contracts from the round-1 notes**: `Flight:launch`'s fourth argument, `Flight.stats`'s sixth
  field, and `Flight.substeps` documented as new, pure and exported.
- Both verdicts were **PASS**; the committed `ARCH_RESULT.md` holds the ballistics one, because the
  second run overwrites the first. The shotgun verdict is in git history at commit `0569a5bb`, which
  is why run 1 was committed before run 2 started.
- Each amendment was checked for truncation, since `cmd_architect` overwrites the whole file:
  shotgun 1548 -> 1834 lines, ballistics 1018 -> 1536, and a diff of the heading lists shows **no
  original heading lost** in either (two renamed in ballistics, the rest additions).

## What I could NOT verify (rule 8)

1. **The live size of the lag correction, on a real server.** A loopback Studio session reads a ping
   of only **0.37-0.51 ms per shot** -- measured, printed by the harness
   (`[catchup] loopback Studio: 0.0015 s granted over 4 shot(s) = 0.37 ms each (= 0.014 studs ...)`)
   -- so the compensation does fire here but is far too small to tell a `FLIGHT_CATCHUP_PING_FACTOR`
   of 1.0 from one of 2.0. **The engine's docs say only "the network ping in seconds" and do not
   state whether that is the round trip or one way**, while section 5.1 shows the correction wanted
   is the round trip. Hence the data row, shipped at the conservative 1.0, awaiting a real server.
   Both readings are reachable by parameter and the spec drives both.
   *(This corrected a claim of mine: round 1 asserted the value was exactly 0 on the premise that
   Studio "has no network". The guard failed on its own author at 0.0017 s, which is how the real
   figure is known. It is now a per-shot bound and the three places I had written "reads ~0" are
   fixed.)*
2. **No screenshot.** The change is a 0.22-0.38 s particle puff on a possibly-sprinting animal. The
   specific risk a frame would catch -- grains firing INTO the body, invisible -- is what the
   creation-time `UpVector == normal` assertion and the `LockedToPart` assertions were added for,
   and they settle it exactly where a frame could not. **This is the weakest part of the evidence
   and I am naming it as such.** A frame needs the Forest Test; the Director's dispatch for this
   step says it is closed and not needed, and part 2 carries the real-click proof.
3. **Whether the slug's single pitch-shifted sample reads as a "different sound"** (item 6). Level
   and pitch differ per load and are measured
   (`task204 voice: buck volume=0.950 pitch=1.000 | slug volume=1.188 pitch=0.820`), but it is ONE
   recording -- the shotgun row has no `SOUND` block. Karen's ear decides; a second sample is an
   upload and therefore the Director's.
4. **No real-click lead proof.** The dispatch's own CLICK PROOF line for this step says N/A, and the
   Learning Agent was right that no lead-fire + OS-click route exists on disk. The lead is proved
   against the real stepper at three ranges (claim 5) and its limit at a fourth (claim 6). Part 2
   carries the route.
5. **Items 3 and 4 are not done** -- part 2 by the Director's split, not started here. The note
   records what is already ruled out for each so part 2 does not re-derive it.
