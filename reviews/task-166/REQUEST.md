# Task 166: the drive's fanfare, the stand as an area, the horn at a bot's mouth

Task: 166
Round: 1
Base: `13fc0f0` (main, #149 merged)
Code commit: `688a78ff775f391da577cc7e85c38b72a7108f5a`

```
[harness] PASS: 33/33 checks @ 688a78ff775f391da577cc7e85c38b72a7108f5a (clean tree) scope=all
[harness] PASS: 33/33 checks @ 688a78ff775f391da577cc7e85c38b72a7108f5a (clean tree) scope=all
[harness2] <NEEDS TEST2 166 688a78ff775f391da577cc7e85c38b72a7108f5a -- the Director runs it>
```

**THE TWO-PLAYER LINE IS THE DIRECTOR'S.** This change touches three `TWO_PLAYER_PATHS` entries:
`tests/client/match_client.spec.luau` (the drive signal's client cases had to change -- the voice is no
longer the beater's asset), `src/server/MatchBoot.server.luau` (one line: the horn seam hands the bots
`blowSeconds`) and one stale comment in `src/server/Match/init.luau`. Per the dispatch I stop here.

## What changed

Karen's playtest of 162-165 (`PLAYTEST.md`, 2026-10-12): the beater's own horn, the 15 s stand timer
and the cleared-up screen are ACCEPTED; three things change. Note:
`docs/research/2026-10-12-fanfare-boundary-pose.md`.

## Claims

1. **The drive's signal is a library bugle fanfare, not three long notes of the beater's horn.**
   `Horn.CONFIG.SIGNAL.PHRASES` is keyed by the server's own word; start is 1842335206 cut 0.42-2.60,
   end is 1842368482 cut 0.32-2.00, and neither is `CONFIG.SOUND_ID`. Verify: `tests/server/zz_horn.spec.luau`,
   describe "the drive's own signal" -- and the harness note `horn: beep 1.00 s (3.40-4.40) on
   rbxassetid://9038902877; start fanfare 2.18 s (0.42-2.60 of 4.06) ...; end 1.68 s (0.32-2.00 of 2.84) ...`

2. **Both assets are public-domain, load in this place, and the cuts are inside them.** Nine candidates
   were measured (`IsPublicDomain: true`, APMOfficial / KPM, the same licensed catalogue as the beater's
   voice) with their real `TimeLength`; the note's section 1 lists all nine and both loudness profiles.
   Verify: the client note `drive signal: made at load=true, preload returned=true, start=true 4.06 s
   (cut 0.42-2.60), end=true 2.84 s (cut 0.32-2.00)` -- the lengths are the engine's, read in the run.

3. **The client has ONE loaded voice per cue BEFORE the first cue, and the end cue plays its own.**
   `Hud.Sound` keeps `voices` keyed by the word, makes and preloads both at module load (163a(a)'s fix,
   kept), and `driveSignal` walks `Horn.signalPlan(which, config)` and holds no numbers. Verify:
   `tests/client/match_client.spec.luau`, describe "the drive's horn signal" -- including the note
   `drive signal: the END cue sounded, first readable position 0.3200 s`.

4. **An unknown or missing cue word sounds the START phrase rather than nothing.** `Horn.SIGNAL_DEFAULT`,
   `Horn.signalPhrase`. Verify: the `zz_horn` case "answers an unknown or missing word with the start
   phrase, never with nothing".

5. **What put Karen back at her stand was MEASURED before anything was changed.** A character moved 20
   studs north of its locked stand read **6.000 studs in one Heartbeat and 6.000 on every sample for four
   seconds** -- the 6-stud leash, not `Body.settle` (one-shot; it would have landed her at 0.00) and not
   the placement. Verify: the note's section 2 (the raw sample row), and the `forest_stand` note
   `stand boundary: radius 12 studs (3.4 m), was 6 (1.7 m); measured 2026-10-12, the old leash wrote
   20.00 -> 6.000 studs in ONE Heartbeat and 6.000 every sample after`.

6. **The stand is now a 12-stud circle, and the clamp CANNOT return anything but a point on it.**
   `ForestTest.boundaryPoint` is pure: nil inside, and outside a point at exactly `standRadiusStuds` on
   the caller's own bearing at the caller's own height. Verify: `tests/server/forest_stand.spec.luau`,
   "clamps a hunter ONTO the circle, at the bearing he walked out along" (36 bearings x 3 distances,
   including 200 studs out) and "can NEVER put him back at the middle of his stand".

7. **The edge is a wall, not a tug: only the OUTWARD velocity is removed.** `ForestTest.boundary` writes
   the clamped CFrame and subtracts the radial component of `AssemblyLinearVelocity` when it points away
   from the stand; sideways and vertical are untouched, an unlocked pick is not bounded, and a beater is
   not bounded. Verify: `forest_stand.spec`, "stops a hunter at the edge and takes away only his OUTWARD
   speed" and "does not hold a beater to a stand".

8. **The edge is drawn, by the one writer of that folder.** `ForestTest.Markers.ring` lays 20 chord
   segments at the same radius, each on its own ground reading, `CanQuery = false` like every other marker;
   it is replaced rather than stacked and cleared with the picks. Verify:
   `tests/server/forest_markers.spec.luau`, describe "the stand's edge ring", and the note `stand ring:
   20 segments at r=12, chord 3.75 studs, lift 0.08, transparency 0.45`. **And a screenshot, inspected:**
   `.screenshots/20261012T164704Z-t166-bot-blow-1.png` -- the ring is the arc on the ground round the
   player's feet.

9. **A bot beater raises the horn to its face while it blows, and only an animation could do it.** Three
   measured failures are in the note and in `Rig`'s own header (these rigs are joined by
   `AnimationConstraint`, not `Motor6D`: 0.01 / 0.12 / 0.3 studs of hand movement; with the tracks
   stopped, 1.6). The pose is a `KeyframeSequence` built from two angles, registered once, played at
   `Action` with every pose above the shoulder at `Weight = 0`; the raise and lower are the Play/Stop
   fades and the hold is `Horn.CONFIG.BLOW_SECONDS`, handed in at both roots. Verify:
   `tests/server/bots_lane.spec.luau`, describe "the horn at the mouth (task 166)", and the note
   `horn pose: shoulder (-120, 0, 15) elbow (-150, 0, 0), up 0.20 s, held 0.90 s (Horn.BLOW_SECONDS),
   down 0.35 s`. **MEASURED LIVE in the Forest Test:** all four bot beaters raised once in 45 s, the hand
   coming from a hanging arm to **-0.20, -0.20, -0.18, -0.17 studs relative to the head**. **And looked at
   (rule 5):** `.screenshots/t166-bot-blow-crop.png` -- a vested beater with the brass horn up at its face.

