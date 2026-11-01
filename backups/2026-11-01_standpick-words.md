# `StandPick.WORDS` moved to the screen (task 323b, 2026-11-01)

Archived per rule 7. Task 323a put the five refusal sentences on the SERVER, in
`src/server/Match/StandPick.luau`, from design section 5.1's table. Nothing on that side ever read
them -- the server draws nothing, and a client cannot require a module in `ServerScriptService`.

Task 323b is the task that draws them (the full map's footer reason line), so they moved to
`MapUi.CONFIG.PICK_WORDS` -- which is `Objective.CONFIG.TEXT`'s own stated rule: *"the repo's real
rule is one word table per DRAWER"*. `StandPick` keeps `REASON` and `ORDER`, the vocabulary that
goes on the wire; the screen keeps the sentences. One owner per fact, with the same five values.

The table as it stood, verbatim:

```lua
-- WHAT HIS SCREEN SAYS, or nil for a refusal that draws nothing. `rate`, `flood` and `same` are
-- silent: he did nothing wrong, and drawing "too fast" teaches a forger the limit. Every word is
-- <= 25 ASCII, inside `Objective.CONFIG.TEXT`'s measured bound of 33 (design section 5.1).
StandPick.WORDS = table.freeze({
	closed = "too late",
	role = "beaters have no stand",
	range = "no such stand",
	seat = "you need tree-stand access",
	taken = "taken",
})
```

The spec case that read it (`tests/server/match_stand_pick.spec.luau`, case 1) is now the
vocabulary's case on the server, and `tests/client/map_ui.spec.luau` measures the sentences at the
screen that draws them.
