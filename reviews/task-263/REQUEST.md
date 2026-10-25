# Task 263 -- the proof tools

Task: 263
Round: 1
Base: fd5d20c5
Code commit: bd98612d90b4fadb94fa4fcc81d6ba029fa3d206

```
[harness] PASS: 34/34 checks @ bd98612d90b4fadb94fa4fcc81d6ba029fa3d206 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS`. The change is
`src/client/Camera/` (named in CLAUDE.md's exempt list -- *"the weapon, the viewmodel, the camera,
the boar, the hud, the sound and the tools"*), its client spec, `tools/agents.py` and two docs.

## PLAN (core quality protocol, step 0 -- committed at `73816945`, before any `src/` edit)

The dispatch names three blockers. **Two are refuted by measurement**, and the protocol says a
refuted premise is a finished item, not a failure. The readings are in the plan commit; the ones
that decide the code are repeated as claims below.

## What changed

| File | What |
|---|---|
| `src/client/Camera/TestLook.luau` | NEW. The one reader of `DHTestLook` / `DHTestLookOff`: a **held, level-triggered, Studio-only** look. Pure resolver + an `IsStudio` gate |
| `src/client/Camera/init.luau` | requires it, exports it for the spec, applies it once per frame after `Mode.step` beside `Poses.holdState`, counts `stats.testLookFrames` |
| `tests/client/camera_client.spec.luau` | four cases: both gate branches by parameter, the release, the refusals, and the real camera held and given back |
| `tools/agents.py` | one `verdict_from_line` helper read by **both** `verdict_of` and `parse_trailer`; `PASS (item N NOT PROVEN)` is a pass; 12 selftest cases |
| `docs/REVIEWER_PROMPT.md`, `docs/REVIEWER_RULES.md` | the Learning Agent's RULE 3, verbatim, plus how to do it read-only |
| `<runs-dir>/aimshot.py`, `<runs-dir>/263key.ps1` | outside the repo (Director ops): the shot instrument, and a keystroke the engine can map |

## Claims

**1. `DHTestOwns` ALREADY arms every gun, and the dispatch's ids are not this build's -- so item 1
needed no code.** The shop sells `rifle.scoped`, `rifle.lever`, `shotgun.semiauto`
(`Shop.ITEM.RIFLE` / `.LEVER` / `.SEMIAUTO`); `weapon.rifle` and friends are refused by
`Economy.testOwnsFor`, which checks `ShopData.anyRow`.
*Verify:* read those three constants in `src/shared/Shop/init.luau`, and `Economy.testOwnsFor`'s
`ShopData.anyRow(id) ~= nil` branch. **Measured in the Forest Test, 2026-10-25**, probe
`<runs-dir>/263-loadout.luau`: with the attribute set,
`team=Shooters held=[Shotgun] backpack=[Lever,Rifle,SemiAuto]`.

**2. He can SWITCH to all four, with real keystrokes, in a drive -- and the thing that could not was
an ops tool.** `<runs-dir>/key.ps1` sends `keybd_event` with the virtual key and **no scan code**;
every digit arrived at `UserInputService` as `KeyCode.None`
(`<runs-dir>/263-keyspy-arm.luau` recorded `LeftAlt/false None/false` per press). `263key.ps1` adds
`MapVirtualKey` **and a throwaway press** -- the first key after the foreground Alt-tap is swallowed,
measured: `R` arrived as `None` and `M` a second later arrived as `M`. After the fix the recorder
read `Two/false`, `Three/false`, and the loadout probe read, in order:
`held=[Rifle]`, `held=[Lever]`, `held=[SemiAuto]`, `held=[Shotgun]`.
*Verify:* the four lines are in the report; the frames are
`<runs-dir>/263-gun-{1-shotgun,2-rifle,3-lever,4-semiauto}.png`. **I looked at `263-gun-2-rifle.png`:
the ornate scoped Rigby fills the lower frame, the hip circle is yellow, the readout reads `9 .416`,
and the Hud says `DRIVE 1 / 3:41 / HUNTER`.**

**3. `DHLookAt` already points the running camera; task 258's `moved=0.0000` was the fresh-module
trap.** `<runs-dir>/263-camlook.luau`, a **client** probe: `tookIt=true moved=84.8599 deg
offTarget=0.00 deg`. So the dispatch's second premise is refuted too.
*Verify:* `Camera.start`'s `GetAttributeChangedSignal(LOOK_AT_ATTRIBUTE)` connection in
`src/client/Camera/init.luau`, which calls `Camera.lookAt` and clears the attribute.

**4. What `DHLookAt` CANNOT do is the thing an aiming instrument needs, and that is the code.** It is
an edge-triggered one-shot whose handshake is a write by the owner. Measured, server probe
`<runs-dir>/263-camlook-server.luau`: the first write lands (a client read showed
`camLook=-0.000,-0.001,1.000`, the asked-for +Z) but **the server's copy is never cleared** --
`serverCopyAfter1 == serverCopyAfter2 ==` the point, because the client's clear is a client write to
its own `Player` and does not replicate up. So a repeat of the same point from the server changes no
property, fires no changed signal and is silently dropped -- and a probe aims from the server,
because that is the side that can see the animals. It also holds nothing and has no `IsStudio` gate.
*Verify:* the two measurements, and the absence of any `RunService` read in that connection.

**5. `Camera.TestLook` is level-triggered, held, and THE CAMERA NEVER WRITES THE ATTRIBUTE.** That
one property removes all three faults at once: no handshake to break, re-asking is idempotent, and
the view stays put while a real click travels through the window.
*Verify:* `TestLook.point` and `TestLook.current` contain no `SetAttribute`; the call site in
`Camera.update` reads and assigns `state` only. `Rig.apply` is still the one writer of
`workspace.CurrentCamera`, and the hold drops a running `faceTowards` rather than fighting it.
**Measured AFTER, same instrument as before**, `<runs-dir>/263-testlook-server.luau` (server) +
`263-testlook-client.luau` (client):
`AIMED AT Boar19 species=boar range=31.7 ... serverCopyStillSet=true` and
`CLIENT sees DHTestLook=3057.052490,146.069748,-2081.640869 | offTarget=0.0000 deg`, with the point
written **twice to exactly the same value** -- the case the old attribute drops.

**6. Studio-only, with BOTH branches asserted, and the production branch only reachable by
parameter.** Inside a Studio session `RunService:IsStudio()` is always true, so
`TestLook.point(isStudio, raw, off)` takes the gate as an argument -- `Economy.testGrantFor`'s own
reason, quoted in the file.
*Verify:* `tests/client/camera_client.spec.luau`, `describe("the Studio-only held look")`:
`point(true, "10,20,30", nil)` is the Vector3 and `point(false, "10,20,30", nil)` is `nil`.
**Delete the producer:** gut `TestLook.point`'s body to `return nil` and the first case fails; gut it
to `return Vector3.new(...)` ignoring `isStudio` and the second fails. The fourth case
(`moves the REAL camera, holds it there, and gives it back`) fails on `steered >= 8` if the call in
`Camera.update` is removed, and on `expect(player:GetAttribute("DHTestLook")).to.be.ok()` if anyone
ever adds the old clearing handshake.

**7. The hold is proved HELD, not snapped, by the owner's own counter.** `stats.testLookFrames` is
incremented only in `Camera.update`, and the spec asserts `>= 8` of 12 rendered frames and then that
it **stops** rising after `DHTestLookOff`. A one-shot steers exactly one frame.
*Verify:* the only `testLookFrames +=` in the repo is inside that `if testLook ~= nil` branch.

**8. `aimshot.py` produces the three numbers from ONE REAL CLICK, and they are not the same engine
identity.** The server side is the **replicated payload** (`ShotLanded`'s `parts` / `impacts`); the
client side is the **Instance** `Effects.puff` built from it, recorded by a `DescendantAdded`
watcher because `Shotgun.CONFIG.IMPACT_LIFETIME` is 1.0 s and the first run of the tool read at 2.0 s
and honestly reported "no Impact instance drawn" for a client that had drawn nine.
*Verify:* the run, verbatim, `<runs-dir>/263-aimshot-h5.png`:
```
TARGET Boar91 species=reddeer kind=calf range=146.2 speed=4.5 flight=0.0580 ...
AIMED heldFrames=0 offTarget=0.000 deg camLook=-0.246,0.136,-0.960
CLICK rawclicked 960,620
AFTER-CLICK offTarget=0.000 deg camLook=0.841,-0.035,0.541
  || SERVER ZoneHead(head) @ 3352.76,169.66,-3196.78 local 0.015,0.174,1.351
  || CLIENT Attachment @ 3352.76,169.66,-3196.78 (under ZoneHead)
```
**I looked at the frame.** The scoped rifle fills the lower half; a hit card bottom-left reads
`HIT - .416` over a boar silhouette with the red diamond **on the head**; the kill line reads
`Alhamdulilah824 FEMALE BOAR head 27 m RIFLE`; a dark animal stands centred at mid-distance with the
green hit ring on it; a high seat is on the left and the Hud reads `DRIVE 2 / 3:30 / HUNTER`.
**The two camLook vectors differ and that is the instrument, not the camera:** it re-aims before the
trigger because the animals move during the reload, so it fires at the nearer one -- the hold was
`0.000` degrees exact at both readings. The tool now prints that `RE-AIM` line; two earlier runs read
as a camera swinging 180 degrees until it did.

**9. `heldFrames=0` in that run is a tool limit, written down, not a failure.** A `require` from a
probe gets the command bar's own copy of the module (L-109), so `Camera.stats()` read there is a
fresh zeroed table. The hold is proved by `offTarget`, by the attribute still being set, and by the
spec, which runs inside the real client's module cache. `aimshot.py`'s header says so.

**10. `tools/agents.py` reads `PASS (item N NOT PROVEN)` as a PASS in BOTH readers, and the Reviewer
prompt carries RULE 3 verbatim.** L-030 named five `== "PASS"` sites: two **parse a line**
(`verdict_of`, `parse_trailer`) and now share `verdict_from_line`; three compare the
already-normalised string (`prev_verdict == "PASS"` in the round check, and the two exit-code
`return 0 if v == "PASS"` lines) and need no change because the helper normalises to `"PASS"`.
*Verify:* `grep -n '== "PASS"' tools/agents.py` -> three sites, all comparisons.
`python tools/agents.py selftest` -> 12 new cases, including `PASSING`, `PASS: 3 notes`,
`PASS (unclosed` and `PASS extra (item 1 NOT PROVEN)` still refused, and
`parse_trailer(body) == (2, "PASS")` so the round count is unchanged by the new form.

## What I could not verify

- **Item 5 -- proving task 261's items 1 to 4 on her path: NOT DONE.** The 2.5-hour stop arrived
  with the instruments built and proven and this not started. 261's items 1, 2 and 3 stay
  `NOT PROVEN`, and item 3 is CORE. The only 261 fact that came out of today's sessions is
  incidental and is not a proof of its item 2: role alternation was observed again live
  (`team=Shooters held=[Shotgun]` in one drive, `team=Drivers held=[Horn]` in the next).
- `blockedByTerrain` and the line-of-sight filter were added after the first aim landed `0.0000`
  degrees off a boar 31.7 studs away whose frame shows **a bank of road** -- the animal was behind a
  rise. That frame (`263-animal-centred.png`) is therefore **not** a frame of a centred animal and is
  not offered as one; `263-aimshot-h5.png` is.
- `aimshot.py`'s `CLICK_XY` is the Forest Test viewport centre on this machine's monitor layout. It
  is a constant in an ops file, not measured per run.
- Two `aimshot` runs printed `SERVER armed || CLIENT armed` -- the trigger was refused. One target
  was 155.9 studs away with a 100-stud shotgun; the other was the per-shell reload (L-023). The real
  `R` keystroke was added for the second. Neither was investigated past that.
