# Task 358 -- BRIEF for the Architect (design)

**Written by the Builder, carrying the Director's dispatch of 2026-11-13.** Read this first; it
overrides anything older in `docs/`, `TASKS.md` or an earlier design.

## What Karen sees

Karen, 2026-11-10: *"animal died and then stand and then again die"*. After this task: shoot any
animal (boar, deer, stag); it falls and stays down until it is removed, **on her screen**, every
kill. Nothing else about death changes (the fall, where it lies, the drag/claim, the score).

## The decision already taken (the Director's, not the Architect's)

1. **There is to be a CLIENT-SIDE OWNER of the dead animal's DRAWN pose.** The server stays the one
   owner of death itself -- when an animal dies, where it lies, when the carcass is removed, the
   collapse, the roll, the anchor, the score. The new owner decides only *what this client draws on
   an animal the server has already called dead*.
2. It ships **behind a feature flag born OFF** (`src/shared/Flags/init.luau`, `default = false`,
   `expires` within 21 days), reachable **by parameter as well as by flag** so both states are
   testable.
3. `src/server/Boar/` keeps its death logic. The only server change contemplated is **publishing data
   the client cannot otherwise have** (see 6 below) -- no new server behaviour.

## What was MEASURED first, in Karen's Forest Test, before any code (the readings)

Instrument: `<runs-dir>/358-cli.luau` (per-Heartbeat reading of the drawn bone span of every
carcass; the 344b sampler read it every 0.5 s and the event is shorter than that).

| reading | result |
|---|---|
| a 480 s drive, 19 kills, 4 kinds | **0 pops / 19 kills**, longest 0.00 s (`358-BEFORE-cli.txt`) |
| the server's own repair forced 80 times (`358-stage.luau` stops the held death track; the server's `shouldRehold` / 6 s re-assert then replays it: `Play(0,1,0)`, `TimePosition`, `AdjustSpeed(0)`) | **0 client pops / 80 repairs** -- the drawn span never moved (`358-BEFORE-staged-cli.txt`) |
| a client track stopped with the bones left alone | the pose **stays**; no track is writing, and the bones keep their last Transform (`358-clipop.luau`: before 1.05, after 12 s 1.05, 0 tracks) |
| the state 344b actually logged on its one standing carcass (`drawn=none`, span 3.07 where lying was 0.90) reproduced -- no track AND the bones at bind, which is a rig that **streamed in and never received the death** | hind 1.05 -> **4.94**, hind 1.04 -> **4.93**, cub 1.01 -> 1.35; **recovered NEVER in 12 s, 3 of 3** (`358-bind.luau`) |

**So the dispatch's stated cause is refuted and a worse one is measured.** The 6 s re-assert does
not pop a carcass (0 in 80 forced repairs, 0 in 19 kills). What *does* put an animal back on its
feet is a client whose rig has **no pose at all** -- bind pose, which for every one of these animals
is standing -- and that client **never recovers**, because the server's re-assert is one-shot
(`handle.reasserted`) at `CARCASS_REASSERT_SECONDS` and `Body.shouldRehold` only fires when the
SERVER's own track is broken. A carcass that reaches a client after the 6 s mark therefore stands
for the rest of its life (~110 s), not "under 4 s".

## What was proved possible, live, before asking for a design

`358-feas.luau`, on a real carcass in the Forest Test: `Animator:LoadAnimation` **from the client**
on a server-owned Animator returns a track (`ok=true`), it plays alongside the replicated one
(`playing=2`), it takes the weight it is given (`localW=10.00`), and **it changes what is drawn**
(span 0.72 -> 1.16 with the local track pinned at frame 0), and `Stop` puts it back (0.72). So a
client-owned track can own the drawn pose of a server-owned animal.

## What the design must contain

1. **The owner**: its name, where it lives (`src/client/...`), what it owns in one sentence, and the
   `GAME_DESIGN.md` owners row. It must not be a second writer of anything `src/server/Boar/` owns.
2. **The boundary**: exactly which instances it may touch (the client's own `Animator` tracks on a
   part whose `Carcass` attribute is true) and which it may never (the part's CFrame, velocity,
   attributes, collision, the server's tracks).
3. **The rule**: when the owner acts. The measured failure is *"this rig is drawing no death pose"*;
   say how that is decided from instance state alone, and say what it does then.
4. **Where the frame comes from.** A client that never received the death has no `TimePosition` and
   no animation id. State whether the server may publish the death clip and its hold frame on the
   carcass part as attributes (the `Reholds` attribute of task 293c is the precedent), or whether
   another route is intended.
5. **Cost**: it runs on every client for every carcass; name the per-frame budget and the shape
   (an event, a poll, a per-carcass connection) that keeps it there.
6. **The two states**: what OFF draws (today's world, byte for byte) and what ON draws.
7. **How it is proven**: the instrument above, before and after, and what a spec can assert about
   the owner's rule off an Instance the owner built.

## Not in scope

The server's death logic, scoring, the drag/claim, the hitboxes, the 6 s re-assert itself (it is
measured harmless and removing it is not this task).
