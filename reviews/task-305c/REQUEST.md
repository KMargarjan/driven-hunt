# Task 305c -- at a run, the nose aim must hit

Task: 305c
Round: 2
Base: a627663d
Code commit: c32004a4ea1400cf163dccb7a0d4d2b31f0b79d6

`[harness] PASS: 34/34 checks @ c32004a4ea1400cf163dccb7a0d4d2b31f0b79d6 (clean tree) scope=all`

Two players: **N/A** -- nothing under `TWO_PLAYER_PATHS`. The change is `src/server/Boar/`,
`src/shared/Flags/` and `tests/server/boar_zones.spec.luau`.

## PLAN

**(a) REAL LIFE.** A .416 flies 35 m in ~0.05 s; a boar at 24 studs/s covers 1.2 studs, so a bullet
aimed at the NOSE arrives 1.2 studs behind it -- head, neck or front chest: a HIT. One body length
ahead is a MISS. The box a shooter aims at must be on the animal he SEES, and a running boar
crouches and carries its head low.

**(b) MEASURED NOW** -- in HER place (Forest Test, Play, `AIM_REWIND=on`, range spot 1, pace run,
24.1 studs/s). Deformation = `Bone.TransformedWorldCFrame` minus the rest chain
`mesh.CFrame * prod(bone.CFrame)`, in the trunk's axes:

- `<runs-dir>/305c/deform.luau` (client) / `305c/srvdeform.luau` (server), **identical on both
  sides**: nose dY **-0.284..-0.640** / -0.281..-0.641, head -0.155..-0.654, Spine_01
  -0.136..-0.279, root_bone 0.000. In the second (head-down) run clip the nose reads dY
  **-1.648..-1.822**.
- `305c/nosegap.luau`: the drawn nose bone lies inside a zone part on **0 of 83** frames at RUN
  (0/88 at trot, 0/98 and 0/99 on later runs). `ZoneHead1`, the snout box, spans trunk-y
  0.420..0.780; the drawn nose sits at 0.025..0.387.
- `305c/prof.luau`: at z -2.40 the static mesh spans y +0.30..+0.90 and `ZoneHead1` +0.42..+0.76 --
  task 284's fit IS right **for the rest pose**.
- `305c/sil.luau`: the collision silhouette is identical frame to frame (747 head rays every frame)
  -- a skinned MeshPart never raycasts its deformed pose, which is why the fit can be right and the
  drawn animal be elsewhere.
- `305c/srv-window.luau`, before: at the drawn nose's own height the window behind it reads
  `+0.0..+0.4 Head1 | +0.6..+1.0 AIR | +1.2..+1.6 Legs | rest AIR`. The real-life 1.2-1.5 studs
  lands in a hole under the neck.

**(c) TARGET.** The drawn nose lies inside a HEAD zone part on >= 90 % of frames (was 0 %), **with
no box grown**, and the window behind it is continuous for at least 2 studs.

**(d) LEVER.** `src/server/Boar/Body.luau`, `buildZones` -- the only writer of a zone part's place:

```
271:			zonePart.CFrame = trunk.CFrame * CFrame.new(box.offset)
276:			local weld = Instance.new("WeldConstraint")
```

A `WeldConstraint` has no writable offset, so the weld is a legacy `Weld` (same name `ZoneWeld`,
`Part1.CFrame = Part0.CFrame * C0`) and `C0` is the dial.

**(e) HOW IT WAS MEASURED AFTER.** The same probes, same place, same pace.

## WHAT CHANGED

1. `Body.buildZones` makes a legacy `Weld` per zone box and keeps `handle.zoneRows`
   (`{part, weld, offset}`).
2. `Body.gaitRig(handle)` -- run once from `attachVisual` -- gives each box the bone whose REST
   position is nearest the box's centre (a rule, not a table: the deer is served by the same line)
   and stores the box in that bone's frame (`row.inBone`).
3. `Body.followGait(handle, maxStuds)` writes `C0 = trunk:ToObjectSpace(bone.TransformedWorldCFrame
   * inBone)`, translation clamped to `GAIT.MAX_SHIFT_STUDS`. The box is skinned to the bone: it
   turns as well as slides, which is what closes the neck hole above.
4. `Boar.CONFIG.GAIT` reads `Flags.isOn("ZONES_FOLLOW_GAIT")` once at the boundary; `Runtime:step`
   calls `followGait` in the loop that already holds the trunk.
5. `Flags.MAX_FLAGS` 20 -> 21, said out loud in the file as the four moves before it were.

## ITERATION (one row per cycle, same instrument both sides)

| cycle | change | drawn nose inside a zone, RUN | window behind the nose | rifle nose clicks |
|---|---|---|---|---|
| 0 | `a627663d` / flag OFF on the fixed build | **0/98** | Head1 then AIR | 3/10 (dispatch) |
| 1 | follow, translation only, clamp 1.0 | 96/105 client; **0/99** in the head-down clip (clamp bit) | -- | 6/10 |
| 2 | clamp 2.5 (measured max 1.822) | **86/94 server** (91.5 %) | `+0.6..+1.0 AIR` | 6/10 |
| 3 | box skinned to its bone, rotation too | 91 % | `Head1 Head2 Chest1 Chest2 Body3`, one 0.2-stud gap | 6/10 |

## CLAIMS

1. **The cause is measured, not inferred.** `305c/deform.luau` + `305c/nosegap.luau`: the drawn nose
   is outside every zone part on 0 of 83-99 frames at run, and the deformation that puts it there
   reads the same on the server and the client. Verify: run both probes in the Forest Test.
