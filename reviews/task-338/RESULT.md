PASS (item 1 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what was seen in Karen's place is
the Builder's own session in her Forest Test (place `130094961655666`, cell C1) and one frame of it,
`338-F1.png`, drive 2 at 87 s with NO got-away line -- a frame I cannot open. What was NOT seen in
her place this session is the state she complained about: the END of a drive, where the count stands
at ~100. The only frame of that is `327d-F1-stand-beaters.png`, taken in a pre-327d2 world (beater
pace 5.2, before `Grid.CONFIG.beaterWalkStudsPerSecond` 5.64 reached main), and Karen has given no
verdict on either frame. The game is unchanged by this round, so there is nothing new for her to
judge -- and the toast she objected to still reads the same way.

Delete the producer, by reading. The client case (`338-wire.luau`, `escape` entries on
`ReplicatedStorage.Drive.Remotes.MatchEvent`) is producer-sensitive: `dispatch({ kind = "gone" })`
in `Match.onDespawned` is the ONLY `"gone"` dispatch in `src/`, `Phase.step`'s
`kind = if kind == "kill" then "kill" else "escape"` is the ONLY `escape` feed entry, `Brain:_outcome`
is the ONLY producer of `reason == "escaped"`, and `Match.init`'s `remotes.MatchEvent.OnClientEvent`
fires one entry per event into the same `feed` the Hud stacks -- delete any link and the probe counts
0 and claims 4, 6 and 7 collapse. The two sides are not one engine identity. BUT: claim 1's load-
bearing lines, *"escape entries = 0 at 15 s, 0 at 60 s"*, survive the producer's deletion verbatim --
a dead probe reads zero too. What saves them is the SAME probe in the SAME run reading 19 at 150 s
and 108 at 300 s, which is a positive control and must be read as the reason those zeros count. Had
drive 1's later readings not been in the same run, claim 1 would have been a blocking finding.

## Notes (non-blocking)
- `ESCALATE.md` 2026-11-09 — *"the only way to make the toast read smaller would be to hide true
  events"* is false, and the mechanism it misses is the one that makes x80 possible at all:
  `Hud.pushFeed` collapses a repeat by writing `at = atClock` and `count = count + 1`, and
  `renderFeed` only trims on `atClock - Drive.CONFIG.FEED_SECONDS` (8). 108 escapes between +72.8 s
  and 300 s is one every ~2.1 s, so the single "an animal got away" line is refreshed forever and
  carries the DRIVE TOTAL in a feed a player reads as "what just happened". A window-local count or a
  cap would make it read smaller and hide no event. Queue it with the density question for the
  Director; it is the lever neither document names.
- `reviews/task-338/REQUEST.md` claims 1, 4, 6 — the evidence they send the reader to is not in the
  repo: *"the per-animal `DEL` log in `ESCALATE.md`"*, *"the two logs in `ESCALATE.md`, same run"*,
  and step (b)'s *"Readings in the table below"*. The ESCALATE entry carries prose summaries only and
  the REQUEST has no table. The raw counts are therefore checkable by their author alone. Commit the
  two probe logs under `reviews/task-338/` next time.
- claim 5 — the reason is `"layoutChanged"`, not `"cleared"`: `promote` calls
  `runtime:clear("layoutChanged")` and `Runtime:clear` passes `reason or "cleared"`, so the default
  is unreached. The conclusion holds either way (`onDespawned` returns on `record.reason ~= "escaped"`).
- claim 4 — no escaped record can carry z > -5402: `Brain:_outcome` returns `"escaped"` only under
  `position.Z <= field.exitZ`, and `Runtime:_step` hands `_despawn` that same `position`. So the
  -5397 end of *"z = -5397 … -5402"* is the watcher's own sampling lag, not a crossing position; say
  so, and say what the probe's sampling period was.
- the LEVER paragraph — `Brain:_outcome` is quoted as *"at `position.Z <= field.exitZ`"* with its
  state predicate dropped (`FLEE` / `WOUNDED` / `AVOID` / `self:ordered()`). The target line *"one
  toast per animal that crosses the cell's exit line"* is therefore wider than the code: an idle
  animal that drifts over the line produces no toast, by that predicate's own comment.
- claim 3 / ESCALATE finding 2 — *"Measured on main at those same two instants: ~100 at 289 s"*
  against the frame's x80 compares two different worlds: `327d-F1-stand-beaters.png` predates
  327d2's `beaterWalkStudsPerSecond` 5.2 -> 5.64, which moves exactly when animals are spooked and
  cross. Directionally consistent (slower beaters, fewer crossings by 289 s) and unreconciled.
- `ESCALATE.md` — *"A 300 s drive at this density releases 130 animals (drive 1) and 80 (drive 2)"*
  presents as a full-drive figure what the REQUEST's own "What I could not verify" says was read at
  145 s / session stop. Both figures refute "about 60"; the overstatement is in ESCALATE only.
- claim 6 — the one-to-one map is an inference from an ASSUMED fixed 4.0 s offset between two
  independent print clocks, carried across 108 entries in order, not a measurement. Nothing in the
  refutation rests on it; do not re-offer it as proof of which animal a toast was.
- `TASKS.md` — task 338 has no row, so the dispatch wording the refutation answers exists only as
  the quote inside the request. Nothing could be cross-checked against it.

---
REVIEWER verdict on commit `050a5c7be060abb6cc3786364ec7343fce3e05a7` (round 1) · 2026-11-09 06:02 UTC · session cost $3.20, 71 turns · written by tools/agents.py
