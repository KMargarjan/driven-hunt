# Task 180: the lobby looks like a real place — free-model lodge, four trucks, trophies, a road, fences and a tree line

Task: 180
Round: 1
Base: main (`253d21f`, #162 merged — task 178's shop)
Code commit: `c3e4f701b4c8bc3c3d5e24a0827a69ce3a0d15e7`

Harness, FULL `test`, TWICE on a clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ c3e4f701b4c8bc3c3d5e24a0827a69ce3a0d15e7 (clean tree) scope=all
[harness] PASS: 33/33 checks @ c3e4f701b4c8bc3c3d5e24a0827a69ce3a0d15e7 (clean tree) scope=all
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

**8. Two look bugs were found by LOOKING and are fixed, and the spec that missed each one now
catches it.** (a) The road was laid flush on the grass shelf and the first shot came back showing a
field with the player standing on the invisible lane — the grass material draws its blades over a
part laid on it. `FIELD.PAD` became `FIELD.PADS` (the yard pad widened for four bays, plus a road
corridor pad) and `Build.road` lifts the slab onto the shelf. (b) All four trophy yaws were inverted,
so every plaque sat past its wall plane and every head a stud beyond, outside the building; and the
back wall was already taken by the fireplace and the shop counter's sign.
*Verify:* commits `c865e19` and `b160d79`; `lobby.spec`, *"lays pads of a material with no grass
blades under the buildings AND the road"* and the footprint bound added to *"hangs every trophy on a
wall of the room it is in, in BOTH builds"* — the old case only looked at the height, which is
exactly why (b) got through.

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
