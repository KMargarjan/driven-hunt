# Task 263 -- the proof tools

Task: 263
Round: 1
Base: fd5d20c5
Code commit: (filled in below, with the harness line)

## PLAN (core quality protocol, step 0 -- written and committed before any `src/` edit)

The dispatch names three blockers. **Two of them are refuted by measurement**, and the protocol says
so plainly: *"If (b) contradicts the dispatch, say so and stop. A refuted premise is a finished item,
not a failure."* The third is real, and the measurement below is what says which is which.

### Item 1 -- arm every gun in the Forest Test

- **(a) REAL LIFE / the rule.** Karen, 2026-10-10: *"Rifle they has to purchase default is double
  barrel shotgun"*. Four guns exist: the free double (`shotgun`), the scoped Rigby (`rifle.scoped`),
  the lever (`rifle.lever`), the semi-auto (`shotgun.semiauto`).
- **(b) MEASURED NOW**, Forest Test, 2026-10-25, probe `<runs-dir>/263-loadout.luau`:
  - with no `DHTestOwns`: `team=nil held=[] backpack=[]` before enrolling, and task 258's
    `team=Shooters tool=Shotgun backpack=[]` after.
  - with `ServerStorage.DHTestOwns = "rifle.scoped,rifle.lever,shotgun.semiauto"` set in Edit:
    **`team=Shooters held=[Shotgun] backpack=[Lever,Rifle,SemiAuto]`**.
  - **The dispatch's ids are not this build's.** `weapon.rifle` / `weapon.lever` / `weapon.semiauto`
    are refused by `Economy.testOwnsFor`, which checks `ShopData.anyRow(id)`. The shop's ids are
    `Shop.ITEM.RIFLE = "rifle.scoped"`, `Shop.ITEM.LEVER = "rifle.lever"`,
    `Shop.ITEM.SEMIAUTO = "shotgun.semiauto"`.
- **(c) TARGET.** Four guns carried, and each one reachable in a drive by a **real keystroke**.
- **(d) LEVER.** No `src/` writer needs changing: `Weapons.loadout` -> `Shop.loadoutFrom` already
  hands out every owned id, and `Weapon.refreshArming` grants the whole loadout. Task 261's
  `Economy.testOwnsFor` is the input. **The lever that was missing is in the OPS tool, not the game**:
  `<runs-dir>/key.ps1` sends `keybd_event` with the virtual key and **no scan code**, and the Forest
  Test measured every digit arriving at `UserInputService` as `KeyCode.None`.
- **(e) HOW MEASURED AFTER.** Same probe, plus the switch read after each real key.

**MET, with no code change** -- see item 1 below. This item is a verification, and that is what the
dispatch asked for: *"Verify it on her path ... If 261 has not made that true, make it true."* It is
true.

### Item 2 -- point the camera in Play

- **(b) MEASURED NOW**, three readings, Forest Test, 2026-10-25:
  1. `<runs-dir>/263-camlook.luau`, a **client** probe writing the existing `DHLookAt` attribute
     (task 101): **`tookIt=true moved=84.8599 deg offTarget=0.00 deg`**. The mechanism the dispatch
     says is missing **exists and works**. Task 258's `moved=0.0000` was a probe fault, not a missing
     tool: it went through `require()` and got the command bar's own fresh copy of the module (L-109).
  2. `<runs-dir>/263-camlook-server.luau`, a **server** probe: the first write lands (a following
     client read shows `camLook=-0.000,-0.001,1.000`, the asked-for +Z), but the server's own copy of
     the attribute is **never cleared** -- `serverCopyAfter1 == serverCopyAfter2 == the point`. The
     client's clear is a client write to its own `Player` and does not replicate up.
  3. `grep LOOK_AT_ATTRIBUTE src/client/Camera/init.luau`: the read sits in `Camera.start`'s
     `GetAttributeChangedSignal` connection with **no `RunService:IsStudio()` guard**.
- **So the premise is refuted and a real gap is left.** `DHLookAt` is an **edge-triggered one-shot**:
  `Camera.lookAt` snaps once, the owner writes the attribute back to `nil` as a handshake, and
  nothing holds the view. For the instrument item 3 needs that fails in three ways, all measured
  above: a repeat of the same point from the server changes no property, fires no changed signal and
  is **silently dropped**; nothing holds the view while a real click travels through the window and a
  frame is taken; and it is not Studio-gated.
- **(c) TARGET.** A **held, level-triggered, Studio-only** look: `DHTestLook = "x,y,z"` on the
  LocalPlayer, re-applied once per frame until `DHTestLookOff` releases it, and answering `nil`
  outside Studio. Level-triggered is the whole point: **the camera never writes the attribute**, so
  there is no handshake to break and asking for the same point twice is idempotent.
- **(d) LEVER.** `src/client/Camera/TestLook.luau` (new, the one reader) + one call in
  `Camera.update`, beside the `Poses.holdState` line that is already a Studio-only hold applied after
  the step. `grep -n "state = Poses.holdState" src/client/Camera/init.luau` ->
  `state = Poses.holdState(state, hold)`.
- **(e) HOW MEASURED AFTER.** The same probe shape as (b): write the attribute from a server probe,
  twice to the same point, and read `moved` / `offTarget` off `workspace.CurrentCamera` from a client
  probe -- plus a captured frame of a named animal.

### Item 3 -- `<runs-dir>/aimshot.py`

- **(b) MEASURED NOW.** No such instrument exists; task 261's item 3 is `NOT PROVEN` for exactly that
  reason. Two tool facts were measured for it today: a `task.spawn`ed thread from an `execute_luau`
  probe **survives the call** (`<runs-dir>/263-keyspy-arm.luau` kept recording between two probes),
  and `ShotLanded` is a `RemoteEvent` **Instance**, so a probe may connect to it without the fresh-
  module trap.
- **(c) TARGET.** One real click, and three numbers printed together: where the shooter aimed, what
  the **server** said it hit (part + local offset, off the `ShotLanded` payload), and where the
  **client drew the mark** (the `Impact` Instance `Effects.puff` created). Plus a frame.
- **(d) LEVER.** Outside the repo, Director ops. The lead uses `Ballistics.timeToRange`.
- **(e)** The run itself is the measurement.

### Item 4 -- the Reviewer prompt, and `tools/agents.py`

- **(b) MEASURED NOW.** `grep -n '== "PASS"' tools/agents.py` -> five sites. Two parse a line
  (`verdict_of`, `parse_trailer`); three compare the already-normalised string (`cmd_review`'s and
  `cmd_architect`'s exit codes, and the round-tracking `prev_verdict == "PASS"`). A line reading
  `PASS (item N NOT PROVEN)` is refused by `verdict_of` today.
- **(c) TARGET.** Line 1 may read `PASS` or `PASS (...)`; both normalise to the verdict `PASS`, so
  the three downstream sites need no change and the two parsers share one helper.
- **(d) LEVER.** `tools/agents.py` `verdict_of` and `parse_trailer`, plus a `selftest` case.

### Item 5 -- prove 261 on her path

No code. The instruments above are the deliverable; 261's four items are re-measured with them.

---

## What changed

(filled in with the claims below once the code is written)
