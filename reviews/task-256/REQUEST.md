# Task 256 part 1: real-life shooting -- the lead with the ping taken out, and the hit mark on the animal

Task: 256
Round: 1
Base: 4ad1af8c (main)
Code commit: adc22d8e1c1a72cec58b0e5b2ef388fca014c237

Harness, clean tree, full suite:

```
[harness] PASS: 34/34 checks @ adc22d8e1c1a72cec58b0e5b2ef388fca014c237 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched. `git diff --name-only
origin/main...HEAD` is `TASKS.md`, `docs/research/*` and the five weapon files below -- no
`src/*/Match/`, no `src/shared/Drive/`, no `Role.luau`, no `match_*`/`outfit_client`/`zz_tie`/
`zz_drive_boundary` spec. This is weapon work, which the 2026-10-03 decision puts on the one-player
line for the review round AND for the PR to main.

## What changed, and why it is smaller than the dispatch

The dispatch asks for six things. **The research note's headline is that four of them were already
built and shipped**, so this task MEASURED them instead of rebuilding them, and changed code for the
two that were actually wrong. Split as the dispatch allows: **part 1 is items 1, 2, 5 and 6**; part 2
is item 3 (the live scope measurement) and item 4 (the kill-zone re-tune).

Note: `docs/research/2026-10-24-real-shooting.md` (sections 0 and 11 are the map).

| item | verdict | code? |
|---|---|---|
| 1 time of flight | built (task 185). **Its lag compensation was missing** | **yes** |
| 2 no drop | built (`GRAVITY_SCALE`, 189/224); measured at <= 1.6 cm inside 60 m | no |
| 3 true scope | part 2. Two causes ruled out by measurement (note section 6) | no |
| 4 kill zones | part 2. Audited against the doctrine (note section 7) | no |
| 5 hit mark | **wrong: the puff was `Anchored` in the world** | **yes** |
| 6 slug vs buck | built (204/244); measured against the real cartridges | no |

## Claims

**1. The lead carried the player's ping, and nothing in `src/` knew about latency.**
Verify: grep `src/` for `GetNetworkPing`, `latency`, `ping` on the BASE commit -- no hit in the
weapon system. `Weapon.onFireRequest` launched at the request's arrival and `Flight.advance`
resolves against live positions, so the required lead was `tof*v + roundTrip*v`. Note section 5.1
derives it; 5.3 measures it at **64 cm on a sprinting boar at 60 ms against a true lead of 91 cm at
60 m**.

**2. It is fixed by forward prediction, and Valve's rewind is refused with a reason.**
Verify: `Shotgun.CONFIG.FLIGHT_CATCHUP_MAX_SECONDS` / `FLIGHT_CATCHUP_PING_FACTOR`,
`Weapon.catchUpFor`, `Flight.launch`'s fourth argument, and `live.catchUp` spent in
`Flight.advance`. The note's source C is Unreal's forward-predicted projectile; source B (Valve) is
refused **by name** because a per-animal position history is a second store of a fact `Boar.Body`
owns. No new mechanism: `Flight.advance` already steps over an injected `dt` through an injected
segment cast, so the catch-up is that step taken once more.

**3. The catch-up is bounded, spent once, and cannot tunnel.**
Verify: `weapon_hits.spec`, `describe("lag compensation")` -- "IS CLAMPED AT THE CAP, and a negative
or a NaN is zero" (clamped at the one door in `Flight.launch`; `-1`, `0/0` and `nil` all give 0),
"IS SPENT ONCE, however many frames the shot lives for" (first frame 4 casts, second 1), and
"CANNOT TUNNEL: a wall between the muzzle and the animal still stops the caught-up shot" (one
impact, and it is the wall). Harness note: `[catchup] spent once: first frame 4 casts, second 1`.

**4. Zero is bit-for-bit today's flight, so the failure mode is "yesterday's game".**
Verify: the "ZERO IS BIT-FOR-BIT TODAY'S FLIGHT" case traces every cast's origin and direction for
30 frames with `nil` and with `0` and compares them to 1e-9. Every call site written before this
task passes nothing.

**5. THE CORE CLAIM, measured live: the TRUE lead now hits what it used to miss.**
Verify: harness notes from the run above --
```
[catchup] rifle at 357 studs (100 m): true lead 5.6 st; 100 ms round trip costs 3.8 st, so the true lead MISSED; with the catch-up it HIT
[catchup] rifle at 536 studs (150 m): ... MISSED; with the catch-up it HIT
[catchup] rifle at 714 studs (200 m): ... MISSED; with the catch-up it HIT
```
Same aim, same animal, same stepper; the only difference is the fourth argument.

**6. THE LIMIT WAS FOUND BY MEASUREMENT, NOT BY REASONING, and it is stated rather than hidden.**
Round 1's first spec asserted a hit at EVERY range and **failed** (`weapon_hits.spec`, expected 1
got 0). Cause: forward prediction can only give back time the bullet actually spends in the air, so
where the round trip exceeds the flight time the correction is partial.
Verify: the "CANNOT GIVE BACK MORE PING THAN THE BULLET SPENDS IN THE AIR" case, and its note:
```
[catchup] LIMIT at 179 studs (50 m): flight 71 ms is SHORTER than the 100 ms round trip, so the catch-up cuts the miss from 4.26 to 1.73 studs and cannot clear it
```
Note section 5.5 is the whole table and says why nothing can be done about it inside this mechanism.
The core case now asserts `timeToRange > roundTrip` at the three ranges where its claim is a hit, so
it cannot silently start depending on the limit.

**7. The hit mark was `Anchored` in the world and the animal ran out from under it.**
Verify: on the BASE commit, `Effects.puff` sets `host.Anchored = true` and parents it to
`Workspace.WeaponEffects`. With `IMPACT.LIFETIME` 0.22-0.38 s and `Boar.CONFIG.MOVE.SPRINT_SPEED`
38 studs/s, that is **11.4 studs -- two of the animal's own 5.5-stud `BODY_SIZE` -- before the
grains have faded**. Note section 8.1 tabulates it at walk, run and sprint. That is Karen's
*"sometimes shows we hit empty space and died"*: "sometimes" is "whenever it was running", and
"died" is the server correctly killing what it correctly hit.

**8. The fix is a PARENT, not a position, and not a per-frame write.**
Verify: `Effects.ridesWith` (the one decision: a BasePart that is not `Anchored`), and `puff`'s
`attachTo` branch -- the `Attachment` this function has always built goes onto the struck part with
`attachTo.CFrame:ToObjectSpace(frame)`, so the emitter rides the body with no weld, no constraint
and no second writer of anything `Boar.Body` owns. The server sends only the Instance (a fourth
`parts` array on `ShotLanded`, `false` as the placeholder for the same index-alignment reason task
249's `normals` uses `Vector3.zero`); the offset is derived on the client, because the client's own
copy of where the animal is NOW is the frame the player can see.

**9. Measured live, and the orientation is measured too.**
Verify: harness note `[mark] body moved 11.4 studs; the mark followed to within 0.0000 studs (before
task 256 it stayed put and was 11.4 studs behind)`, plus `weapon_client.spec`'s riding-mark case:
the attachment's `WorldCFrame.UpVector` **is** the surface normal when the mark is made, and **turns
with the body** when the animal swings 90 degrees. That second pair exists because the emitter fires
along its host's TOP face, so a wrong frame sprays every grain into the boar's chest and the puff is
invisible -- a position correct to the millimetre says nothing about it.
A static surface is unchanged: "leaves a STATIC surface exactly as it was" asserts the anchored host
is still in `Effects.folder()` and that nothing was parented to the ground.

**10. Items 2 and 6 needed no code, and the note says so with numbers rather than with an opinion.**
Verify: note section 4 -- every weapon and load is **within 1.6 cm of the reticle inside 60 m**
against a 45 cm chest zone, so *"drop not needed"* is already true (`GRAVITY_SCALE`). Note section 9
-- the slug/buck split is already per-load (`poses.json` `fire.loads`) and already chosen by the
**chambered** round, which was verified end to end: `onFireRequest` reads
`state.loaded[state.selected]` (not `state.ammo`, the HUD's selection for the NEXT load), puts it on
`ShotFired`, and `CameraBoot` hands that one string to both `Camera.kick` and `Weapon.Sound.shot`.
Shipped recoil 1.45x against a **real 1.29x** derived here from the free-recoil formula; the shipped
`SPREAD_FULL_DEG.Buck = 1.6` deg turns out to match the real ~1.59 deg almost exactly.

## What I could NOT verify (rule 8)

1. **The live size of the lag correction.** A Studio Play session has no network and
   `GetNetworkPing()` reads ~0, so the compensation never fires in the harness --
   `Flight.stats().catchUpSeconds` is 0 in every run above, deliberately, and a non-zero value there
   would be a bug. **`FLIGHT_CATCHUP_PING_FACTOR` is a DATA ROW at the conservative 1.0 and needs a
   real server to confirm**, because the engine's own docs say only *"the network ping in seconds"*
   and do not state whether that is the round trip or one way. Section 5.1 shows the correction
   wanted is the round trip. Both readings are reachable by parameter and the spec drives both.
2. **No screenshot, and the reason is in claim 9.** The visual change is a 0.22-0.38 s particle puff
   on an animal that may be sprinting; a frame of it cannot settle to the millimetre what the two
   orientation assertions settle exactly, and the specific risk (grains firing into the body) is
   what those assertions were added for. If the Reviewer considers a frame necessary anyway, it
   needs the Forest Test, which was **not open** during this session -- only DEV was connected.
3. **Whether the slug's single pitch-shifted sample reads as a "different sound"** (item 6). The
   level and the pitch differ per load and are measured in the harness
   (`task204 voice: buck volume=0.950 pitch=1.000 | slug volume=1.188 pitch=0.820`), but it is ONE
   recording -- the shotgun row has no `SOUND` block. Karen's ear decides; a second sample is an
   upload and therefore the Director's.
4. **No real-click lead proof in the Forest Test.** The dispatch asks for one and the Learning
   Agent's route note correctly says no such route exists on disk. The lead claim is instead proved
   against the real stepper at three ranges (claim 5) with the aim geometry derived in the note, and
   the limit at a fourth (claim 6). Building the lead-fire + OS-click route belongs with part 2's
   live scope measurement, which needs the Forest Test open.
5. **Items 3 and 4 are not done** -- they are part 2 by the dispatch's own split. The note records
   what is already ruled out for each so part 2 does not re-derive it.
