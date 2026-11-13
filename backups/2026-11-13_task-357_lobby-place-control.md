# Archived: the task 357 positive control at the lobby's `place` seam

**Why it is here and not in the tree (rule 7).** Task 357's answer is a NULL one -- the lobby's
1,214 ms at the join is not a frame -- and a channel that reports *"nothing long happened"* is
worthless unless it would have reported something long (task 356's own lesson, and L-141). So two
Studio-only knobs were put at `ForestTestBoot`'s `place` seam, measured in Karen's Forest Test, and
then removed: a spin loop in a seam the live game calls is not something to leave in a repository.

It lived in commits `211cdc18`..`8276a2b7` on `task-357-lobby-join-frame` and was removed in the
commit that carries this file. To run it again, restore the block below.

## What it was

```lua
	place = function(player, cframe)
		-- DHLobbyBurn  ms SPUN on the main thread. A real stall: the `place` bite's ms must rise by
		--              it and its FRAME count must not, and the Heartbeat max must move.
		-- DHLobbyWait  ms WAITED. A yield: the bite's ms must rise by it and its frame count must
		--              rise by about ms/16.7, and the Heartbeat max must NOT move.
		if RunService:IsStudio() then
			local burn = ServerStorage:GetAttribute("DHLobbyBurn")
			if type(burn) == "number" and burn > 0 then
				local spinUntil = os.clock() + burn / 1000
				local spins = 0
				while os.clock() < spinUntil do
					spins += 1
				end
				burnSpins = spins
			end
			local waited = ServerStorage:GetAttribute("DHLobbyWait")
			if type(waited) == "number" and waited > 0 then
				local waitUntil = os.clock() + waited / 1000
				while os.clock() < waitUntil do
					task.wait()
				end
			end
		end
		Body.place(player, cframe, Match.CONFIG)
	end,
```

`burnSpins` was a file-level counter published as `ServerStorage.DHLobbyBurnSpins`: a witness that
the spin really ran, and a loop body so `selene`'s `empty_loop` rule had something to see.

## How it was driven

Both attributes were set **at runtime inside a Play session**
(`<runs-dir>/357-ctrl-set.luau`, run through `342-ft.py server`), never in Edit, so nothing was
written to Karen's place -- the same rule task 356's control followed. The probe then walked the
player 600 studs out of the lodge's home areas so the lobby's next scan called `world.place` again.
`<runs-dir>/357-ctrl.sh` is the runner.

## What it read, in Karen's place, C1, her flags

| input at the `place` seam | `place` ms | `place` FRAMES | the Heartbeat channel's top 3 |
|---|---|---|---|
| **none** (`BEF3`) | 361.1 | **11** | 1539.6@12 · 911.5@14 · **162.2@16** |
| **spin 800 ms** (`CTRLBURN`) | **1034.4** | **7** | 1483.3@12 · 931.2@14 · **811.4@502** |
| **wait 800 ms** (`CTRLWAIT`) | **1125.2** | **37** | 1414.0@12 · 900.7@14 · **99.7@2** |

**A spin raises the milliseconds and does NOT raise the frame count, and it puts a new long frame in
the Heartbeat channel. A wait raises both the milliseconds and the frame count, and puts no long
frame there at all.** 20,870,172 spins were counted in the burn run and `DHLobbyBurnSpins` was
`nil` in the wait run, so each arm ran only its own knob. The instrument is not blind, and the two
channels disagree in exactly the way they must.
