# Task 144 - a respawn hands the whole loadout back, shotgun in hand

Task: 144
Round: 1
Base: main (`f3162ce`, task 143 merged as PR #126)
Code commit: `a3b2a4e298e7fdfcacc84b5c4f210effe35c8a89`

```
[harness] PASS: 33/33 checks @ a3b2a4e298e7fdfcacc84b5c4f210effe35c8a89 (clean tree) scope=all
```

`test2` is N/A: the diff is `src/server/Weapon/init.luau` and `tests/server/weapon_equip.spec.luau`,
neither in `TWO_PLAYER_PATHS`.

**No Architect run:** no new owner and no new system. One predicate inside the arming owner was
asking the wrong question; this corrects the question.

## The ten claims

1. **IT REPRODUCES, AND HERE IS THE SHAPE.** Twelve rounds in the Forest Test with the loadout of
   three, alternating a plain death with a SECOND death 0.35 s after the respawn — inside
   `AUTO_EQUIP_DELAY_SECONDS` (0.5 s). Round 4 broke and round 5 was still broken:

   ```
   r04 before FAST  hand=[]        bag=[Rifle,RifleOpen,Shotgun]
   r04 +0.35        hand=[]        bag=[Rifle,RifleOpen,Shotgun]
   r04 +0.6         hand=[]        bag=[Rifle,RifleOpen]     <- the shotgun is gone
   r04 +1.5 / +3.0 / +6.0          bag=[Rifle,RifleOpen]     <- and stays gone
   r05 before slow  hand=[]        bag=[Rifle,RifleOpen]     <- a whole further respawn
   r05 +0.6 .. +6.0 hand=[]        bag=[Rifle,RifleOpen]     <- does not repair it
   ```

   That is Task 141's note — *"dying can leave a player with only the rifle and nothing in hand ...
   doesn't reproduce on a fresh session"* — with the trigger named: **the second death has to land
   inside the auto-equip window**. The script is `driven-hunt-runs/t144-after.luau` (the before run
   used the same body).

2. **THE CAUSE, FOUND BY COUNTING TOOLS RATHER THAN BY READING CODE.** A census of the WHOLE
   DataModel at the broken moment (`driven-hunt-runs/t144-census.luau`, printing every Tool's
   `GetFullName()`):

   ```
   attempt 9, +1.5 after the double death  hand=[] bag=[Rifle,RifleOpen]
       Rifle      parent=Players.<player>.Backpack (Backpack)  liveBag=true
       RifleOpen  parent=Players.<player>.Backpack (Backpack)  liveBag=true
   ```

   **Two Tools, not three.** The shotgun is not under `game` anywhere — and the owner still believed
   it had granted one. That is only possible if the record points at a Tool whose Parent is NOT nil
   and is NOT in the tree: **a respawn DETACHES the old Backpack (`Parent = nil` on the Backpack
   itself) without destroying it**, so the Tool inside keeps a perfectly good Parent indefinitely.

3. **SO THE OLD PREDICATE ANSWERED THE WRONG QUESTION.** `holdsTool` was `tool.Parent ~= nil`, which
   reads a detached container as "he is holding it", so `armingAction` returned nil and the grant was
   skipped. `watchTool`'s guard was the same test (`if tool.Parent ~= nil then return end`), so the
   record was never cleared either — and the 2-second arming sweep restated the same wrong answer
   every tick instead of repairing it. Nothing re-granted until the engine got round to destroying
   the detached Backpack, which is non-deterministic: **that is why a fresh session looks fine and a
   long one does not.**

4. **THE FIX IS ONE PREDICATE, AND IT IS THE QUESTION `Hardware.toolsOf` ALREADY ASKS.**
   `Weapon.reachable(tool, player)` — pure and public — is true only when the Tool's parent is the
   Backpack the player has NOW or the character they are wearing NOW. **Verify:**
   `Weapon.reachable` in `src/server/Weapon/init.luau`, and the two callers: `holdsTool` and
   `watchTool`'s `AncestryChanged`.

5. **THE RECORD IS CORRECTED ON EVERY READ.** `holdsTool` drops the stale entry when the predicate
   fails, so the next `armingAction` says "grant" — which turns the arming sweep from a restatement
   into a repair, and makes `CharacterAdded` repair it in the same frame.

6. **THE CASE FAILS TODAY, AND I RAN IT TO PROVE IT.** With `src/server/Weapon/init.luau` stashed
   back to its merged state and the new spec in place:

   ```
   failed [server] weapon_equip.spec:444  attempt to call a nil value        <- Weapon.reachable
   failed [server] weapon_equip.spec:544  Expected value "true", got "false" <- the re-grant
   [harness] FAIL: 31/33 checks @ f3162ce (DIRTY TREE (1 paths) - NOT valid evidence)
   ```

   The second is the load-bearing one: it is `waitUntil(6, #Hardware.toolsOf(player, PRIMARY) > 0)`
   after the primary has been moved into a detached Backpack. **Verify:** "re-grants a gun that went
   with a detached Backpack, and puts the primary back in the hand" in
   `tests/server/weapon_equip.spec.luau`.

7. **A SPEC CANNOT KILL THE HARNESS PLAYER** — every other case in that file needs him and his own
   gun back — so the case reproduces the STATE a respawn leaves rather than the respawn: the Tool is
   moved into a `Backpack` that is not in the tree. That is the one fact the old rule got wrong, and
   the case asserts `tool.Parent ~= nil` on that Tool before asserting it is unreachable, so it
   cannot pass by accident.

8. **IT ALSO CLOSES 143a's TOP NOTE.** The Reviewer: *"no committed spec puts a THIRD Tool in a
   hand"*. This one does — `Weapons.loadoutFor(true)` **by parameter**, because the gate refuses to
   run with a flag override set, which is the rule CLAUDE.md states for anything behind a flag. It
   asserts all three Tools come back and that the shotgun ends in the CHARACTER.

9. **AFTER, THE SAME TWELVE ROUNDS.** Six of them double-deaths. Every single respawn:
   `hand=[Shotgun] bag=[Rifle,RifleOpen]` at +1.5 s and at +3.0 s, 12/12. The full table is in the
   report to the Director; nothing in it varies.

10. **THE EQUIP RULE IS UNCHANGED ON PURPOSE.** `refreshArming` still equips only when that pass
    actually granted something and the player is holding nothing — the narrow rule `Weapon.
    upgradeLook` follows too, so a sweep can never take the rifle out of the hands of a player who
    chose it, and can never undo a holster. The fix works by making the GRANT happen on a respawn,
    not by widening what re-equips.

## The frame, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t144-after-respawn.png` | **The hotbar is not in it.** The harness's capture is the 3D viewport, and the engine's Backpack bar is CoreGui, so slot order is evidenced by `weapon_equip.spec`'s bag-arrival case and not by this picture. What the frame DOES show is the half that was broken: taken 8 s after a double death, the **shotgun is in the hand** — both barrels and the glove on the forend, bottom left — with the compass up and the readout reading `[*]* SLUG 24`. Before the fix this frame is empty hands. |

## Standing rule A, Forest Test, 85 s, with RIFLE ON

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 2 boar sounds at once over 10 s with 27 boars alive

## What I could not verify, and what I got wrong

* **THE FIRST CLEAN GATE RUN ON THIS COMMIT READ 31/33.** It ran immediately after `git stash pop`
  put the owner back, and I did not capture which two checks failed — the likely reason is Rojo
  still catching up with the restored file when the Edit-place sync checks ran. The two runs after
  it both read `PASS: 33/33 @ a3b2a4e… (clean tree) scope=all`, with 828 server and 180 client
  assertions and no failures. I am reporting it rather than quoting only the passes.
* **I did not reproduce the drive's own respawn** (`Match.Body.place` -> `LoadCharacter`), which is
  the path Task 34 and Task 129 were about. The double-death I used is the same event from the
  weapon owner's side — a character replaced while an auto-equip is in flight — but a drive
  placement may have its own timing, and only a two-player drive would show it.
* **`Weapon.reachable` takes a `Player`, so it is not callable without one.** The pure case uses
  the harness's own player and real Instances; there is no session-free unit for it.
* **The hotbar's slot numbers are still the engine's**, and nothing here changes the order rule from
  task 141. What this task guarantees is that all three Tools arrive, in `Weapons.ORDER`, on a
  respawn — which is the input that rule needs.
