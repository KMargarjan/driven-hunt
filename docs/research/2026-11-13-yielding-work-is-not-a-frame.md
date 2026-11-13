# Measuring a YIELDING call: wall time is not frame time (task 356)

## What the system must do

Say, of a server function that takes 570 ms of wall-clock time, whether the server was **frozen**
for 570 ms or merely **elapsed** 570 ms while continuing to run. Task 355 measured
`ForestTest.releaseLine` at 569.3 / 567.5 / 845.7 ms "in ONE frame each time a slot fires" and
named it the biggest single stall a drive takes. That claim rests on an `os.clock()` bite, and an
`os.clock()` bite across a yield measures the wrong thing.

## The three external sources

1. **Roblox, `Path:ComputeAsync`** --
   <https://create.roblox.com/docs/reference/engine/classes/Path#ComputeAsync>. First-party API
   reference, maintained with the engine, no licence question (documentation). It states the method
   **yields**: "This function is a yielding function", and computes the path "asynchronously".
   *Does well:* it is unambiguous that the calling thread is suspended. *Does badly:* it says
   nothing about how much of the computation lands on the main thread, which is exactly the number
   a game needs -- so the doc alone cannot settle whether a frame is lost.
2. **Roblox, `RunService.Heartbeat`** --
   <https://create.roblox.com/docs/reference/engine/classes/RunService#Heartbeat>. Same status.
   `Heartbeat` passes `deltaTimeSec`, "the time elapsed since the previous frame". That is the only
   number in reach of Lua that includes the **engine's own** work -- physics, replication,
   pathfinding -- which no `os.clock()` bite inside a script can see. *Does well:* it is the frame,
   by definition. *Does badly:* it attributes nothing; a long frame does not say whose it was.
3. **Brendan Gregg, "Off-CPU Analysis"** -- <https://www.brendangregg.com/offcpuanalysis.html>
   (CC BY-SA 4.0 on the site's content; actively maintained, the reference treatment). The
   general form of this exact trap: profiling on-CPU time and blocked (off-CPU) time are different
   questions, and a span of wall time is the sum of both. Gregg's rule -- *"measure the time a
   thread spends off-CPU separately, or you will attribute waiting to working"* -- is what task 355
   did not do. *Does well:* it names the error class and the fix (split the two). *Does badly:*
   nothing here is about a game loop, so the mapping onto "a frame" is ours to make.
4. **Roblox, MicroProfiler** -- <https://create.roblox.com/docs/studio/microprofiler>. First-party,
   maintained. The engine's own per-frame breakdown, and the tool that would answer this directly.
   *Does well:* ground truth. *Does badly:* it cannot be read from a headless agent session -- it
   is a Studio overlay with no scripting API -- so it is not available to this harness. That is the
   reason a Lua-side instrument had to be built at all, and it is the written reason required by
   rule 2 (**borrow before building**).

## The pattern adopted, and why

**Split the span into the two questions Gregg splits, and charge every frame to one of them**
(source 3), **using `Heartbeat`'s own `deltaTimeSec` as the frame** (source 2), because the call
under test is documented as yielding (source 1):

- `ForestTest.step` runs exactly once per Heartbeat, so counting its entries between a call's entry
  and its exit gives **how many frames the call spanned**. One call, zero extra frames, is a
  genuine stall; 43 frames is not.
- A depth counter (`ForestTest.releasing()`) says, for each Heartbeat, whether a release was in
  flight. Each frame's `dt` is then charged to **in-release** or **elsewhere**, with max, mean and
  a count on both sides. Two distributions, not two maxima -- task 355's own lesson, where one
  1,274 ms join frame hid every other owner behind it.
- **A positive control, because the result is a null one.** "No frame during a release is long"
  only means something if the same channel would report a long one, so a Studio-only spin of N ms
  was injected into in-release frames and the channel had to read N back. It did
  (`backups/2026-11-13_task-356_release-burn-control.md`). Without this the finding would be
  indistinguishable from a broken instrument -- which is the failure mode
  `docs/PROJECT_CONTEXT.md` records as having killed the previous project twice.

Nothing was invented: the frame counter, the depth flag and the two accumulators are the shape task
355 already used for `stepSections` / `DHBootOwners`, one level down.

## The numeric targets

| | target | why |
|---|---|---|
| frames spanned by one `releaseLine` | **reported, not bounded** | the number that decides stall vs elapse; 0 extra frames would mean the dispatch is right |
| `hb-in-release` mean vs `hb-elsewhere` mean | **within 10 % of each other** | if a release cost the frame anything, its frames would be measurably fatter than the drive's others |
| the control reads its own burn back | **within 20 % of N** | a channel that cannot see N ms cannot be trusted to report 0 |
| instrument cost | **< 0.05 ms per frame** | one `ForestTest.releasing()` call plus two adds per Heartbeat, and ~10 `os.clock()` calls per release (26 releases per drive) |

## What this does NOT establish

That `Path:ComputeAsync` is free. It establishes that its cost does not land in one frame of the
drive. Whether the engine spends main-thread time on it spread thinly across those frames is a
question only the MicroProfiler can answer, and this instrument cannot -- see `hb-in-release mean`
in `reviews/task-356/MEASUREMENTS.md` for the bound that can be put on it from Lua.
