# Task 152: the beater kit, part 2 — THE HORN

Task: 152
Round: 1
Base: 0106c5e (main, after #134 merged)
Code commit: 8c01700b54cb69771408cd48e4430c574c63ca98

```
[harness] PASS: 33/33 checks @ 8c01700b54cb69771408cd48e4430c574c63ca98 (clean tree) scope=all
[harness2] <PENDING — the Director runs it; see "Needs test2" below>
```

## What changed

A beater now carries a signal horn. `src/shared/Horn/init.luau` is the frozen data (a pure piece
list, the measured clip window, the roll-off, the spook radius in metres and studs);
`src/server/Weapon/Horn.luau` is the one writer of the Tool, its `Sound` and its `Grip`;
`Runtime:hearHorn` is one new door on the boar runtime; `MatchBoot` and `ForestTestBoot` wire them.

A defect found by looking is fixed beside it: a beater holding the horn saw a **shotgun** in first
person. `Weapons.isWeaponTool` is the one fact that fixes it, and six specs that equated "a Tool"
with "a gun" now ask it too.

## Claims

1. **The horn is built from parts, with no asset and no upload.** `Horn.pieces` (shared) is pure and
   `Weapon.Horn.build` welds each piece with the existing `Hardware.addPiece`. Verify:
   `zz_horn.spec` — "builds a horn from parts" asserts every piece and weld by name and **zero**
   `MeshPart`/`SpecialMesh` in the Tool; "lays the sections nose to tail" asserts the sections are
   contiguous and that the last face lands exactly on `Horn.bellOffset`. Why parts at all:
   note §5.2 and §5.4 (both free Creator Store horn MODELS answer `LoadAsset` with *"User is not
   authorized to access Asset."*).

2. **It is the beater's DEFAULT tool, in the hand, and hunters never get it.**
   `Weapon.Horn.setCarryPolicy` is injected at each composition root as
   `Body.teamOf(player) == Horn.TEAM` — the same fact the outfit is chosen from. Verify: `zz_horn.spec`
   — "gives one horn and only one, and takes it back" (idempotent grant, `refreshCarry` a no-op when
   nothing changed, revoke) and "gives nobody a horn when no policy is wired" (the safe default, a
   revoke on a non-beater, and a policy that THROWS being a "no"). Live, Forest Test: a spawn reads
   `team=Shooters character=[Shotgun] backpack=[Rifle]` with **no horn anywhere**; after `/beater`,
   `team=Drivers character=[Horn] backpack=[Rifle,Shotgun]` — in the CHARACTER, not the Backpack.

3. **A click is one blast, read on the SERVER, and the cooldown is the rate limit.**
   `Tool.Activated` in `Horn.grant`, so there is no remote, no client module and no input binding.
   Verify: `zz_horn.spec` — "sounds once per cooldown, publishes where it was blown, and raises to
   the mouth" (a click inside the cooldown publishes nothing; the next one on time does) and
   `Horn.readyAt`'s four boundary cases.

4. **The clip is CUT, and the cut is measured — which moved one of the dispatch's numbers.**
   `Sound.TimeLength` is **60.63 s**: the asset is a horn blown over and over, not one blast. The
   loudness profile (note §5.4) puts the first call at 0.2–4.0 s, the clip's own silence at 4.1–5.0
   and the **second call at 5.1**, so `SOUND_START` is 0.12 and `SOUND_CUT` 4.4. **The cooldown is
   5 s and not the dispatch's 3**: a 3 s cooldown over a 4.0 s call chops the last note and lets a
   beater produce one continuous unbroken horn. Verify: `zz_horn.spec` — "cuts one call out of a
   sixty-second recording, and the cooldown fits it" asserts only the RELATIONS (`SOUND_CUT < 5.1`,
   `playSeconds <= COOLDOWN`), never the values, because all four are data.

5. **The blast spooks boars within 80 m through the EXISTING door, and it is not the shot latch.**
   `Runtime:hearHorn(at, radiusStuds)` sweeps its own animals and calls `Brain:spook(at)` with the
   `shot` argument left nil, so task 150's one-way `SENSE.SHOT_FLIGHT_UNTIL_EXIT` does not fire and
   `_lastShotAt`/`_lastShotPos` are untouched. Verify: `zz_horn.spec` — "pushes every animal inside
   the radius and leaves the ones outside it alone" asserts `flying()` for the two inside, **not**
   flying for the one outside, and that a boar **spawned after** the blast is not in flight (which
   is the latch not firing). It adds no boar rule and no boar number: the radius is the horn's and
   is passed in.

6. **Boars outside the radius are unchanged — measured live, with a control window.** One blast, 13
   animals: **12 of 12 inside 286 studs ran** at 21.3–23.0 studs/s and **every one ended farther
   from the beater** (+5 to +34 studs in 1.5 s). A second trace with a 1.5 s window *before* the
   blast: of 18 inside, **10 went from under 6 studs/s to 15.9–21.0**; of **7 outside at 295–341
   studs, 0 started running** — each walking 4.5–4.6 studs/s before and 4.5–4.6 after. The boundary
   is in the rows: **276 ran, 295 did not.** Console: `[ForestTest] horn blown at (3029, 144,
   -2095): 12 boar(s) pushed within 286 studs (80 m)`.

7. **"Away from the beater" means what the drive already means by it, and that is written down
   rather than assumed.** `Brain:_latchFlight` heads the animal for `field.exitZ` and makes the
   fright a SWERVE (*"the exit is the heading and the gun is a swerve ... driven game breaks PAST
   the guns"*, task 139). A beater pushing animals toward the hunters' line is what that rule is
   for. Verify: `zz_horn.spec` — "sends them away from the horn, and out of the wood" asserts only
   what the horn owns (the animal ends farther from the beater) and prints the components;
   measured in the gate: `pushed from 90 to 123 studs off the beater in 1.5 s (dx -26, dz -41)`.

8. **One owner, and the horn never touches a Brain.** It publishes `Horn.Blown({ blowerUserId, at })`
   and each composition root wires that to the boar runtime, exactly as `Weapon.ShotFired` is wired
   to `hearShot` — so neither owner requires the other. `at` is the horn's own Handle, never a
   phantom (note §5.3). Verify: grep for `hearHorn` (two call sites, both boots) and for `Boar` in
   `src/server/Weapon/Horn.luau` (none); `zz_horn.spec` asserts the published `at` is the Handle's
   own position. `GAME_DESIGN.md` has the owner row.

9. **THE DEFECT FOUND BY LOOKING, and it is the camera's.** A beater holding the horn saw a
   **SHOTGUN** in first person: `Camera.Viewmodel`'s source is *"the Handle of the Tool in the local
   character"*, so it took the horn's Handle, `weaponId()` answered nil, `Weapons.row(nil) or
   Shotgun.CONFIG` answered the shotgun, and it drew the wrong object out of the right Handle.
   **Karen plays in first person.** Fixed with one shared fact asked in two places —
   `Weapons.isWeaponTool` (attribute first, name as the fallback for a Tool older than task 140):
   `Viewmodel.update` draws nothing for a non-weapon Tool and `Rig.trackHiddenPart` leaves one
   VISIBLE. **They are exact complements**, so the thing in the hand is on screen exactly once —
   never the "two shotguns at once" `Rig`'s own header records, and never nothing. Verify:
   `camera_client.spec` — "leaves a non-weapon Tool visible, and still hides a gun's" drives both
   halves against one probe, plus `Rig.toolAbove` on a body part (nil) and on a Tool's part.
   Looked at: `<runs-dir>/152-horn-fp.png`.

10. **Six specs equated "a Tool" with "a gun", and in a drive the DRIVER is the one who now carries
    one.** `zz_drive_boundary` failed on the first gate run for exactly that. Each asks
    `Weapons.isWeaponTool` now: `zz_drive_boundary`, `match_live`, `zz_tie_to_a_tree`,
    `weapon_rearm`, `weapon_client` (its "the driver's empty hands" case is renamed to "never given
    a WEAPON", because asserting "no Tool anywhere" would now be asserting the beater kit does not
    exist) and `rifle_client`. Verify: grep `FindFirstChildOfClass("Tool")` under `tests/` — the
    remaining hits are `rifle_client`'s (now gated) and `weapon_client`'s line 1053 region, both
    narrowed in the same commit.

## What I could not verify

- **`test2` has not been run.** Four of the changed files are in `TWO_PLAYER_PATHS` — checked
  against `tools/agents.py`'s own table, not asserted: `src/server/MatchBoot.server.luau`,
  `tests/server/match_live.spec.luau`, `tests/server/zz_drive_boundary.spec.luau` and
  `tests/client/zz_tie_to_a_tree.spec.luau`. (The other three specs I narrowed in claim 10 —
  `weapon_rearm`, `weapon_client`, `rifle_client` — are NOT in that list, and an earlier draft of
  this line said "five specs", which was wrong.) So the two-player line is part of this task's gate
  and the dispatch reserves that run for the Director. **NEEDS TEST2 152 8c01700b54cb69771408cd48e4430c574c63ca98.**
  Claims 2, 6 and 10 are the ones a second player could sharpen: everything above was measured with
  one player, where the beater is the local player rather than somebody else.
- **Nobody has HEARD the horn.** No spec in this repo can load an audio asset, so `zz_horn.spec`
  asserts the `Sound`'s properties and not its noise. Live, in the Forest Test: `IsLoaded=true`,
  `TimeLength=60.630`, and `IsPlaying=true` with `TimePosition=0.53` on a blast. Whether 9038902877
  sounds like a hunting horn is **Karen's** judgement, and the whistle alternate is one line.
- **There is no first-person horn VIEWMODEL**, and it is named rather than hidden. The real Tool is
  drawn instead, so the horn is in view but **no hands are**, and the "raise to mouth" is a tilt of
  `Tool.Grip` (measured `0,0,0.25` → `0,0.205,0.143`) with the ARM left where it is. Raising an arm
  means writing the character's Motor6Ds or its Animator — a second writer on a character that has
  exactly one per concern (rule 3). A posed first-person horn with hands is the camera system's own
  task.
- **The server suite's token budget is thin and this task did not widen it.** `TOKEN_MAX_AGE` is
  120 s and `sync.spec` failed with a stale token when this spec sorted before it and spent ~3.5 s
  of wall clock — so the margin on `main` was under 3.5 s. The spec is `zz_horn.spec` now and runs
  last, which fixes this task; the budget itself is a note for the Director, not a fix I made.
- **A beater who also carries a gun** (the later licence) is out of scope, and so is the compass.

## Evidence looked at (rule 5)

- `<runs-dir>/152-horn-fp.png` — first person: brass taper, flared bell, nickel mouthpiece, leather
  cord, **no shotgun**. The same frame before the fix was a side-by-side shotgun.
- `<runs-dir>/152-horn-preview.png` — third person: the orange cap and vest from task 151, the horn
  in hand. (The greens read very dark in shade; that is task 151's colour and not this task's.)
- `<runs-dir>/152-horn-blow.png` — the raised tilt during a blast.
- Smoke, Forest Test, at the code commit: `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 |
  waves=5 | worst playing sounds over 10 s: 1` — **SMOKE PASS**.
