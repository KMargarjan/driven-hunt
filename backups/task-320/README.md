# Task 320: the range's treestands, archived (CLAUDE.md rule 7)

Karen, 2026-10-31, after playing her range: *"and remove towers we dont need them in shooting
range"*. The "towers" are the six TREESTANDs of the lobby shooting range -- a 15-stud deck on four
legs with a ladder, one uprange of every station (built at task 306, design
`docs/design/shooting-range-lobby.md` 7.1-7.3).

`Build-treestands-removed.luau` is the code deleted from `src/server/Range/Build.luau` at task 320,
verbatim and in file order: `makeClimbPrompt`, `makePiece`, and the per-station stand loop (the
`HighSeats.plan` call, the stand folder, the deck's `RangeStandPrompt`, and the two climb prompts).

WHAT STAYED, AND WHY. The treestand ARITHMETIC in `src/shared/Range/init.luau` (`LAYOUT.STAND`,
`LAYOUT.CLIMB`, `POSITION.TREESTAND`, `standPosition`, `climbTargetFor`, `distanceFor`'s branch and
the rest) is left in place as DATA NO READER BUILDS, marked as such at each site: the T6 safety
envelope, the station box (`standReach`) and the banks are computed from `STAND.backStuds`, so
deleting it would MOVE the envelope -- which the dispatch's item (c) forbids. Nothing builds a deck,
so `Build` returns no `deckTops`, `Range.onClimb` refuses, `Range.wireClimbs` finds no prompt and
`Range.spotAt` can only answer `bench`.

Restoring it: put the three blocks back where the file's `-- ONE PROMPT ON AN ATTACHMENT` and
`-- THE SECOND FIRING POSITION` comments sat, and re-point `Range.nearestPrompt` at both POSITION
words.
