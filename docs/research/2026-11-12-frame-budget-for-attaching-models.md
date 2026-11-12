# A frame budget for attaching animal models (task 355)

## What the system must do

One `Boar.Runtime:step` attaches the skinned model to every animal that does not have one yet, in
that one frame. When a wave releases a group, ten animals arrive together and ten models are built
in the same step. MEASURED in Karen's Forest Test, cell C1, flags as she has them, one 340 s drive
(`<runs-dir>/BEFORE-track.txt`, code `402aec2e`): the boar runtime's worst step was **104.2 ms**, of
which **92.1 ms** was `Body.attachVisual` -- 88 % of the frame, with 30 animals alive. The design's
budget (`docs/design/grid-map.md` 9.2, quoted by task 327h) is **20 ms peak**; task 345e measured
73-94 ms on both sides of its change and left it unowned (`ESCALATE.md` 2026-11-12 ~05:05, item 3).

So: spread the attaching over frames, with **every animal still getting its model, none skipped, and
no change to any other count or timing**. The work is already level-triggered -- the step re-tests
`entry.body.visual == nil` every frame -- so what is needed is a budget, not a queue.

## Sources

1. **React Scheduler** -- `packages/scheduler` in facebook/react, MIT, actively maintained
   (https://github.com/facebook/react/tree/main/packages/scheduler). The canonical frame-budget
   loop: `workLoop` keeps taking units of work while `!shouldYieldToHost()`, and
   `shouldYieldToHost` is a wall-clock test against `frameInterval` (5 ms) since the slice began.
   **Does well:** the budget is time, not a count, so it is right whatever one unit happens to cost;
   work is never dropped, only deferred. **Does badly:** it owns a scheduler, priorities and
   continuations -- an apparatus for work that can be interrupted mid-unit, which a single
   `attachVisual` cannot be.
2. **Godot background loading** -- `ResourceLoader.load_threaded_request` /
   `load_threaded_get_status`, MIT, actively maintained
   (https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html). The engine answer
   to the same stall: ask for the resource, poll a progress value each frame, use it when it is
   there. **Does well:** the caller never blocks and the "not ready yet" state is explicit.
   **Does badly:** it is threaded, and a Roblox `Instance` tree cannot be built off the main thread;
   polling also needs somewhere to hold the pending request, which is state this runtime does not
   have and does not need.
3. **Game Programming Patterns, "Update Method"** -- Robert Nystrom, free online, stable
   (https://gameprogrammingpatterns.com/update-method.html). Why a per-frame sweep over a list with
   a cheap "is this one done?" test is the right shape for work that is naturally level-triggered,
   and why such a sweep may do only part of its list in a frame without any bookkeeping at all.
   **Does well:** names exactly the property this code already has. **Does badly:** says nothing
   about how much work one frame should do.
4. **This repo's own `src/server/Places/Slice.luau`** (task 343, `docs/design/map-generator.md`).
   The same pattern already lives here: `Cells.spend` plants models until the frame's budget is
   spent and prints what it spent (`Slice.stats`). **Does well:** it is the house style, with the
   measured-and-printed discipline. **Does badly:** it carries a queue, a drain deadline and a
   report -- the planter must finish a known list by a known moment; attaching has no deadline and
   no list.

## The pattern adopted, and why

**A wall-clock frame budget, in the shape of React's `shouldYieldToHost`, with no queue** -- source 1
for the rule, source 3 for why no bookkeeping is needed, source 4 for the house style of printing
what was spent. The step already walks every animal every frame and already asks `visual == nil`, so
an animal not attached this frame is attached on the next pass with no state at all. One test is
added in front of the existing call:

    if attachBudgetMs <= 0 or prof.attach < attachBudgetMs then Body.attachVisual(...) end

`prof.attach` is this frame's attach spend, which task 355's instrument already accumulates -- so the
budget reads the same number the measurement does.

**Not invented:** the rule, the shape and the "defer, never drop" guarantee are all source 1's. What
is left out is source 1's scheduler -- there is no priority, no continuation and no queue, because
source 3's level-triggered sweep already provides them.

## The numeric targets

| | before | target |
|---|---|---|
| boar step peak (`workspace.Boars.StepMsMax`, C1, one drive) | 104.2 ms | <= 40 ms (the dispatch; the design's own figure is 20 ms) |
| `attach` worst frame (`StepOwners`) | 92.1 ms | <= 20 ms, i.e. the budget plus the one attach that crosses it |
| animals that end the drive without a model | 0 | 0 -- the budget defers, it never drops |
| peak live, parts, spawn calls | 60 / 1020 / 91 | unchanged |

**The budget is 8 ms.** One attach measured 9.4 ms at its worst and ~2-3 ms typically, and the test
is made BEFORE the call, so the frame's attach spend can reach `8 + one attach`. 8 + 9.4 = 17.4 ms,
under the 20 ms row above, and the rest of the step at 30 animals is ~12 ms -- which puts the step
peak at ~30 ms, inside the dispatch's 40.
