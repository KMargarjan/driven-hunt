PASS (item 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing drawn changed, so there is
no new frame of Karen's to see -- `setClock` has no caller outside `tests/`, and with `os.clock`
monotonic `sinceCheck` is never negative, so a player's cadence is bit-for-bit what it was. What was
seen: `rifle_client.spec`'s "the kick belongs to the gun on screen" ran in the DEV place against a
real `humanoid:EquipTool(rifle)` and went green (`drawn=rifle`, claim 7's note). What was NOT seen:
the drawn rifle itself. `drawn` is `Camera.Viewmodel.weaponId()` -- the cache this task repairs,
reading its own output -- and no case in this change inspects the model under the camera or a frame.
Claim 7's "the equip is seen again" is a cache read, not a picture, so item 7 is NOT PROVEN.

Delete-the-producer (RULE 3a), on the one case offered as proof -- `camera_client.spec`, "re-asks the
source on the frame the clock drops below the last check": with `or sinceCheck < 0` removed from
`Viewmodel.update`'s `sourceDue`, `expect(Camera.Viewmodel.weaponId()).to.equal("rifle")` answers
"shotgun" and the case is red. Neither other disjunct rescues it: `cachedHandle` is `firstHandle`
(non-nil) and its `Parent` is the still-alive `first` Tool, so `cachedHandle == nil or not
cachedHandle.Parent` is false, and `sinceCheck` is about -1000. The two sides are not one identity --
distinct Parts under distinct Tools, compared through the `DrivenHunt.Weapon` attribute strings
"shotgun" and "rifle". No yield exists between `fake = os.clock()` and the read, so the live camera
loop cannot answer for it. The case bites.

Verified against the repo: claim 2 (`local fake = 4000.0` in `gun_client.spec`'s `withSeatedShells`,
then `setClock` then `update`, with `withNewGun` restoring only `setClock(nil)` -- which under the
old code left `lastSourceCheck = 4000` installed for the session); claim 3's sibling citation
(`rifle_client.spec`'s `expect(drawn).to.equal("rifle")` is at 747 as quoted); claim 8
(`changed-files.txt` is those two files plus the request); claim 9 (`src/client/Camera/` and
`camera_client.spec` are absent from `TWO_PLAYER_PATHS`, and `needs_two_player` returns only
members of that tuple); claim 10 (selene 0/0/0 twice, stylua exit 0, rojo build exit 0). Harness
line names the `Code commit:` 4f275598 with "(clean tree) scope=all", and
`paperwork-after-code-commit.txt` says only `reviews/task-314/REQUEST.md` followed it. 34/34 is
unchanged from 306m's 34/34 because `checks` is the harness's own `check()` count
(`sum(checks)/len(checks)` in `studio_mcp.py`), not a TestEZ case count -- a new `it` does not move
it, so the number is consistent and not a stale paste.

## Notes (non-blocking)
- `Viewmodel.setClock` / `heldSince` — the reset drops `lastSourceCheck` but not `heldSince`, which
  is session-lived (cleared only by `forgetHold`, never by `clear()`) and is stamped from the same
  injected clock: `heldSince[geometry.FOLDER_NAME] = nowHold`. The new case is now the repo's second
  clock installed AHEAD of live (`os.clock() + 1000`, after `gun_client`'s 4000.0). If its first
  `update` is ever the first to build a folder whose meshes are still downloading, `heldSince` takes
  a timestamp ~1000 s in the future and `holdPieces(waiting, negative)` answers true for the rest of
  the session — every piece held invisible. Unlikely where the case sits (the shotgun folder's
  `waiting` is 0 by then, and `asset_fetch.spec` has already seeded the key), and it would fail loud
  rather than pass wrong. Queue: `table.clear(heldSince)` inside `setClock`'s reset, or
  `Viewmodel.forgetHold()` in the case's tail beside `clear()`.
- `Viewmodel.setClock` — the second half of the fix has no case of its own. Delete
  `lastSourceCheck = -math.huge` and keep the guard, and nothing in the suite goes red: the new case
  calls `setClock` before its first `update`, so the reset is invisible to it (claim 4 says as much,
  deliberately). The guard alone cures the measured defect, so this is not a hole in the gate, but
  the `setClock` edit is unwitnessed.
- `reviews/task-314/REQUEST.md` claim 3 — `camera_client.spec:2858` is not the assertion. In the
  committed file 2858 is `error(err, 0)`; the `expect(...).to.equal("rifle")` the message belongs to
  is eight lines earlier. Consistent with the fail-first run's dirty copy of the spec being eight
  lines longer, and the quoted message text is exactly what the committed case produces — a stale
  citation, nothing more.
- `reviews/task-314/REQUEST.md` claim 1 — `clock=3512.460 ... rebuilds=51` comes from an uncommitted
  dirty-tree run and cannot be re-derived from the repo. Nothing rests on it: the mechanism is
  readable in the tree (`fake = 4000.0` against the old `now - lastSourceCheck > 0.25`), and the
  pair `clock=3512.460 os=3512.460` is self-consistent with `withNewGun` having restored
  `setClock(nil)` while leaving `lastSourceCheck` at 4000.
- `tests/client/rifle_client.spec.luau` — the live witness for this defect class is uptime-dependent:
  `expect(drawn).to.equal("rifle")` only goes red while Studio's uptime is below the largest fake
  constant any earlier spec installed. That is why `main` was green on every run before this morning.
  The new `camera_client` case is deterministic (`os.clock() + 1000`), which is the right place for
  the claim; worth queueing a rule that a spec's fake clock is derived from `os.clock()` rather than
  written as a literal, so no constant can ever sit above a fresh process's clock again.

---
REVIEWER verdict on commit `237d41bdc3ec78c9c7fe90aabb54736f9d3cbc8d` (round 1) · 2026-10-30 11:01 UTC · session cost $1.86, 31 turns · written by tools/agents.py
