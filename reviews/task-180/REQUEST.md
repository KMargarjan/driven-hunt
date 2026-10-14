# Task 180: the lobby looks like a real place — free-model lodge, four trucks, trophies, a road, fences and a tree line

Task: 180
Round: 3
Base: main (`253d21f`, #162 merged — task 178's shop)
Code commit: `7f4d4fe35b3a714a6af6c06b60a4d87442620c7e`

Harness, FULL `test`, TWICE on a clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ 7f4d4fe35b3a714a6af6c06b60a4d87442620c7e (clean tree) scope=all
[harness] PASS: 33/33 checks @ 7f4d4fe35b3a714a6af6c06b60a4d87442620c7e (clean tree) scope=all
```

**`test2` is N/A and the reason is the explicit list.** The change touches
`src/server/Lobby/`, `src/shared/Lobby/` and `tests/server/lobby.spec.luau`, and not one path in
`TWO_PLAYER_PATHS` (`tools/agents.py`). A second player answers one question — who the OTHER player
is — and the lobby's lodge, trucks, trophies, road and trees look the same to one player as to two.

Karen, 2026-10-14 ~09:30, verbatim: *"let's start with lobby / we need better house we can use free
models / we need car truck model or hunting bus also use free model / place could be a bit more
nicer like road going to that house and around fields and forrests / ... and then on walls we can
make trophys like head of deer head of boar / so work on lobby now"*.

Research note: `docs/research/2026-10-14-lobby-free-models.md`, in `docs/research/INDEX.md`.

---

## Claims, and how to verify each

**1. A free Creator Store model gets into this place with no Karen click, and that is a measurement,
not a hope.** StudioMCP ships `search_asset` and `insert_asset`; a free public model nobody here owns
inserted successfully, 16 of 16 candidates. `InsertService:LoadAsset` is still shut for such a model
and a `.model.json` still cannot carry geometry — both recorded with their sources.
*Verify:* note §2 and §5; the rejection of 2a cites `docs/research/2026-09-26-asset-pipeline.md` §8,
`docs/design/beater-kit.md` §16.1 (task 152's *"User is not authorized to access Asset."*) and
`tools/studio_mcp.py`'s docstring for both the typed-value refusal and the capitals-only ban on
calling `LoadAsset` through `execute_luau`. **§8 says plainly that these four ids were NOT
re-measured against `LoadAsset`, and why.**

**2. `Build.clone` is the one place a template becomes a lobby instance, and `templates` is an
ARGUMENT.** Nothing in `Build` reads `Workspace`; the owner resolves `Workspace.LobbyAssets` at its
own boundary (`Lobby.tryBuild`, with a `world.templates` seam for a spec).
*Verify:* `src/server/Lobby/Build.luau`, `clone` and `Build.build`'s signature;
`src/server/Lobby/init.luau`, `tryBuild`. `lobby.spec`, *"builds the lodge, the four trucks and the
three trophies out of the templates"* drives it with a Folder of plain Parts.

**3. A missing template falls back to task 177's parts build, PER PIECE, and the counters say which
ran.** No folder → the whole parts lobby; the truck template alone removed → a model lodge and four
parts trucks.
*Verify:* `lobby.spec`, *"falls back to task 177's parts build when the folder is not there at all"*
and *"falls back one piece at a time when only some of the templates are there"*; `stats.models`,
`stats.fallbacks` in `Build.stats`.

**4. A script a free model smuggles in is stripped from the clone and counted, and the template is
left alone.** All four chosen models carry zero scripts — counted, not assumed — and the strip is
belt and braces.
*Verify:* `Build.scriptsIn`; `lobby.spec`, *"strips a script a free model smuggled in, and says how
many"*, which plants a `Script` named `Fire_Effect` in the fake lodge. The existing *"holds no
Script, LocalScript or ModuleScript anywhere in the tree"* case still passes.

**5. Every cloned part is anchored and every free model stands ON the shelf.** A free model ships
with whatever its builder left, and a Model's pivot is its bounding-box centre, so sitting it down is
measured with `GetBoundingBox` and never assumed from the listed size.
*Verify:* `Build.sitOnShelf`; `lobby.spec`, *"anchors every cloned part, however the free model
shipped it"* and *"stands every free model ON the shelf, not in it and not over it"* (0.05 studs).

**6. Four trucks, a bay apart, bay 1 exactly where task 177's one truck stood** — so the circle
beside it has not moved and 177's flow is untouched. Task 182's pad goes `PAD_BEHIND_STUDS` behind
each.
*Verify:* `Build.trucks`; `lobby.spec`, *"parks the trucks in a row, a bay apart, starting where
177's one truck stood"*.

**7. The road, the fences and the tree line stay inside the 220 × 220 shelf** — the same bound
`Field.fill` is held to, because the ground falls away outside it and a flat slab laid past the edge
would float.
*Verify:* `Lobby.CONFIG.ROAD` / `FENCE` / `TREELINE` and their comments; `lobby.spec`, *"keeps the
road, the fences and the trees inside the field's own rectangle"*.

**8. Four look bugs found by LOOKING, each fixed, and each now has a spec case that fails without
the fix.** (a) The road was laid flush on the grass shelf: the first shot showed a field with the
player standing on the invisible lane, because a grass material draws its blades over a part laid on
it. `FIELD.PAD` became `FIELD.PADS` (yard pad widened for four bays, plus a road corridor pad) and
`Build.road` lifts the slab onto the shelf. (b) All four trophy yaws were inverted, so every plaque
sat past its wall plane and every head a stud beyond, in the open air outside the lodge. (c) **Round
1, finding 1:** the heads were then SEATED on the floor by `clone`'s unconditional `sitOnShelf`, so a
head's bottom landed at the mount height — the deer's 5.4 studs went 2.4 studs through a 7.4-stud
ceiling. `clone` takes a `seat` argument now and the head is clamped under the room's own ceiling,
measured off its bounding box. (d) **Round 1, finding 2:** (a)'s own fix then buried the marked
circle — the yard slab sits 0.5 studs proud and the ring was lifted 0.08 studs off the SHELF, so
*"STAND HERE TO HUNT"* pointed at nothing. The ring is lifted off the ROAD surface now.
*Verify:* commits `c865e19`, `b160d79`, `9de261e`; `lobby.spec` — *"lays pads of a material with no
grass blades under the buildings AND the road"*, *"hangs every trophy INSIDE the room it is in, under
its ceiling, in BOTH builds"*, and *"leaves the marked circle standing CLEAR of the road surface it is
drawn on"*.

**8b. The round-1 guard was useless and now is not (round 1, finding 3).** It bounded a plaque
against `LODGE.SIZE / 2`, ten studs outside the wall, while an inverted yaw moves it 0.25. `roomFor`
is a pure exported function, so the spec bounds every plaque AND every head against the rectangle the
mount itself used, with floor and ceiling. The round-1 request's claim that the spec caught (b) was
**false**, and this is what makes it true.
*Verify:* `Build.roomFor`; `lobby.spec`, the trophy case.

**9. `Room` exists because there are now two rooms.** The free model's is 19.6 × 19.6 × 7.4 (raycast)
and task 177's is 38 × 26 × 9, so `interior` places against a measured rectangle and a trophy names a
WALL rather than an offset. The chimney is clamped to the ceiling for the same reason.
*Verify:* `Build.Room`, `interior`, `trophies`; `Lobby.CONFIG.LODGE.MODEL.ROOM` with the six measured
numbers; `CONFIG.TROPHIES.MOUNTS`.

**10. The superseded builder is archived, not deleted, and the four creators are credited.**
*Verify:* `backups/2026-10-14_task-180_lobby-track.txt` (rule 7, with the reason and the source as it
stood at `253d21f`); `CREDITS.md`, the new section — credited although none of the four licences asks
for it, which was Karen's instruction.

---

## Measured in the running place (Forest Test, `DHFlag_LOBBY` on), not inferred

```
[lobby] built in 28 ms: shelf y=149.2, 822 part(s), 12 terrain fill(s) (4 grass), spot 2866, 149.2, -2932
parts=822 scripts=0 house=true | Road=10 Fences=50 TreeLine=98 Lodge=336 Trucks=304 Spot=23
trophies: Plaque1 2840.3 / Plaque2 2859.4 / Plaque3 2859.4   (walls at 2840.1 and 2859.7 — inside)
```

822 parts against `MAX_PARTS` 1200. 177's flow re-proved end to end in that session: stood in the
circle → `DHLobbyLeaveAt` set → enrolled → placed at the stand (3030, −2097), team Shooters,
**Shotgun in the character**. Whole-session console: no "Stack Begin", no "attempt to", no "invalid
argument", no error line.

## Round 3: what changed

**Round 2's one blocking finding was right and is fixed.** `POSTS_PER_SIDE = 9` from z −98 at 18
studs put the WEST fence line (x +2, two studs off the lodge's own centre line) at z +46 — the
lodge's centre. A post stood inside the cabin through its floorboards, one in the middle of the porch
two studs from the doorway, and the rails lay across the `LodgeSpawn` pad at knee and waist height.
`CONFIG.FENCE`'s own comment promised *"a gap at the yard so the road is open"* and nothing
implemented it.

A COUNT CAN WALK INTO THE HOUSE AND A BOUND CANNOT: `POSTS_PER_SIDE` is now `TO_Z = -8`, four studs
south of the yard slab's own southern edge, and `fences` walks from `FROM_Z` and stops.
*Verify:* `Lobby.CONFIG.FENCE`, `Build.fences`; and `lobby.spec`, *"keeps the fence line OUT of the
yard, the porch, the spawn and the lodge, in BOTH builds"* — which asserts no `Fences` part reaches
north of the yard's southern edge and none stands inside `Build.roomFor`'s rectangle. The field
bound that was supposed to cover this is 110 studs away and passed it trivially, which is the note
round 2 made about the same case.

**Three notes fixed with it:** a tree may no longer stand in the YARD either (the arc's eastern end
swings past the fourth bay — the same mistake as a tree in the road); `ROOM.HALF` is `HALF_X` /
`HALF_Z` by name instead of a `Vector2` whose `Y` secretly meant z, where both being 9.8 made a swap
invisible; and `cloneInstance`'s unseated branch corrects all three axes, so a replacement head with
a `PrimaryPart` cannot hang off its plaque sideways. `ROAD.FROM_Z`'s comment now says what 56 is —
past the front wall and under the floor — rather than "the lodge's front", which it is not.

**Not taken, queued for the Director:** the `corners()` coverage on the road/tree case (the new fence
case bounds the thing that mattered); `docs/design/lobby.md`'s `MAX_PARTS = 400` and track row
(Architect's lane); and `CONFIG.TRACK`, dead until task 182.

**Corrected from round 2's own paperwork (rule 8):** the pasted `ceiling y = 160.9` was wrong
arithmetic on my part — `shelf 149.2 + 3.3 + (10.7 − 3.3)` is **159.9**. The conclusion is unchanged
(the heads' tops are at 159.6, so they are under it either way), but the number was not the config's.

## Round 2: what changed

Three blocking findings, all three correct, all three fixed — plus four of the nine notes: the tree
line now goes through `cloneInstance` (its hand-rolled walk used `GetDescendants`, which never visits
the clone itself, so a Part template came out unanchored and queryable — the one thing that function's
own comment forbids); the shop counter is clamped so a 12-stud till cannot come through a 9.8-stud
half-room; the owner's `stats` carries `strippedScripts`; and the room is 19.6 × 19.6 in every file
instead of 19.6 in one and 19.8 in two. The `TREELINE` comment now says what the numbers do (a ±34°
gap due north, not "south-east round to south-west").

Measured in the running place after the fixes, which is how (c) and (d) are known to be gone:

```
ringClearOfYard = 0.02 studs   (it was -0.42: inside the slab)
Plaque1/2/3 y = 156.9    BoarHead2 / DeerHead1 / DeerHead3 y = 156.9    ceiling y = 160.9
```

— the heads were at 158.0 and 159.6 before, their bases on the mount instead of their centres.

**Notes NOT taken, queued for the Director:** the `corners()` coverage on the road/fence case (the
geometry is inside today, so it is coverage and not a defect); a `north` or `south` mount would now
pass correctly since the bound is the room; `docs/design/lobby.md`'s `MAX_PARTS = 400` and track row
(Architect's lane); `CONFIG.TRACK` dead until task 182; and the road lying 0.5 studs proud of the
walkable terrain with `CanCollide = false`.

## What I could not verify, and what is wrong that I did not fix

1. **That `LoadAsset` refuses these four ids** — claim 1, note §8. Rejected on recorded evidence, not
   measured, because the only instrument available is the one the harness docstring forbids.
2. **That the models survive a Studio restart.** `Workspace.LobbyAssets` is Edit-mode Studio content
   until the Forest Test place is **saved**, which only Karen can do. Until then the fallback parts
   build is what she gets — which is task 177's lobby exactly, so nothing breaks.
3. **A `Session/Bush` stands in the new road** at (2871, −2965) — pre-existing Studio content from an
   earlier session, 15 m across, and it blocks the view up the road to the lodge. **Not touched**: it
   belongs to another owner and the lobby must not become a writer of `Workspace.Session`. It is the
   only such object in the road; 15 `OurForest` models also sit inside the field, all at the northern
   edge, where they help rather than hurt.
4. **The boar head reads cartoonish in game** — big flat eyes — where its Creator Store thumbnail
   looked realistic. It is one row in `CREDITS.md` and one id to swap. Karen's call.
5. **`tools/flags.py` cannot aim at the second place.** `run_flags` resolves "the editor" through
   `studio_for_role`, and with the DEV and Forest Test Studios both in Edit it cannot be told which,
   so `DHFlag_LOBBY` had to be set on the Forest Test's `ServerStorage` by hand for the playtest.
   Reported rather than worked around (rule 6); nothing was committed, and DEV's attributes were
   checked empty before and after every harness run.
6. **`screen_capture`'s camera arguments are edit-time only**, so no Play screenshot can be framed
   from an arbitrary point; the two shots are the player's own view, aimed through the camera owner's
   `DHLookAt` seam. Not a defect, but it is why the framing is a player's and not a camera's.
