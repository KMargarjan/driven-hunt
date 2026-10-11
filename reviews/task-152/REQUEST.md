# Task 152: the beater kit, part 2 — THE HORN

Task: 152
Round: 1
Base: 0106c5e (main, after #134 merged)
Code commit: 4c819f75182e7c3b500bb0297fc62cd7ae3da64d

```
[harness] PASS: 33/33 checks @ 4c819f75182e7c3b500bb0297fc62cd7ae3da64d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 4c819f75182e7c3b500bb0297fc62cd7ae3da64d (clean tree) scope=all
[harness2] <PENDING — the Director runs it; see "Needs test2" below>
```

The one-player gate is pasted **twice** on purpose: the Director's own second run at the previous
head failed where mine had passed, so a single green run was not evidence. Both of these are at this
commit, consecutive, on a clean tree.

## What changed

A beater carries a signal horn. `src/shared/Horn/init.luau` is the frozen data (a pure piece list
for a coiled tube, the measured clip window, the roll-off, the spook radius in metres and studs);
`src/server/Weapon/Horn.luau` is the one writer of the Tool, its `Sound` and its `Grip`;
`Runtime:hearHorn` is one new door on the boar runtime; `MatchBoot` and `ForestTestBoot` wire them.

Two defects found by looking are fixed beside it — one in the camera (a beater saw a **shotgun** in
first person) and one in six specs that equated "a Tool" with "a gun".

## Claims

1. **The horn is a COIL built from parts, with no asset and no upload.** Five cylinders laid as
   **chords between points on a 230° arc** of radius 0.38, so consecutive sections share an endpoint
   exactly and no joint can gap however the numbers move; the bore widens 0.09 → 0.22, a nickel cup
   sits tangent at the near end, a flare and a bell at the far one, and the carrying cord closes the
   C. Verify: `zz_horn.spec` — "is a COIL and not a straight tube" asserts each joint bends by
   `degrees/segments` and that the **total turn exceeds 150°** (a straight tube scores 0); "rides one
   arc, nose to tail" asserts every section end is at the arc's radius and meets the next; "builds a
   horn from parts" asserts **zero** `MeshPart`/`SpecialMesh`. Gate note: `5 section(s) over a
   230-degree arc of radius 0.38; total turn 184 degrees`, `9 piece(s), bore 0.10 -> 0.21`.

2. **It is the beater's DEFAULT tool, in the hand, and hunters never get it — behind `HORN`, born
   OFF.** `Weapon.Horn.setCarryPolicy` is injected at each composition root as
   `Horn.carriesFor(Flags.isOn(Horn.FLAG), Body.teamOf(player))` — the flag read ONCE at the
   boundary, the team the same fact the outfit is chosen from — with a 2 s
   level-triggered sweep for the measured reason the gun has one (Task 34: the drive respawns players
   to place them). Verify: `zz_horn.spec` — "gives one horn and only one, and takes it back",
   "gives nobody a horn when no policy is wired" (the safe default, a revoke on a non-beater, and a
   policy that THROWS being a "no"). Live, Forest Test: a spawn reads `team=Shooters
   character=[Shotgun] backpack=[Rifle]` with **no horn anywhere**; after `/beater`, `team=Drivers
   character=[Horn]`. Live, DEV: setting a player's Team to `Drivers` and touching nothing else had
   the owner grant him one within the sweep — `team=Drivers horn=CHARACTER parts=9`.

3. **A click is one blast, read on the SERVER, and the cooldown is the rate limit.**
   `Tool.Activated` in `Horn.grant`: no remote, no client module, no input binding. Verify:
   `zz_horn.spec` — "sounds once per cooldown, publishes where it was blown, and raises to the
   mouth", plus `Horn.readyAt`'s four boundary cases.

4. **The clip is CUT, and the cut is measured — which moved one of the dispatch's numbers.**
   `Sound.TimeLength` is **60.63 s**: a horn blown over and over, not one blast. The loudness profile
   (note §5.4) puts the first call at 0.2–4.0 s, the clip's own silence at 4.1–5.0 and the **second
   call at 5.1**, so `SOUND_START` is 0.12 and `SOUND_CUT` 4.4. **The cooldown is 5 s and not the
   dispatch's 3**: 3 chops the last note and lets a beater produce one continuous unbroken horn.
   Verify: `zz_horn.spec` asserts only the RELATIONS (`SOUND_CUT < 5.1`, `playSeconds <= COOLDOWN`),
   never the values, because all four are data. The last case drives the real `task.delay`: the horn
   comes back down and the clip is stopped, not left running for the remaining 56 s.

5. **The blast spooks boars within 80 m through the EXISTING door, and it is not the shot latch.**
   `Runtime:hearHorn(at, radiusStuds)` sweeps its own animals and calls `Brain:spook(at)` with the
   `shot` argument left nil, so task 150's one-way `SENSE.SHOT_FLIGHT_UNTIL_EXIT` does not fire and
   `_lastShotAt`/`_lastShotPos` are untouched. Verify: `zz_horn.spec` — "pushes every animal inside
   the radius and leaves the ones outside it alone" asserts `flying()` for the two inside, **not**
   flying for the one outside, and that a boar **spawned after** the blast is not in flight. It adds
   no boar rule and no boar number: the radius is the horn's and is passed in.

6. **Boars outside the radius are unchanged — measured live, with a control window.** One blast, 13
   animals: **12 of 12 inside 286 studs ran** at 21.3–23.0 studs/s and **every one ended farther from
   the beater** (+5 to +34 studs in 1.5 s). A second trace with a 1.5 s window *before* the blast: of
   18 inside, **10 went from under 6 studs/s to 15.9–21.0**; of **7 outside at 295–341 studs, 0
   started running** — each walking 4.5–4.6 studs/s before and 4.5–4.6 after. The boundary is in the
   rows: **276 ran, 295 did not.**

7. **One owner, and the horn never touches a Brain.** It publishes `Horn.Blown({ blowerUserId, at })`
   and each composition root wires that to the boar runtime, exactly as `Weapon.ShotFired` is wired
   to `hearShot`. `at` is the horn's own Handle, never a phantom (note §5.3). Verify: grep `hearHorn`
   (two call sites, both boots) and `Boar` in `src/server/Weapon/Horn.luau` (none); `GAME_DESIGN.md`
   has the owner row. "Away from the beater" is `Brain:_latchFlight`'s existing rule — the exit is
   the heading and the beater is a swerve (task 139) — so `zz_horn.spec` asserts only what the horn
   owns (the animal ends farther from the beater) and prints the components.

8. **THE CAMERA DEFECT, found by looking.** A beater holding the horn saw a **SHOTGUN** in first
   person: `Camera.Viewmodel`'s source is *"the Handle of the Tool in the local character"*, so it
   took the horn's Handle, `weaponId()` answered nil, `Weapons.row(nil) or Shotgun.CONFIG` answered
   the shotgun. **Karen plays in first person.** Fixed with one shared fact asked in two places —
   `Weapons.isWeaponTool` (attribute first, name as the fallback for a Tool older than task 140):
   `Viewmodel.update` draws nothing for a non-weapon Tool and `Rig.trackHiddenPart` leaves one
   VISIBLE. **Exact complements**, so the thing in the hand is on screen once — never the "two
   shotguns at once" `Rig`'s header records, never nothing. Verify: `camera_client.spec` — "leaves a
   non-weapon Tool visible, and still hides a gun's" drives both halves against one probe, plus
   `Rig.toolAbove` on a body part (nil) and on a Tool's part. **The guard refuses a non-weapon TOOL,
   not "anything that is not a gun"** — the first version refused a Handle with no Tool above it,
   which is every Handle a spec injects, and three `camera_client` cases went to nil.

9. **The three camera cases that met the horn now exclude exactly it, by the same shared fact.**
   `camera_client.spec:634` (a driver "holding" something that is not a gun gets the empty-handed
   claim), `:1658` and `:1698` (the hidden-body and ADS sweeps). **The body check is not weakened**:
   every other part must still be at `LocalTransparencyModifier == 1`, and the ADS case COUNTS what
   it skipped, so "the horn is the only thing drawn" is a number in the note rather than an omission.
   This is the owner's decision made explicit: `Rig` leaves a non-weapon Tool visible on purpose,
   because a horn has no viewmodel and hiding it would leave a beater holding nothing.

10. **Six specs equated "a Tool" with "a gun", and in a drive the DRIVER is the one who now carries
    one.** `zz_drive_boundary` failed on the first gate run for exactly that. Each asks
    `Weapons.isWeaponTool` now: `zz_drive_boundary`, `match_live`, `zz_tie_to_a_tree`,
    `weapon_rearm`, `weapon_client` (its "the driver's empty hands" case is renamed to "never given a
    WEAPON", because asserting "no Tool anywhere" would now assert the beater kit does not exist) and
    `rifle_client`.

## The horn is BORN OFF, and that is also the isolation experiment

`Flags.DEFAULTS.HORN` is `false`. CLAUDE.md says a new feel-critical path is born dark, and all
three of this one's halves are feel — how loud a blast is, whether one call per five seconds is
right, whether a drive visibly moves when a beater blows. **Not having this row in round 1 was a
miss**, and the Director's gate is what showed why the rule exists: `test2` fails on this branch
where `main` passes, and with no switch the only A/B available was an uncommitted edit.

The flag is read **once**, at each composition root, and the value passed inward;
`Horn.carriesFor(on, team)` is pure, so both worlds are reachable in a spec while the flag sits at
one of them. **OFF, nobody is granted anything and the drive is bit-for-bit the game before this
task** — so the next `test2` *is* experiment (3):

- **it passes** → the horn's GRANT causes `zz_tie_to_a_tree:250`, and the bisect is next;
- **it fails** → the horn is exonerated and the cause is elsewhere on this branch.

The Forest Test keeps it on (`hornOn = true` in its own root), because Karen plays there to judge
the thing — the same way that world turns `BOAR_MODEL`, `PACE`, `MOVE` and `LINE` on.

## The gate failures the Director reported, and what each was

- **`[harness2]` 31/35 — the driver's camera.** Claim 9. `Rig` leaves the horn visible on purpose and
  three specs asserted "nothing of the local body draws". Decided at the owner (the rule stays
  static; see "what I could not verify" for why hiding-until-a-blast was rejected) and the specs now
  exclude exactly that Tool.
- **`[harness] 31/33` on a SECOND one-player run — NOT the horn.** One cause, not two:
  `Hud.renderScore` hides the score board while the report panel is open, and
  `ReportPanel.onDriveChanged` **auto-opens the panel once when a drive closes**. A live drive ending
  part-way through a run emptied `match_client`'s three score cases and broke `report_panel`'s "not
  visible until something opens it" — because a drive report **is** something opening it. Both were
  unstated preconditions and both now state themselves. **MEASURED: two consecutive runs at this
  commit, both PASS, and the condition FIRED in the second** (`report_panel: a drive report
  auto-opened the panel 9 time(s) before this case`) — so the fix was exercised, not dodged.
- **`[shooter] zz_tie_to_a_tree.spec:250` — still failing, and TWO of the three mechanisms are now
  REFUTED BY EXPERIMENT rather than by reading.** I ran the server's own judgement in a live Play
  session with a real horn on a stub driver as the only variable — the horn built by its own owner,
  `Body.driverPositions` with a stub players service, and `Penalty.judge` with its real arguments:

  ```
  NO HORN    drivers=1  firstHit=StubDriver.HumanoidRootPart @24.50  stopAt=24.50 reach=28.50 along=25.00  GUILTY=true
  WITH HORN  drivers=1  firstHit=StubDriver.HumanoidRootPart @24.50  stopAt=24.50 reach=28.50 along=25.00  GUILTY=true
  ```

  and, read off the live Instances rather than off the source, **all ten horn parts are
  `CanQuery=false CanTouch=false CanCollide=false Massless=true`**, with the character's
  `PrimaryPart` intact. So: the horn blocks no ray and shortens no `stopAt` (hypothesis 1 refuted);
  `driverPositions` finds the driver either way and nothing about him moved (hypothesis 2 refuted);
  and `SAFETY_GRACE_SECONDS` is **0**, so the grace is not it either. My earlier guess
  (`camera_client:634` leaving the driver aiming) was refuted by the Director's own run. **I do not
  have the mechanism, and I am not going to assert one.** What this round does instead is make the
  next run answer it — see the next two sections.

## What I could not verify

- **`test2` has not been run.** Five changed files are in `TWO_PLAYER_PATHS`, checked against
  `tools/agents.py`'s own table: `src/server/MatchBoot.server.luau`, `match_live.spec`,
  `zz_drive_boundary.spec`, `zz_tie_to_a_tree.spec`, `match_client.spec`.
  **NEEDS TEST2 152 4c819f75182e7c3b500bb0297fc62cd7ae3da64d.** `src/shared/Flags/init.luau`
  joins the five (it is not in `TWO_PLAYER_PATHS`; the five above are).
- **`zz_tie_to_a_tree.spec:250` is still unexplained after two refuted hypotheses, and the next run
  is set up to name it.** `violations=0` carried the whole story and cannot tell *"no shot was
  fired"* from *"a shot was fired and was not judged"* — two defects in two different systems, and
  it is what sent this task down both wrong paths. The spec's failure note now prints, **without
  touching the assertion**: both players' positions NOW against where the shot was staged and the
  drift of each; the `miss` against `SAFETY_MISS_STUDS` (12); and the gun's **barrels and reserve at
  the cue against now**, which change on a shot and on nothing else. One run with the flag OFF and
  one with it ON answers both the "is it the horn" question and the "was a shot fired" question.
- **Smoke in the Forest Test was NOT run, so nothing here says "ready for Karen".** The dispatch says
  that place is closed and must not be reopened. Standing rule A is therefore unmet by instruction,
  and the frames below are from a throwaway DEV Play session instead.
- **Nobody has HEARD the horn.** No spec can load an audio asset. Live: `IsLoaded=true`,
  `TimeLength=60.630`, `IsPlaying=true` with `TimePosition=0.53` on a blast. Whether 9038902877 sounds
  like a hunting horn is **Karen's** judgement; the whistle alternate is one line.
- **There is no first-person horn VIEWMODEL**, and no hands are drawn. The real Tool is drawn
  instead. A posed first-person horn with hands is the camera system's own task.
- **The brass reads as flat yellow under the DEV plate's bright sky** and as brass in the Forest
  Test's shade. Two lighting environments disagree, so `LOOK.brass` is not changed on the strength of
  one of them. Karen's dial, one line.
- **The server suite's token budget is thin** — `sync.spec` failed with a stale token when this spec
  sorted before it and spent ~3.5 s. It is `zz_horn.spec` now and runs last; the budget itself is a
  note for the Director.

## Evidence looked at (rule 5)

- `<runs-dir>/152-horn-shape.png` — the coil, built from `Horn.pieces` and stood in front of the
  camera: five visibly angled sections, nickel cup, flare and bell, cord closing the C.
- `<runs-dir>/152-grip-a.png` … `152-grip-d.png` — the four candidate carry grips. `d`
  (-0.80, 0.70, 0.45) is the one kept: about a fifth of the coil in the bottom-right, view clear.
- `<runs-dir>/152-grip-blow.png` — the raised pose, mouthpiece toward the face.
- `<runs-dir>/152-horn-fp.png`, `152-horn-fp2.png` — first person with the horn and **no shotgun**.
- `<runs-dir>/152-horn-preview.png` — third person, the orange cap and vest from task 151.