10. **The HUD's arrival band followed the radius, 12/18 -> 24/30.** An "arrived" ring inside the circle a
    hunter may legally walk in would flicker exactly where he is meant to stand. Verify:
    `tests/client/hud_clarity.spec.luau`, "latches ARRIVED with a dead band".

## What could not be verified

- **Nothing has been HEARD or FELT.** Both phrases, the 12-stud radius, the ring's look and the pose are
  measurements and pictures. Karen's judgement is the gate for all four, and each is one line of data.
- **A PLAYER beater gets no arm raise**, deliberately: his character is `Match.Body`'s and his own
  client's `Animate`'s, so a server-side pose would be a second writer. He keeps the Tool's `GRIP_BLOW`
  tilt he already had. The dispatch asked for it "if cheap": it is not cheap, it is an owner boundary.
- **No close-up of a blowing bot could be framed.** In a solo Play session the only camera is the
  player's own and `Camera.Rig` owns it, and `capture ... server` answers "no Studio answered as
  'server'". The screenshot above is the player's own view, cropped; the numbers in claim 9 are what
  carries the claim.
- **`docs/design/forest-drive.md` (sections 5.2, 13) and `docs/design/hud-clarity.md` still name
  `ForestTest.leash` and `PICK.leashStuds`.** `docs/design/` is the Architect's to write, so the code
  moved and those two documents have not. Queued rather than edited.
- **The `[harness2]` line**, as above.
