# Task 166: the drive's fanfare, the stand as an area, the horn at a bot's mouth

Task: 166
Round: 2
Base: `13fc0f0` (main, #149 merged)
Code commit: `a1ed4a1f56811c836f3e7697b774ff572b3333e0`

```
[harness] PASS: 33/33 checks @ 74b83cba7759ca931a0ae077725e2e602c760185 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 74b83cba7759ca931a0ae077725e2e602c760185 (clean tree) scope=all
[harness] PASS: 33/33 checks @ a1ed4a1f56811c836f3e7697b774ff572b3333e0 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ a1ed4a1f56811c836f3e7697b774ff572b3333e0 (clean tree)
```

**THE TWO-PLAYER LINE IS THE DIRECTOR'S.** Three `TWO_PLAYER_PATHS` entries are touched:
`tests/client/match_client.spec.luau` (the drive signal's client cases -- the voice is no longer the
beater's asset), `src/server/MatchBoot.server.luau` (one line: the horn seam hands the bots
`blowSeconds`) and two comments in `src/server/Match/`. Round 1's `[harness2]` was PASS 35/35 at
`28be043`; this round changes `src/server/Bots/` and specs, so it needs a fresh one.

## What changed

Karen's playtest of 162-165 (`PLAYTEST.md`, 2026-10-12): the beater's own horn, the 15 s stand timer
and the cleared-up screen are ACCEPTED; three things change. Note:
`docs/research/2026-10-12-fanfare-boundary-pose.md`. Round 1's two findings are claims 9 and 10; six of
its notes are fixed, three are queued as `TASKS.md` 166a.

## Claims

1. **The drive's signal is a library bugle fanfare, not three long notes of the beater's horn.**
   `Horn.CONFIG.SIGNAL.PHRASES` is keyed by the server's own word; start is 1842335206 cut 0.42-2.60,
   end is 1842368482 cut 0.32-2.00, and neither is `CONFIG.SOUND_ID`. Verify:
   `tests/server/zz_horn.spec.luau`, describe "the drive's own signal", and the harness note `horn: beep
   1.00 s (3.40-4.40) on rbxassetid://9038902877; start fanfare 2.18 s (0.42-2.60 of 4.06) ...; end
   1.68 s (0.32-2.00 of 2.84) ...; volume 3.0`.

2. **Both assets are public-domain, load in this place, and the cuts are inside them.** Nine candidates
   were measured (`IsPublicDomain: true`, APMOfficial / KPM, the same licensed catalogue as the beater's
   voice) with their real `TimeLength`; the note's section 1 lists all nine and both loudness profiles,
   and says why the pitch-shift route the dispatch allowed was refused. Verify: the client note `drive
   signal: made at load=true, preload returned=true, start=true 4.06 s (cut 0.42-2.60), end=true 2.84 s
   (cut 0.32-2.00)` -- those lengths are the engine's, read in the run.

3. **One loaded voice per cue BEFORE the first cue, the end cue plays its own, and the cue list is
   DERIVED.** `Hud.Sound` keeps `voices` keyed by the word and makes and preloads them at module load
   (163a(a)'s fix, kept); `driveSignal` walks `Horn.signalPlan(which, config)` and holds no numbers;
   `Horn.signalWords` is built from `SIGNAL.PHRASES` with the drive's own first cue leading, so a third
   row really is "a row here and no code anywhere" (round 1's note). An unknown word sounds the start
   phrase and `lastSignal` records the word that SOUNDED. Verify: `tests/client/match_client.spec.luau`,
   describe "the drive's horn signal" (note `drive signal: the END cue sounded, first readable position
   0.3200 s`), and `zz_horn`'s "answers an unknown or missing word with the start phrase".

4. **What put Karen back at her stand was MEASURED before anything was changed.** A character moved 20
   studs north of its locked stand read **6.000 studs in one Heartbeat and 6.000 on every sample for four
   seconds** -- the 6-stud leash, not `Body.settle` (one-shot; it would have landed her at 0.00) and not
   the placement. Verify: the note's section 2 (the raw sample row) and the `forest_stand` note `stand
   boundary: radius 12 studs (3.4 m), was 6 (1.7 m); measured 2026-10-12 ...`.

5. **The stand is a 12-stud circle and the clamp CANNOT return anything but a point on it.**
   `ForestTest.boundaryPoint` is pure: nil inside, outside a point at exactly `standRadiusStuds` on the
   caller's own bearing at the caller's own height. Verify: `tests/server/forest_stand.spec.luau`,
   "clamps a hunter ONTO the circle, at the bearing he walked out along" (36 bearings x 3 distances,
   including 200 studs out) and "can NEVER put him back at the middle of his stand". **The HUD's arrival
   band followed the radius, 12/18 -> 24/30** (`hud_clarity.spec`, "latches ARRIVED with a dead band").

6. **The edge is a wall, not a tug: only the OUTWARD velocity is removed.** `ForestTest.boundary` writes
   the clamped CFrame and subtracts the radial component of `AssemblyLinearVelocity` when it points away
   from the stand; sideways and vertical are untouched, an unlocked pick is not bounded, a beater is not
   bounded. Verify: `forest_stand.spec`, "stops a hunter at the edge and takes away only his OUTWARD
   speed" and "does not hold a beater to a stand".

7. **The edge is drawn, by the one writer of that folder.** `ForestTest.Markers.ring` lays 20 chord
   segments at the same radius, each on its own ground reading, `CanQuery = false` like every other
   marker; it is replaced rather than stacked, cleared with the picks, and now cleared with a LEAVER's
   pick too (round 1's note). `RING` is frozen and `stats.rings` counts rings rather than attempts.
   Verify: `tests/server/forest_markers.spec.luau`, describe "the stand's edge ring", the note `stand
   ring: 20 segments at r=12, chord 3.75 studs, lift 0.08, transparency 0.45`, and the screenshot
   `.screenshots/20261012T164704Z-t166-bot-blow-1.png` -- the ring is the arc round the player's feet.

8. **A bot beater raises the horn to its face while it blows, and only an animation could do it.** Three
   measured failures are in the note and in `Rig`'s header (these rigs are joined by
   `AnimationConstraint`, not `Motor6D`: 0.01 / 0.12 / 0.3 studs of hand movement; with the tracks
   stopped, 1.6). The pose is a `KeyframeSequence` built from two angles, registered once, played at
   `Action` with every pose above the shoulder at `Weight = 0`; the raise and lower are the Play/Stop
   fades and the hold is `Horn.CONFIG.BLOW_SECONDS`, handed in at both roots. **MEASURED LIVE:** all four
   bot beaters raised once in 45 s, the hand coming from a hanging arm to -0.20, -0.20, -0.18, -0.17
   studs relative to the head. **Looked at (rule 5):** `.screenshots/t166-bot-blow-crop.png`. Verify:
   `tests/server/bots_lane.spec.luau`, describe "the horn at the mouth (task 166)".

9. **ROUND 1 FINDING 1: no path can leave an arm up any more, and the drive's end takes it down in the
   same dispatch.** The level-trigger is asked of EVERY bot with a body, every step, outside
   `released`, `bot.to` and `bot.horn` -- the three guards it sat behind -- so the only way a horn is at
   a face is that this bot's blast has not finished. AND `Bots.gather` clears `blowUntil` and lowers the
   pose for every bot before any of them is placed in the results ring, because the scene begins there.
   The false comment is gone. Verify: `Bots.step`'s per-bot loop and `Bots.gather`'s first loop, and the
   case in claim 10 -- which fails on the old code at its `gather` line.

10. **ROUND 1 FINDING 2: `Rig.blow`'s playing half is asserted on a real rig.** `bots_live.spec`'s
    "raises the horn on top of the gait, and the drive's end takes it down again" is `holdTool`'s own
    idiom: up (the track plays, `blowing` records it, the WALK survives, which is the `Action`-over-
    `Core` claim), idempotent on the repeat, down through `Bots.gather`, the track stopped over its own
    fade, and down again from a STEP taken after the gather. It is guarded on `clips.blow ~= nil` for a
    session whose registration failed, and the `bots_lane` case is renamed to the claim it really makes.
    Verify: both cases, and the note `bots: the blow pose plays over the gait and is down again after
    gather and after a step`. **Also: two client cases that assumed the shooter still had a gun**
    (`weapon_client`'s trigger case, `rifle_client`'s draw case) now assert the TIE's own claim -- no gun
    equipped, no trigger bound, nothing drawn -- with `Match.isTied()`, the server's replicated answer.
    "Tied but still armed" fails there now; an unexplained 0 still fails as before.

## What could not be verified

- **Nothing has been HEARD or FELT.** Both phrases, the 12-stud radius, the ring's look and the pose are
  measurements and pictures. Karen's judgement is the gate for all four, and each is one line of data.
- **A PLAYER beater gets no arm raise**, deliberately: his character is `Match.Body`'s and his own
  client's `Animate`'s, so a server-side pose would be a second writer. He keeps the Tool's `GRIP_BLOW`
  tilt he already had.
- **No close-up of a blowing bot could be framed.** In a solo Play session the only camera is the
  player's own and `Camera.Rig` owns it; `capture ... server` answers "no Studio answered as 'server'".
  The screenshot is the player's own view, cropped; the numbers in claim 8 are what carries it.
- **No live run this round.** The Forest Test Studio is closed for `test2` and the dispatch says not to
  reopen it, so claims 9 and 10 rest on the two full one-player runs and not on a fresh playtest.
- **Queued, not fixed (`TASKS.md` 166a):** nothing ties the signal's two words to `Phase`'s own call
  sites; the client suite's tie race wants a harness fix rather than two guards; and
  `docs/design/forest-drive.md` and `docs/design/hud-clarity.md` still describe the leash this task
  replaced -- designs are the Architect's.
- **The `[harness2]` line**, as above.