2. **The fix is geometric and proved on the moving animal** (rule L): server-side, the tense the
   bullet is tested in, 86/94 frames inside `ZoneHead1`. FAIL FIRST, same build, flag off: 0/98.
3. **No box is grown.** `Body.followGait` writes only `Weld.C0`; `boar_zones.spec` asserts
   `row.part.Size` is unchanged after a 4-stud bone move. Verify: grep `Size` inside `followGait` --
   there is none.
4. **Air ahead of the animal is still a miss.** `305c/srv-window.luau`: dz -0.2 and -0.4 (ahead of
   the drawn nose) read `.` on 8 of 8 frames after the fix.
5. **The flag.** `ZONES_FOLLOW_GAIT` default false, owner `ServerScriptService.Boar`, expires
   2026-11-18, read once in `Boar.CONFIG.GAIT.ENABLED` and passed inward as `gait.ENABLED` /
   `gait.MAX_SHIFT_STUDS`. OFF is the welded rest-pose rig, byte for byte.
6. **`followGait` needs no mesh** -- `gaitRig` baked it into `inBone` -- so an animal whose visual
   never attached has no wired row and the loop moves nothing. That is the grey-box world.
7. **The spec reads its rows off the real parts**, because `Runtime:spawn` hands back a narrowed
   view and not the body handle (`src/server/Boar/init.luau`, the `local handle = {` inside
   `Runtime:spawn`). That is also why round 1's first spec draft read `nil`.

## ROUND 1'S FINDING, FIXED

The finding is right: the nearest-bone comparison -- the one line the rule is -- was held by no case,
and the grey-box branch was silent. Two changes, `tests/server/boar_zones.spec.luau` only:

8. **A case that bites the sign.** `picks the NEAR bone for each box and never the far one` builds a
   hand-made carrier at the trunk's own CFrame with TWO bones at the male's real `nose` (0, 0.666,
   -2.388) and `Spine_05` (0, 0.948, 1.486) rest places, and the real `CONFIG.ZONES.head.boxes[1]`
   and `.rear.boxes[1]` offsets. It asserts the snout box took the snout bone and the rump box the
   rump bone, and that `inBone` holds exactly `offset - bonePosition` (0, -0.066, +0.138) for the
   snout. **Flip `distance < bestDistance` to `>` and both equality assertions go red.** It uses no
   bought asset, so it runs the same in every environment -- which is the second half of the
   finding. **Said plainly (V293b): the bite is argued by reading the one comparison, not by running
   a flipped build; there was no time for a second 250 s harness pass before the deadline.**
9. **The grey-box branch is no longer silent.** The first case now reads the mesh and the bone count
   BEFORE deciding, and `TestKit.note`s the branch it took. This run printed
   `boar_zones gait: mesh=nil bones=0 rows=15 wired=0 branch=grey-box` -- so the skinned branch is
   NOT exercised in DEV, which is exactly what the finding said must not be hidden, and claim 8 is
   what covers the rule instead.

The rest of round 1's notes are untouched and belong in `TASKS.md` under 305c: the per-box clamp
(2.5 studs applied to all fifteen, justified by the snout alone), `gaitRig` running in the dark
build, the two stale comments in `Runtime:spawn`/`Runtime:step`, `Body.liftDrawn`'s header, the
`hit-zones.md` section 4.3 wording (Architect's), no frame-time number, and -- the one that matters
most -- **`AIM_REWIND` pairs a 0.18 s-old trunk position with a PRESENT-pose box, an error of the
same order as the one this task fixes, and both flags are lit in Karen's place.** That is now the
first thing to measure after the click control is restored, and `ESCALATE.md` says so.

## WHAT I COULD NOT VERIFY -- the dispatch's CLICK PROOF is NOT MET

- **rifle RUN nose = 6/10, asked >= 8/10.** AND my own control is worse than the one it must be
  compared with: **chest + `Ballistics.leadStuds` reads 4/10 on this rig in this session**, where
  `reviews/task-305b/MEASURED.md` reads 9/10. 305b's own rig, changed only in the aim point, reads
  4/10 at the drawn nose, with `testedAt-firedAt` -0.078..-0.095 where 305b measured -0.126. So the
  click instrument, or the range target's pace discipline, is not the one 305b measured with, and
  **none of my click counts may be read as the game's hit rate until that control is restored.**
  `ESCALATE.md` carries the entry.
- **slug / semi-auto / red deer at the nose: NOT RUN.** The clock went on finding the cause and on
  the three geometry cycles.
- **The per-shot crossing offset relative to the DRAWN animal at the crossing instant** (dispatch DO
  item 1) is NOT measured: the rig reads the drawn nose when `ShotLanded` arrives, ~0.2 s late,
  which at 24 studs/s is ~4.8 studs of error -- exactly what the `impact-drawnNose along` column
  shows. The GEOMETRIC answer (`srv-window.luau`) is measured instead, and it is the one the fix is
  argued from.
- **Nobody has played this.** No real mouse click, no screenshot. The path is behind
  `ZONES_FOLLOW_GAIT`, which ships OFF.
- **The client/server animation PHASE is not measured.** The fix uses the server's PRESENT pose,
  which is right if the client's animator is in phase with the server's. The deformation ENVELOPES
  match exactly on both sides; the phase does not follow from that.
- `Runtime:spawn`'s comment "every zone part is ... WELDED to it ... so its offset in trunk space is
  constant" is now false with the flag on. Reported here rather than edited after the code commit.
