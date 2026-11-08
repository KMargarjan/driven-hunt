# One cell at a time, and no land nobody hunts on (task 337)

Karen, 2026-11-08: *"so we will need to optimize, we only load one per game thats it"* and
*"so rest part of map we can remove we can only focus on those what we have from A1 ect /
outsource also best practicisess"*.

## 1. What the system must do

The grid world has eight drive cells (`Grid.CELL_ORDER`). A round is played in **one** of them
(Karen's map vision, 2026-11-01: one cell per round). Two things follow, and neither is true today.

1. **Only the round's cell is standing.** A planted cell's wood must exist, but a cell that is not
   being hunted must not be in `Workspace`: not drawn, not replicated, not raycast against. Changing
   the active cell swaps them on the server. Planting a cell must never destroy another cell's wood.
2. **The world is the grid plus what the player uses to reach it.** Terrain and parts outside the
   footprint and its 300-stud margin -- except the lobby, the lodge, the shooting range, the spawn
   and the templates -- are land nobody hunts on, and they cost memory, boot time and file size.

### The numbers this note is written against (MEASURED, Forest Test, 2026-11-08, before any change)

| Reading | Value | Instrument |
|---|---|---|
| `Workspace` in a Play session | **75,008 instances / 31,437 parts** | `337-census.luau` (server) |
| ...of which OUTSIDE footprint+300 | **21,841 parts (69 %)** | same |
| `OurForest` (legacy Studio wood) | 24,192 inst / 9,901 parts, all outside | same |
| `DrivePlaces` (the 4 pre-grid line places, re-planted every boot) | 21,173 inst / 9,105 parts, all outside | same |
| `GridForest` (C1's prebuilt wood -- the one playable cell) | 20,518 inst / 9,318 parts, all inside | same |
| `Lobby` + `LobbyAssets` + `Range` + spawn (THE KEEP SET outside) | 1,634+452+50+1 inst / **1,288 parts** | same |
| Terrain occupied extent | **x[-7000..7000] z[-7000..7000]**, 841/1,681 lattice nodes hit | `337-terrain.luau`, 500-stud lattice |
| Footprint + 300 margin | x[-7000..-1910] z[-6900..-3314] = 5,090 x 3,586 | `Grid.footprint()` |
| Frame time, camera at C1 stand 8 | mean **21.91 ms**, p95 **28.56 ms** | `337-frametime.luau` (client) |
| `Workspace.StreamingEnabled` | **true**, min 384 / target 512 | `337-streaming.luau` |

The keep region is **8.7 %** of the occupied terrain's area. 69 % of the parts stand outside it, and
1,288 of those 21,841 are the lobby, the range and the spawn.

## 2. The sources

### A. Roblox -- Instance streaming
<https://create.roblox.com/docs/workspace/streaming> and
<https://create.roblox.com/docs/reference/engine/classes/Workspace#StreamingEnabled>
Licence **CC BY 4.0** (`creator-docs`, <https://github.com/Roblox/creator-docs/blob/main/LICENSE>).
First-party, maintained. Fetched 2026-11-08, 200.

*Good:* it is the engine's own answer and it is already on in this place. Stream-out **parents an
instance to nil rather than destroying it**, so Luau state reconnects when it streams back in -- the
exact shape this task wants for a cell.

*Bad, and it is why this task exists:* **streaming is a CLIENT optimisation only. The server holds
the whole world.** The page addresses no server-side reduction; streaming decides what is *sent* to a
client, never what the server keeps. Measured here: streaming is on at target radius 512 and the
server still holds 31,437 parts, of which 21,841 are more than 2,800 studs from any stand. It also
cannot help the two costs Karen named -- boot time and place size.

### B. Roblox -- ServerStorage
<https://create.roblox.com/docs/reference/engine/classes/ServerStorage> -- same licence, fetched 200.

*Good:* **"Not Replicated"**. A model parented there is on the server, addressable, reaches no
client, is not rendered and is not in `Workspace`'s spatial queries. That is precisely "stored, not
drawn". The documented idiom is the one we need: keep the map there, move it into `workspace` to
make it live.

*Bad:* it is storage, not a system. It offers no reconciliation, no epoch and no cost accounting;
all of those are ours to write. And a move is not free -- the parts are re-added to the physics and
render world on the way back.

### C. Unreal Engine 5 -- World Partition
<https://dev.epicgames.com/documentation/en-us/unreal-engine/world-partition-in-unreal-engine>
Epic's documentation (proprietary, free to read); maintained first-party. Fetched 2026-11-08.

*Good:* the pattern we are copying, stated plainly. One persistent level, subdivided into **streamable
grid cells**; at runtime only cells near active streaming sources are loaded, and cells load and
unload by distance from a source. The vocabulary -- cell, streaming source, load/unload -- is this
grid's own, and it tells us the right owner shape: the **world** owns which cells are loaded, and the
cell knows nothing about who asked.

*Bad:* it is distance-driven and continuous. This game's selector is not a distance, it is **the
round's cell** -- one discrete fact, chosen by the drive. Borrowing the distance half would invent a
problem we do not have. So we take the cell/load/unload shape and NOT the streaming source.

### D. Unity -- additive scene load / unload
<https://docs.unity3d.com/ScriptReference/SceneManagement.SceneManager.LoadScene.html> and
<https://docs.unity3d.com/Packages/com.unity.addressables@2.0/api/UnityEngine.AddressableAssets.Addressables.UnloadSceneAsync.html>
Unity's documentation (proprietary, free to read); maintained first-party. Fetched 2026-11-08.

*Good:* the explicit load/unload pair, and the warning that matters to us: `UnloadSceneAsync`
**destroys** every GameObject in the scene. Unity therefore has to re-create the content on the way
back; Roblox does not, because a `Parent` move keeps the instances. This is the argument for
**moving, not destroying**: it is cheaper and it is reversible.

*Bad:* `LoadSceneAsync` is asynchronous with an activation handshake, which we have no equivalent of
and do not need -- a `Parent` write is synchronous here. The async machinery would be imported cost.

### E. Minecraft -- chunks
<https://minecraft.wiki/w/Chunk> -- Minecraft Wiki, **CC BY-NC-SA 3.0**; community-maintained, active.
(This repo already borrowed its per-chunk determinism rule in `docs/design/drive-places.md` 10.1 and
`Places.plantCell`'s header.)

*Good:* two rules worth stealing. **The server keeps only the chunks near active players in memory** --
server-side, not client-side, which is the half Roblox streaming does not do. And a chunk's content is
a pure function of its seed and coordinates, so unloading loses nothing that cannot be rebuilt --
which is already `Grid.seedFor`'s property here.

*Bad:* Minecraft's loaded set is a radius around every player and it has **spawn chunks** that are
always loaded. Both are answers to a continuous, many-player, infinite world. Ours is one cell chosen
by the drive, so copying the radius would be inventing a selector.

## 3. The pattern adopted, and why

**Borrowed (rule 2):** Unreal's *cell / load / unload* vocabulary and owner split (C); Roblox's own
stream-out semantics -- **detach, do not destroy** (A) -- implemented with the one container the
engine documents as not replicated (B); Unity's load/unload pair as the interface shape, with its
destroy-on-unload refuted by (A) and (B); Minecraft's *the server keeps only what is being played*
and *the content is a pure function of the seed* (E).

**Invented, with its reason (rule 2):** nothing in the mechanism. One thing is ours because no source
has it: the **selector is the round's cell, not a distance**. Every source above drives loading from a
position; this game already has a drive that names a cell, and a distance rule laid over it would be a
second, disagreeing answer to a question that is already decided -- the defect `Map.EXPECTED_WORLD`
and `Places.isPlanted` were both written to avoid (CLAUDE.md rule 3, one owner per system).

**Reconciled, never event-driven (lesson L-029).** "Only the round's cell is in `Workspace`" is a
desired state, not an action. It is checked at boot and at every swap -- what is in `Workspace`
against what should be -- rather than being whatever the last plant or swap call happened to leave.
A keep set computed per call is what let task 335 fell a stored forest; a reconciliation cannot.

**The liveness rule (lesson L-093).** `Places.isPlanted` reads the static `Grid.PLANTED_CELLS` table.
Once cells move in and out of `Workspace`, "planted" has two possible meanings -- *has a wood
somewhere* and *is standing now* -- and the skirt rule, `cellCapacity` and the stand types all read
it. The two facts must be named separately and the live one must be read from the world, not from a
table.

**The world trim is archive-first (rule 7), and its halves are not equally reversible.** Parts are
*moved* to an archive folder with a note: reversible with no backup. Terrain cannot be moved, so its
removal is covered by the place backup and by nothing else -- which makes the backup a precondition
of that half and of that half alone.

## 4. The numeric targets

| # | Target | Why that number | How it is measured |
|---|---|---|---|
| T1 | A non-active cell contributes **0** parts to `Workspace` | "only load one per game thats it" | census: `Workspace` holds exactly one cell folder |
| T2 | Planting cell X leaves cell Y's stored wood with **the same model count** it had | task 335's keep-set destroy | count Y's models before and after planting X |
| T3 | `Workspace` parts outside footprint+300, after the trim: **<= 1,400** | the keep set measures 1,288; 1,400 is that plus 8 % | `337-census.luau`, same instrument as the before |
| T4 | Terrain outside footprint+300 and outside the lobby/range box: **0 lattice hits** | the trim either happened or it did not | `337-terrain.luau`, same lattice |
| T5 | Boot to lobby, and client join-to-gun: **no worse** than before | the trim must not cost what it saves | `smoke.sh`, same script |
| T6 | Frame time at a C1 stand: **no worse** than 21.91 ms mean | HONEST BOUND, NOT A WIN -- see below | `337-frametime.luau`, same stations |

T6 is written as a bound rather than a gain deliberately. The measured 21.91 ms at C1 is **C1's own
wood**, not the land being removed: with `StreamingEnabled` true and a 512-stud target radius, a part
6,000 studs away is not on the client at all. `Places.PART_BUDGET_CELL` (8,000) and `grid-terrain.md`
12.2's 16.7 ms are the dial that moves that number, and they are a different task.

## 5. What this note does not decide

The owner, the module boundaries, the folder names, the swap's call site and whether the trim is a
`tools/` command or a `src/` boot step are the Architect's (`tools/architect.sh design cell-loading
--task 337`, `reviews/task-337/BRIEF.md`).
