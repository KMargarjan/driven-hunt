# The 1.4 s server frame at the lobby join: splitting the bucket (task 357)

## What the system must do

Say **where** the 1,214.6 ms that the boot bill charges to `lobby` at a player's join goes, and
whether any of it is **one server frame** rather than wall-clock time elapsed across many. Task 356
measured the drive's worst server frame at **1,399.7-1,421.7 ms** with no release in flight, and the
same drive's boot bill named `lobby=1214.6 ms` of a 1,214.79 ms step -- `Lobby.step` + `reportLobby`
in one bucket (`reviews/task-356/MEASUREMENTS.md` section 5 item 1). Two numbers of a similar size
are not the same frame, and the answer decides whether there is anything to fix at all.

The numeric targets the dispatch sets: **no server frame over 100 ms at the join**, the heartbeat max
reported, and `smoke.sh`'s gun-in-hand time not later by more than 1 s.

## The external sources

1. **Roblox, `Player:LoadCharacter()`** --
   <https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacter>. First-party API
   reference, maintained with the engine, no licence question (documentation). It is marked
   **yields**, and it is what `Match.Body.place` calls -- which `Lobby.step` calls through
   `world.place` for a man standing outside the lodge's home areas. *Does well:* it settles that the
   calling thread is suspended, so an `os.clock` bite across it is wall time. *Does badly:* it says
   nothing about how much of the avatar load lands on the main thread, which is the number that
   decides whether the player SEES a freeze -- so the doc cannot answer the dispatch's question on
   its own, and an instrument was needed.
2. **Roblox, `RunService.Heartbeat`** --
   <https://create.roblox.com/docs/reference/engine/classes/RunService#Heartbeat>. Same status. `dt`
   is "the time elapsed since the previous frame": the only number in Lua's reach that includes the
   **engine's** own work -- character loading, replication, terrain -- which no `os.clock` bite in a
   script can see. *Does well:* it IS the frame, by definition. *Does badly:* it is
   **backward-looking** and attributes nothing, so a long frame does not say whose it was; that has
   to be joined to a step number by hand, which is what `DHLobbyBill`'s `hbmax=... at step=...` does.
3. **Brendan Gregg, "Off-CPU Analysis"** -- <https://www.brendangregg.com/offcpuanalysis.html>
   (CC BY-SA 4.0, actively maintained, the reference treatment). The error class in its general
   form: on-CPU time and blocked (off-CPU) time are different questions and wall time is their sum,
   so a single span measured with one clock attributes waiting to working. *Does well:* it names the
   trap and the fix -- split the two and count the blocked span separately. *Does badly:* nothing in
   it is about a game loop, so the mapping of "off-CPU" onto "frames spanned" is ours to make.
4. **Roblox, MicroProfiler** -- <https://create.roblox.com/docs/studio/microprofiler>. First-party,
   maintained, and the tool that would answer this directly with per-frame engine-side detail.
   *Does well:* ground truth. *Does badly:* it is a Studio overlay with no scripting API, so a
   headless agent session cannot read it. **That is the written reason (rule 2) a Lua-side
   instrument was built instead of borrowed.**
5. **This repository, task 356** -- `docs/research/2026-11-13-yielding-work-is-not-a-frame.md` and
   `reviews/task-356/MEASUREMENTS.md`. The same question asked of `ForestTest.releaseLine`, with the
   instrument that answered it (`DHReleaseBill`: ms **and** frames spanned per bite, plus a
   Heartbeat-`dt` channel, plus an injected-delay positive control). *Does well:* it is the pattern,
   proven in this exact place a day earlier, including the lesson that a NULL result needs a control.
   *Does badly:* its bill is per-release and its control is per-release, so neither transfers without
   being re-pointed at the lobby's own calls.

## The pattern adopted, and why

**Borrowed wholesale from task 356 (source 5), re-pointed at `Lobby.step`.** Three parts:

1. **Every bite carries a frame count beside its milliseconds.** `profMs` / `profFrames` /
   `profCalls` in `src/server/Lobby/init.luau` over the three calls that can account for the bucket:
   `ground` (`world.groundAt`, outside `stats.buildMs` and run on every scan before the lobby
   exists), `build` (the whole of `tryBuild` from `began`), and `place` (`world.place`, the one call
   the file's own comment already names as yielding). `rest` is the remainder of the scan, derived,
   so the bill always adds up. A bite that reads `frames=0` spent its milliseconds **inside one
   frame**; a bite that reads `frames=N>0` was suspended through N frames and its wall time is not a
   stall.
2. **The frame counter has exactly one writer.** `bootSteps` in `ForestTestBoot`, incremented at the
   **top** of the one Heartbeat handler (it used to be incremented mid-handler, which would have
   been off by one for a bite that spans a yield) and handed to the lobby as `world.frames` -- an
   instrument seam, optional, nil in every spec and in the DEV place. "Which frame is it" must not
   have two answers.
3. **The frame itself, from `dt`, with the step number on it.** `hbWorst` records the worst
   Heartbeat `dt` of the session, the step it fired on, and the lobby buckets as they stood -- with
   the comment saying `dt` looks backward, because reading those buckets as *that* frame's work is
   precisely how a 1.4 s frame gets charged to whichever owner was slow after it.

**And a positive control, because the expected answer is a NULL one** (356's own lesson: a channel
that reports "nothing long happened" is worthless unless it would have reported something long).
Two Studio-only knobs, injected into the scan, measured, then reverted and archived rather than
shipped: a **synchronous spin** of N ms, which must read back as `ms~=N, frames=0` and move the
Heartbeat max; and a **`task.wait`** of N ms, which must read back as `ms~=N, frames~=N/16.7` and
leave the Heartbeat max alone. One instrument, two known inputs, two different readings.

## What was rejected, and why

- **Reading `stats.buildMs` alone** (already printed as `[lobby] built in 71 ms`). It is 6 % of the
  bucket and it excludes the first `world.groundAt` and every call after the build, so it cannot
  name the spender. **It is NOT a cross-check of the new `build` bite, and saying so was the first
  review round's finding 1:** both lines sit in `tryBuild` and read the same `began`, so they are
  one reading printed twice and cannot disagree. The `build` bite's milliseconds have exactly one
  source. **What IS corroborated is the thing the task turns on** -- that those milliseconds are
  *one frame* -- and it is corroborated by a different mechanism, not a second clock: `frames=0`
  comes from `bootSteps`, an integer the Heartbeat increments, with no `os.clock` in it at all.
- **Treating the boot's own bracket as a second instrument.** `ForestTestBoot` times `Lobby.step`
  from outside (`lobbyStepMs`) while `Lobby.step` times itself from inside (`scan worst`), and the
  two read 386.5 and 386.5. That bounds the call and throttle overhead at under 0.1 ms, which is
  worth having -- but they are nested spans off the same clock, so it is a consistency check and is
  written here as one.
- **A second `RunService.Heartbeat` connection inside `Lobby`.** `ForestTestBoot`'s header already
  forbids it in writing (*"ONE HEARTBEAT FOR BOTH JOBS"*), and it would be a second answer to "what
  time is it".
- **Timing it from a probe over StudioMCP.** A live probe gets a FRESH copy of every module
  (memory: `studio-mcp-execute-luau-single-line`), so module state is unreadable that way; the bill
  is published on `ServerStorage.DHLobbyBill` for the same reason `DHBootWorst` is (V293b).
