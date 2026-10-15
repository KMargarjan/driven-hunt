PASS

Verified against the repo this round, not taken on the request's word:

- Round 3's blocking finding is really fixed. `lodge` now builds `Antlers.OverTheDoor` with
  `cfg.TROPHIES.DOOR` at `(doorTop + LINTEL_STUDS + underEave) / 2`, yaw **0** (`shield`'s own
  convention: `R_y(0)·(0,0,-1) = -Z`, and -Z is south = outdoors, so the skull plate and both beams
  project into the yard, not into the roof void), then `fitBetween(doorMount, doorTop + 0.2,
  underEave - 0.2)`. Measured: band `origin.Y + 12.0 … 14.64`, mount span before the clamp
  `12.822 … 15.288`, shift `-0.6456`, final `12.177 … 14.643` — inside the band, above the lintel,
  south of the wall plane. The big stag moved to `Antlers.EastGable` at `wallTop + 3.4`, yaw
  `-pi/2` (LookVector `+X`), clamped into `wallTop + 0.4 … ridge - 1.2`; the gable wedges really are
  the west/east ends (`Gable%s%s` at `origin.X ± (SIZE.X/2 - 0.45)`), so that wall exists, and the
  mount's top (~26.6) clears the slab underside at the ridge (~27.7).
- The new case can fail and tests the player's path: "hangs the OUTSIDE antlers clear of the roof,
  facing out of the building" projects each part's rotated box (`m10/m11/m12`), splits on
  `DoorStag`, and bounds height above `DOOR.HEIGHT`, top under the eave and `Position.Z` south of
  the wall — the round-3 build (`doorTop + 5.2`, yaw `pi`) fails all three. `doorParts > 3` /
  `gableParts > 3` stop a bound nothing satisfies.
- Round 2 finding 2 is fixed: in "really CUTS the door and every window…" the build is `pcall`ed,
  every failure is a string in `problem` / `filled`, and `other:Destroy()` precedes the first
  `expect`. Nothing can leak an enabled `SpawnLocation` at x 2850 into `Workspace` again.
- Claims 1, 3, 5, 6, 7, 9, 10 check out: `snapOpening(floorY, floorY+3.4, floorY+7.8, 1.8)` =
  `(+3.6, +7.2)` and `logWall`'s strict test drops exactly courses 3-4, which is the band
  `WindowGlass` fills, so the spec's 0.15-stud walk matches within `step*2`; the north window at
  `-11` leaves a 2.7-stud run (at `-13` it was 0.7 < `d*0.6`, the dropped sliver); `TEMPLATE` has
  only `TRUCK`/`TREES` with the removed rows and ids archived in
  `backups/2026-10-14_task-187_free-lodge.txt` (rule 7); `roomFor` = 32.4 × 22.4 × 12.6;
  lights = `1 + #LANTERN.ALONG(3) + 2` = 6; `#MOUNTS` = 12; `MAX_PARTS = 1500`; the keeper's head
  gets `HeadColor3` on every `BodyColors` (created if none), a `rbxasset://` Decal, and `Body.paint`
  still never writes `HeadColor3` — no second writer.
- Paperwork gate: `[harness] PASS: 33/33 @ 35afd577… (clean tree)` names the request's
  `Code commit:`, `[harness2] PASS: 35/35 @ 35afd577… (clean tree)` is pasted, and
  `paperwork-after-code-commit.txt` says OK (only `ESCALATE.md` and `reviews/task-187/REQUEST.md`
  follow it). selene, stylua and `rojo build` are all exit 0. No conflict markers survived the
  merge; no absolute user path, email or key in the diff.

## Notes (non-blocking)
- `src/server/Lobby/Build.luau` `lodge` — the door band is measured at the WALL PLANE while the
  mount stands south of it. `underEave = wallTop - THICK/2/cos(pitch)` = `origin.Y + 14.843` is the
  slab underside at `z = origin.Z - 13`, but the beams lean out to `z = origin.Z - 13.99`, where the
  44° underside is `≈ origin.Y + 13.88`. After the clamp the upper segment of each beam and both
  tines sit INSIDE the south slab: the top tip is `(z = -13.894, y = +14.591)` against an underside
  of `+13.980` — 0.44 studs perpendicular into a 0.8-stud slab, so nothing emerges through the
  slate, but roughly the top 0.6 studs of a 2.5-stud mount are swallowed by the soffit. Subtracting
  `tan(pitch) * (halfZ + the mount's own reach)` from the band, instead of using the wall-plane
  figure, is the fix. `lobby.spec`'s case recomputes the same wall-plane `underEave`, so it cannot
  see this.
- `src/server/Lobby/Build.luau` `doorway` — "The leaf stands OPEN against the wall beside it" /
  "it stands beside the opening rather than in it" describes the opposite of what is built. With
  `CFrame.Angles(0, -LEAF_OPEN_RADIANS, 0)` and `R_y(t)·(a,0,0) = (a cos t, 0, -a sin t)`, the
  translation comes back as **+3.44 in local Z** — inward — so `DoorLeaf` runs from the hinge at
  `(origin.X + 4.05, origin.Z - 13.3)` to `(origin.X + 2.80, origin.Z - 6.41)`, i.e. 4.8 studs into
  the room, crossing `DoorPostE` on the way out. An inward-opening door at 100° is not wrong and the
  leaf is `CanCollide = false` and clear of the walk line, but this is the one offset in the task
  where the "-Z is out" convention the rest of it fixed is still inverted; either flip the sign or
  rewrite the comment to say the leaf opens inward.
- `reviews/task-187/REQUEST.md` — "`[harness2]` is **N/A**: no file this branch touches is in
  `TWO_PLAYER_PATHS`" and claim 10's "`src/server/Match/` is untouched" are stale after the merge at
  `35afd57`: the commit under review changes `src/server/Match/Body.luau`, `Scene.luau`, `init.luau`
  and `tests/server/match_place.spec.luau` relative to the base. True of task 187's own commits, and
  the `[harness2]` line is pasted anyway, so the evidence is complete — only the sentences are
  wrong.
- `src/server/Lobby/Build.luau` `roof` / `porch` — round 3's note, unfixed: `EAVE_STUDS` is added to
  the slab's length, so the real eave edge is `(z = origin.Z - 15.441, y = origin.Y + 13.034)` and
  not `porch`'s `eaveZ` (-16.4) / `eaveY` (+12.1); the lean-to still hangs off a point the roof does
  not reach, with `PorchRoof`'s `+ 0.8` padding closing most of the slot.
- `src/server/Lobby/Build.luau` `windowUnit` — round 3's note, unfixed: `WindowJamb`/`WindowHead`
  are `f * 2.2` = 1.1 deep centred 0.1 out, so they stop 0.65 studs from the wall plane against the
  log's 0.9-stud outer surface. The sill (1.35) and the shutters (to 2.44) are proud of the logs;
  the frame is not.
- `docs/design/lobby.md` / `docs/design/truck-pads.md` — the Architect's files, so citations rather
  than edits here: `MAX_PARTS = 400` and "cap 400" in the first, "`<= MAX_PARTS` (1200), unchanged"
  and "`LODGE.MODEL`'s comments" in the second, all now wrong. The request already queues §9's
  "two builds, free model first".

---
REVIEWER verdict on commit `27b1623ac25dc8955ad868b627504d3376398088` (round 4) · 2026-10-15 23:44 UTC · session cost $4.23, 43 turns · written by tools/agents.py
