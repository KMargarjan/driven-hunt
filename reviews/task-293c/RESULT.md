PASS (item 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing was seen in Karen's place.
The only live reading in the request is at **main**, on three ALIVE boars (`Reholds=nil`), which is
the absence of the feature, not the feature; the request's own "Not verified" says the DEV kill was
NOT OBTAINABLE (`0 kills attempted`, then 6 `FireRequest:FireServer` shots with `carcass=nil`
afterwards), so **no running game has ever shown `Reholds` on a real carcass**. What IS proven by
reading: `Body.create` returns `part = part` (a fresh `Instance.new("Part")` per animal, destroyed in
`Body.stepCarcass`, so no recycled part can carry a stale count), the Runtime's per-boar loop does
NOT skip collapsed animals (`if not entry.body.collapsed` guards only `Wound.advance`) and reaches
`Body.stepVisual` under `config.MODEL.ENABLED`, which `Flags.isOn("BOAR_MODEL")` has lit
(`default = true`), and the new block sits BEFORE the `if handle.toppled then return end`, so a
box-toppled carcass publishes too. There is no visual change owing a screenshot: the `src/` diff is
one added block plus one comment, and it touches no rule, window, frame or clip name.

Delete the producer, by reading:
- *"publishes the repair count on the carcass instance, on every change (task 293c)"* — delete the
  new `handle.part:SetAttribute("Reholds", ...)` block and `expect(part:GetAttribute("Reholds")).to.equal(0)`
  reads nil; delete `handle.reholds += 1` and `expect(handle.reholds).to.equal(i)` fails. The case
  also pins ORDERING: moving the publish above the repair block makes the attribute lag by one and
  `equal(i)` fails on the first overrun. No line survives the deletion.
- *"reads 0 across a whole carcass life with no overrun (task 293c)"* — delete the block and
  `expect(part:GetAttribute("Reholds")).to.equal(0)` reads nil. The two sides of no comparison are
  the same engine identity: the attribute is an instance store, `handle.reholds` a Lua field, and
  both are also asserted against the literals `i`, `N` and `0`.
- The float arithmetic in the 7200-step case holds, so it is not decided by rounding noise:
  `fl(1/60) = (1/60)(1 - 2^-56)`, so `math.ceil(120 / dt)` is exactly 7200 and `steps * dt` rounds
  back to exactly 120.0 — `steps * dt >= life` is true, not marginal.
- FAIL FIRST is real: `log.txt` shows `83273e4d` as "1 file changed, 107 insertions(+)" in
  `tests/server/boar_model.spec.luau` and nothing in `src/`, so the cases existed at a commit whose
  `Body.luau` was main's. The harness line names the request's `Code commit:` f482308f with
  "(clean tree)", and `paperwork-after-code-commit.txt` says OK (only `reviews/task-293c/REQUEST.md`
  followed it).

## Notes (non-blocking)
- `reviews/task-293c/REQUEST.md`, claim 3 — calls `Expected value "0" (number), got "nil" (nil)`
  "claim 1's first assertion". It is the SECOND assertion; the first,
  `expect(part:GetAttribute("Reholds")).to.equal(nil)`, passes at main. Fix the sentence, not the code.
- `tests/server/boar_model.spec.luau`, claim 6's cited proof — `expect(part:GetAttribute("Reholds")).to.equal(nil)`
  is read off a Part created one line earlier in `carcass293` and never stepped, so it passes with the
  whole feature deleted and proves nothing about a LIVE animal. The claim itself is sound (the
  `if handle.collapsed` guard in `Body.stepVisual` is its real support, and it is the first term, so a
  live animal pays no `GetAttribute` either), but nothing asserts it: the existing
  *"leaves a live animal and a box-toppled carcass alone (task 293)"* case already steps a
  `collapsed = false` handle and is one line
  (`expect(live.part:GetAttribute("Reholds")).to.equal(nil)`) short of closing it.
- `src/server/Boar/Body.luau`, the new block — `Reholds` is a newly published attribute on the same
  trunk part whose reader-visible attributes (`Damageable`, `Carcass`, `HitZone`, `Kind`) are written
  down in `docs/design/hit-zones.md`. Nothing outside the code records it. Queue a one-line entry
  there, or queue the block's removal with 293's close-out, so a diagnostic with no expiry does not
  become a contract by accident. Outside this change's scope, so a note only.

---
REVIEWER verdict on commit `c6bfd067518d738659a28b6309d1555e4da60c6f` (round 1) · 2026-10-27 18:44 UTC · session cost $2.97, 42 turns · written by tools/agents.py
