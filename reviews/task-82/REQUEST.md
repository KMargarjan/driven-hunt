# Task 82 — the vest wraps the torso, and Karen's two accepted defaults flip on

Task: 82
Round: 1
Base: `main` (`39533b6`)
Code commit: `ca81c19cd8b27766a4360a339188279bffb1f7dd`

```
[harness2] PASS: 32/32 checks @ ca81c19cd8b27766a4360a339188279bffb1f7dd (clean tree)
[harness]  PASS: 32/32 checks @ ca81c19cd8b27766a4360a339188279bffb1f7dd (clean tree)
```

Both are my own `gate.sh` runs at this head, on the map world, with no flag override set
(`flags.py` printed `override none` for all three before the run). `src/` and `tests/client/` both
changed, so `test2` is part of the gate.

**The first gate at `8daf457` came back `[harness2] FAIL: 28/32` while `[harness] PASS: 32/32` named
the same commit.** Both failures were test faults, both of the shape Task 80 spent a task on, and
claim 7 is what they were and how they are fixed. Nothing was re-run until they were diagnosed.

**What changed.** `src/server/Match/Body.luau` (the `OUTFITS` table, the new pure `Body.fit`, and
`Body.dress` fitting each row to the limb it found), `src/server/Match/init.luau`
(`watchCharacter` dresses every new character), `src/shared/Flags/init.luau` (two `default`s and two
`expires`), `tests/server/match_outfit.spec.luau`, `tests/client/outfit_client.spec.luau`,
`tests/server/match_live.spec.luau`, `tests/server/weapon_rearm.spec.luau`,
`tests/client/camera_client.spec.luau`, `GAME_DESIGN.md` (two owner rows), `TASKS.md` rows 82/82a/82b,
`PLAYTEST.md` (the session's task links).

## Claims

1. **THE VEST WAS INVISIBLE BECAUSE ITS SIZE WAS A NUMBER, AND THE NUMBER IS GONE.** Task 77's row was
   one `Vest` of 2.2 × 1.6 × 1.3 **centred** on the torso: 0.1 proud on each side of an R15
   `UpperTorso` of (2, 1.6, 1), and entirely *inside* any torso wider than 2.2 or deeper than 1.3 —
   which `HumanoidDescription` scaling, an R6 `Torso` and any bundle can produce. `Body.fit` (pure)
   now answers `size = limbSize * scale + pad` and `offset = limbSize/2 * anchor + offset`, so the
   four plates are sized against **the limb that was actually found**. Verify: `Body.fit` and the
   `Drivers` rows in `src/server/Match/Body.luau`; the `fit, which sizes a plate against the limb it
   is hung on` cases in `tests/server/match_outfit.spec.luau`, which drive three torsos — R15
   (2, 1.6, 1), R6 (2, 2, 1) and a scaled (3.2, 2.4, 1.8) one that the old vest is entirely inside.

2. **EVERY PLATE STANDS `Body.VEST_GAP` CLEAR OF THE TORSO, AND THE WRAP HAS NO OPEN CORNER.** The
   pure cases assert, per torso and per plate: the inner face is at least the gap outside the limb's
   own surface, the plate has at least `Body.VEST_THICKNESS` on the axis it stands off, its height is
   the published fraction of the torso's, the four anchors are the four horizontal faces, each side
   plate reaches past the front plate's outer face, and the front plate covers ≥ 90 % of the torso's
   width. Verify: `clearanceOf` and those two `it`s in `tests/server/match_outfit.spec.luau`.

3. **THE SAME THING MEASURED ON LIVE INSTANCES, INCLUDING THE R6 FALLBACK, AND IT FOLLOWS A MOVING
   TORSO.** `dress` is run on rigs of all three torso sizes and each part's clearance is measured from
   `limb.CFrame:Inverse() * part.CFrame`; the R6 case renames the limb to `Torso` and asserts the
   fallback vest is fitted to *that* limb, not a weaker one; and one case moves the torso 18 studs and
   turns it 35° and requires the plate to have kept its offset (that is the `WeldConstraint` doing the
   work, not merely existing). Verify: `wraps a driver's torso in four plates, every one of them
   outside it`, `counts a miss rather than believing a change it did not make`, and `follows the torso
   when it moves, because it is welded to it`.

4. **THE CLIENT — WHERE KAREN LOOKS — MEASURES IT TOO, AND THE TWO-PLAYER RUN DID.**
   `tests/client/outfit_client.spec.luau` walks the outfit parts it *received*, takes each one's
   welded `Part0` as the limb and requires the same clearance. Run notes at the code commit:
   `outfit[client]: ORANGE_OUTFITS=true, 6 outfit part(s) on live characters, mine=dressed`,
   `2 teamed character(s), 2 dressed`, `4 vest plate(s) measured, worst 0.120 at VestRightSide
   (gap 0.12)` — **from both clients**, and the server's own case reports
   `task82: ORANGE_OUTFITS=true, 2 teamed character(s), 2 dressed, 4 vest plate(s), worst clearance
   0.120`. In a one-player run the single player is a shooter, so the vest half of that case measures
   nothing: `test2` is the only run that can carry this claim, and it does.

5. **THE MUTATION.** Every vest row's `anchor` set to `Vector3.zero` — which is exactly the Task 77
   bug, a plate centred on the limb — applied, run and restored:
   `[harness] FAIL: 30/32 @ 8daf457 (DIRTY)` with `match_outfit.spec` failing at its clearance case,
   its corner case, the rig case, the follows-the-torso case and the R6 case (five named failures,
   five errors). The invariant bites, and it bites where the defect was.

6. **THE DEFAULTS ARE FLIPPED, AND THE SPECS ASSERT THE REVIEWED VALUE RATHER THAN A CONSTANT.**
   `Flags.DEFAULTS.BOAR_SOUNDERS.default` and `.ORANGE_OUTFITS.default` are `true` (Karen:
   *"this ok"* for the sounders, and the hat/vest question is what this task answers), both with a
   one-line reason and `expires = 2026-12-31` — an accepted flag follows `TIE_UNTIL_DRIVE_END` and
   stays until the losing branch is archived, which is queued as row 82b; the 21-day ceiling is for a
   **dark** path. The specs assert the flag row itself (`the flag row` in `match_outfit.spec`) and
   that `Match.CONFIG` still equals `Flags.isOn(...)` at the boundary, and `match_live.spec` now
   requires `Match.CONFIG.SOUNDER.ENABLED == Flags.DEFAULTS.BOAR_SOUNDERS.default`, which still
   catches a run produced with an override.

7. **THE FIRST TWO-PLAYER GATE FOUND TWO SPECS MEASURING A GLOBAL QUANTITY ACROSS A WALL-CLOCK
   WINDOW.** (a) `weapon_rearm.spec` held a player's Tool for six seconds and asserted the same Tool
   after — but the drive **places** players at a drive start (`Match.Body.place` → `LoadCharacter`),
   which takes the character's Tool with it and lets the sweep repair it; that run's own note reads
   `repairs=2 granted=5`. It calls `Weapon.refreshArming` three times now — the sweep's own per-player
   work — with no wall clock, and only for a player **both** owners say may carry and who is holding
   one, so it still takes nobody's gun. (b) `camera_client.spec`'s refused-request case compared
   `Camera.stats().lookAtRequests` across three frames, and this client has another legitimate caller:
   `shoot_boar.spec` connects a `RenderStepped` tracker at require time that calls `Camera.lookAt`
   **every frame** for up to 15 s once the harness has staged its shot and a boar is on the field
   (`Expected 13, got 15`). The refusal is synchronous, so it is measured with no frame in between.
   **Mutations, applied, run and restored:** `armingAction` returning `"grant"` whenever allowed →
   `weapon_rearm.spec` fails on the Tool's identity; the `LookAtRequest` refusal counting →
   `camera_client.spec` fails on the request count. Neither case is vacuous.

8. **ONE ASSERTION WAS DELIBERATELY LOOSENED, AND IT IS THE HOLDBACK COUNT.** `match_live.spec` asked
   for `stats.sounderHoldbacks == 0`, justified by "nothing can have been held back on an empty
   field". With `BOAR_SOUNDERS` on, a release is a group of up to `SOUNDER.MAX_SIZE` = 5 against
   `MAX_ALIVE_BOARS` = 6, so `alive + size > ceiling` is a legitimate event on a field the players are
   not clearing, and whether it has happened by the time the spec runs depends on where in the release
   schedule the run landed. It now asserts the drive is **not stuck** (`< SOUNDER.HOLDBACK_WARN`) and
   that `boarsReleased <= BOARS_PER_DRIVE`. Called out because it is a weakening, not a fix.

9. **A RESPAWN IS DRESSED NOW — AND THIS IS THE ONE THING NO SPEC COVERS.** `Match`'s own
   `CharacterAdded` watcher returned early unless the player was tied, so a driver who pressed Reset
   mid-drive spent the rest of it with no vest while the shooters kept their hats. It calls
   `Body.dress` first now. **Unverified by test:** a spec cannot respawn the one live player without
   rewriting what half the client suite reports on (the Task 34 lesson), so mutating that line away
   fails nothing. Verified by reading only; recorded in `TASKS.md` row 82a(e).

10. **THE SCREENSHOTS, DESCRIBED AS THEY ARE** (`.screenshots/20260927T0902*`, a two-player session I
    started and ended myself, no override — the defaults carry it). *Driver, own over-the-shoulder
    camera:* an orange panel across the whole back of the torso, unmistakable against the green shirt,
    with the HUD reading `DRIVE 1 8:38 BOARS 6 DRIVER`. *Shooter, own camera:* the orange hat, brim
    and crown, clearly on the head, gun in hand. **What I got wrong first:** the dark blocks at the
    driver's shoulders are **not** the vest's side plates — the shooter, who wears no vest, has the
    same blocks, so they are the avatar's own shoulder accessories, and from directly behind they may
    be in front of the side plates. **No screenshot shows the vest from the FRONT**: a client window
    renders its own player from behind and cannot be turned, the capture's camera arguments are
    overridden by the game's camera owner (measured: the picture came back identical), and the test
    **server** window answers `screen_capture` with `missing field 'data'`. The front plate is carried
    by claims 2–5 instead — measured, not looked at. A desktop screenshot of the driver's front is the
    Director's, and `## Needs` in the report says exactly when in a run to take it.
