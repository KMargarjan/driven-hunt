# Task 356: the release-burn control, archived (rule 7)

**What it was.** Six lines in `ForestTestBoot`'s Heartbeat, Studio only, read through a
`ServerStorage.DHReleaseBurn` attribute: while `ForestTest.releasing()` was true, spin that many
milliseconds of Lua.

**Why it existed.** Task 356's finding is a NULL result -- *no frame during a wave release is long*
-- and a null result means nothing unless the channel that reports it would have reported a long
frame. This is that proof.

**What it measured** (her Forest Test, C1, her flags, one drive each, same commit `f5f06f93`):

| | burn off | burn = 250 ms |
|---|---|---|
| `hb-in-release max` | 46.5 ms | **277.9 ms** |
| `hb-in-release mean` | 23.0 ms over 373 frames | **188.7 ms** over 37 frames |
| `hb-elsewhere max` | 1421.7 ms | 1497.1 ms |
| `hb-elsewhere mean` | 23.3 ms over 14,507 | 22.6 ms over 9,563 |

Runs: `<runs-dir>/BEFORE-track.txt`, `<runs-dir>/CTRL-track.txt`.

**Why it is not in the tree.** A spin loop inside the server's Heartbeat, however well gated, is a
hazard if the attribute is ever set by accident -- and the question it answers has been answered.
The code, verbatim:

```luau
if RunService:IsStudio() and ForestTest.releasing() then
	local burn = tonumber(ServerStorage:GetAttribute("DHReleaseBurn")) or 0
	if burn > 0 then
		local until_ = os.clock() + burn / 1000
		while os.clock() < until_ do
		end
	end
end
```

Put it back the same way if a later task needs to prove another frame channel is not blind.
