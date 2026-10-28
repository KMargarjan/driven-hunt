# Task 305c -- at a run, the nose aim must hit

Task: 305c
Round: 1
Base: a627663d
Code commit: TBD

## PLAN

**(a) REAL LIFE.** A .416 flies 35 m in ~0.05 s; a boar at 24 studs/s covers 1.2 studs in that time,
so a bullet aimed at the NOSE arrives 1.2 studs behind it -- head, neck or front chest: a HIT. One
body length ahead is a MISS. The hitbox a shooter aims at is the animal he SEES, and a running boar
crouches: the drawn body sits lower than it does standing.

**(b) MEASURED NOW, in HER place (Forest Test, Play, `a627663d`, `AIM_REWIND=on`, range spot 1,
pace run, 24.1 studs/s).** The zone boxes are welded to the trunk at the offsets task 284 fitted to
the mesh's REST pose; the drawn animal is the mesh DEFORMED by the gait clip. Both tenses measured
with the same probe on both sides:

- `<runs-dir>/305c/deform.luau` (client) and `305c/srvdeform.luau` (server), deformation of each
  bone = `Bone.TransformedWorldCFrame` minus the rest chain `mesh.CFrame * prod(bone.CFrame)`, in
  the trunk's own axes, at RUN. **Identical on both sides**: nose dY **-0.284..-0.640** (client)
  / **-0.281..-0.641** (server); head -0.155..-0.654; Spine_01 -0.136..-0.279;
  Spine_03 -0.215..-0.407; Spine_05 -0.214..-0.453; root_bone 0.000.
- `305c/nosegap.luau` (client, RUN): the drawn nose bone sits at trunk-relative y **0.025..0.387**
  over 83 frames. `ZoneHead1`, the snout box, spans y **0.420..0.780**. **0/83 samples of the drawn
  nose lie inside ANY zone part.** At TROT (11.0 studs/s) it is 0/88, y 0.112..0.311.
- `305c/prof.luau` (client, static collision silhouette per z slice): at z -2.40 the mesh spans
  y +0.30..+0.90 and `ZoneHead1` +0.42..+0.76 -- so the 284 fit IS correct **for the rest pose**.
- `305c/sil.luau`: the collision silhouette is byte-identical frame to frame (mesh=747 head rays
  every frame), i.e. a skinned MeshPart's query geometry never deforms -- which is why the fit could
  be right and the drawn animal still be elsewhere.

**So: at a run the whole drawn boar sits 0.14-0.65 studs BELOW its zone rig, the head 0.28-0.65
below, and the snout box (0.36 studs tall) misses the drawn snout on every frame.** That is
candidate (a) of the dispatch, with numbers. It also explains the measured 3/10 exactly: the ray at
the drawn nose is in air under the head boxes, and only the ballistic 1.2 studs that carries it back
into the much taller chest/body boxes (1.64-1.76 studs) ever registers -- "CHEST 2 BODY 1".

**(c) TARGET.** Over a whole run cycle, the drawn nose lies inside a HEAD zone part on **>= 90 % of
frames** (now 0 %), with **no box grown**: every box keeps its measured size, so air above, below or
a body length ahead of the drawn animal stays a miss. Then the real-life offset puts a nose-aimed
bullet in head/neck/chest. 90 % and not 100 %: the snout box deliberately under-covers the drawn
snout's tip (task 284's own rule).

**(d) LEVER.** `src/server/Boar/Body.luau`, `buildZones` -- the only writer of a zone part's place:
```
271:			zonePart.CFrame = trunk.CFrame * CFrame.new(box.offset)
276:			local weld = Instance.new("WeldConstraint")
```
A `WeldConstraint` has no writable offset, so the weld becomes a legacy `Weld` (same name
`ZoneWeld`, `Part1.CFrame = Part0.CFrame * C0`) and `C0` is the dial: `CFrame.new(box.offset +
gaitShift)`. `gaitShift` is that box's own nearest rest-pose bone's deformation, in the trunk's axes,
clamped. New flag `ZONES_FOLLOW_GAIT` (default **off**), read once at `ServerScriptService.Boar`'s
boundary and passed inward as a parameter.

**(e) HOW IT WILL BE MEASURED AFTER.** `305c/nosegap.luau` and `305c/deform.luau`, the same probes
as (b), same place, same pace -- plus real clicks on the drawn nose with the flag off (fail first)
and on (proof), same build.

## STEP 1 -- her case, reproduced
See (b): nose-at-run inside a zone = 0/83 frames. Reproduced in her place, on her build.
