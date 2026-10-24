PASS

Verified against the repo, not the request: harness line `[harness] PASS: 34/34 checks @ 9a3e8642…
(clean tree) scope=all` names the request's `Code commit:`, and `paperwork-after-code-commit.txt`
says only `reviews/task-256/REQUEST.md` followed it ("OK"). Lint, format and Rojo build clean.

What I checked and found true: `Flight.launch`'s fourth argument is clamped at the one door
(`math.clamp(catchUpSeconds, 0, self._config.FLIGHT_CATCHUP_MAX_SECONDS)`, NaN rejected by
`catchUpSeconds == catchUpSeconds`); `live.catchUp` is read and zeroed before the sub-step split in
`Flight.advance`, so it cannot be spent twice; `Flight.substeps(dt + owed, config)` reproduces the
old per-frame arithmetic exactly for `owed = 0` (`total <= 0` → `1, 0`, same `min`/`max`/`ceil`);
`Flight.substeps(0.1 + 1/60, {1/30, 8})` is 4 sub-steps against a bare 1/60's 1, which is what
"IS SPENT ONCE" asserts (4 then 1) and it fails if the catch-up is re-applied; the core claim's
`expect(#missed).to.equal(0)` / `expect(#hit).to.equal(1)` differ only in the fourth argument and
fail with the feature deleted; `Weapon.catchUpFor` is the only `GetNetworkPing` reader in `src/`
(grep) and `flight:launch` has exactly one production call site; `Shotgun.CONFIG` carries both rows
and `Flight.new(CONFIG)`/`CONFIG = Shotgun.CONFIG` means the clamp can never read a nil bound.
Round 1's three findings are closed: `emitter.LockedToPart = true` is set only on the riding path and
asserted `true` riding / `false` static, so the two paths cannot drift into one answer; and
`docs/design/ballistics.md` §1.2 now reads "No REWINDING of targets, and no position history of one"
with §2.2, §5.1, the `Flight.launch` fourth argument, the `Flight.stats` sixth field and
`Flight.substeps` all matching the shipped code.

## Notes (non-blocking)
- `src/server/Weapon/Flight.luau` — three comments still assert an invariant this round disproved:
  `Flight.new` ("In a Studio harness run there is no network, so this must stay 0"), `Flight.launch`
  ("with no network this must read 0.000, so a non-zero total in a Studio harness run is this feature
  firing where there is no lag to compensate -- a bug said out loud") and `Flight.stats` ("0.000 in
  any run with no network; a non-zero value in the harness is a bug"). The shipped guard says the
  opposite on purpose — `weapon_state.spec`: "IT WAS `equal(0)` AND THAT FAILED … reported 1.70 ms".
  A reader of `Flight.stats` would file the expected value as a bug. Same sentence as
  `Weapon/init.luau`'s `flightCatchUpSeconds` would fix all three. Same stale claim in
  `weapon_hits.spec`'s "a Studio Play session has no network and `GetNetworkPing` reads ~0", in
  research note §5.4 ("a local Play session's ping is ~0") and in `TASKS.md` row 256.
- `docs/research/2026-10-24-real-shooting.md` §5.3, and the two shipped comments quoting it
  (`Shotgun.CONFIG` "at 60 ms one way, a boar at `SPRINT_SPEED` wants 64 cm of extra lead … The ping
  is 70 % of the lead again", `Weapon.catchUpFor` the same sentence) — the label is one trip and the
  figures are a round trip. §5.1 concludes "the player feels **`2L*v`** -- the full round trip", §5.5
  prices 100 ms *round trip* at 3.80 studs and `shotgun.md` §11 priced "100 ms RTT" at ~3.8 studs;
  64 cm is 0.06 s × 38 studs/s × `METRES_PER_STUD`, i.e. `L*v`, under a header reading "one-way L".
  Either the column means the round trip or the row is 128 cm / +141 %. Nothing shipped depends on
  it: §5.4's operative sentence ("the correction wanted is the ROUND TRIP") is right, and
  `FLIGHT_CATCHUP_PING_FACTOR` is the dial for exactly that ambiguity.
- Rule 5, stated so this PASS is not read as rule 5 having been met: the one thing nobody has looked
  at is the picture, and the picture is the deliverable of item 5. The Builder names it under rule 8
  and leans on the Director's split (real-click proof in part 2); what the code can prove is proved
  (`LockedToPart` both ways, `WorldCFrame.UpVector == normal` at creation). Part 2 should carry a
  frame of a sprinting animal mid-puff — that is the assertion neither a spec nor I can make.
- `docs/design/` vs the riding path's owner boundary, recorded only in a code comment.
  `shotgun.md` still says "`Workspace.WeaponEffects` and everything in it | `PlayerScripts.Weapon.
  Effects`" and "`Effects.luau` | cosmetic Instances under a runtime folder `Workspace.
  WeaponEffects`", and `ballistics.md` §7's contract still says "one \"Impact\" Part per position …
  through the same `part()` helper", while the riding path makes an **Attachment** and parents it
  **into a boar's part**. §7's own parenthetical — "it changes no claim in this section and no claim
  in this design" — changes that claim. Architect's file; carry it with part 2. (The boundary itself
  is sound: a client-local child, no property of the boar written, Debris removes it, and an
  Attachment has no geometry so it cannot enter a cast.)
- `ShotLanded`'s fourth array is undocumented in either design, as task 249's `normals`/`materials`
  already were (grep: neither word appears in `ballistics.md`), so it contradicts nothing new — but
  whichever doc owns that payload should eventually list all four.
- `tests/client/weapon_client.spec.luau`, the riding case — the struck body is parentless on purpose,
  so by `puff`'s own comment ("an `Emit` on an emitter that is not yet in the world draws nothing")
  no grain is actually emitted in that case. The asserted properties hold regardless and the case is
  the right one to have; it proves the wiring, not a visible grain.
- No `Flags` row for a feel-critical shooting path, a fourth time. `ballistics.md` now rules it out
  by name ("No feature flag — `catchUpSeconds = 0` and `FLIGHT_CATCHUP_PING_FACTOR = 0` each
  reproduce today's flight bit for bit"), so the Builder is following the amended design and this is
  not his to answer; the standing `docs/design/feature-flags.md` decision queued as 254a(b) /
  255a(f) is still the thing that would stop this recurring.

---
REVIEWER verdict on commit `0e9ab2c504ac9061f2f4d8d4fc0ec8fda763e075` (round 2) · 2026-10-24 21:32 UTC · session cost $3.89, 35 turns · written by tools/agents.py
