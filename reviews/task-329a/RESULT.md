PASS (items 2, 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the gun reaching the player's
hand was seen in Karen's place (placeId 130094961655666, :34873 at `dadc3540`, which is byte-identical
to the code under review since no `src/` file changed) ONLY as instance facts read by
`t329a-probe.luau` -- `Player.Team`, the `Tool`'s parent, the root's Y -- never as a frame of her
view, and never once on the condition the dispatch named: there is no first-Play-after-a-sync run
after the fix (the request's own "NOT OBTAINABLE"). Item 2 ("the player's own path is correct") and
item 8 ("5 consecutive patched runs PASS") both rest on probe output from warm Plays. Nothing visual
and nothing in `src/` changed, so there is no new picture owed under rule 5 -- but neither item has
been judged by playing.

Delete-the-producer, stated: the load-bearing case is item 7. Deleting the patch's `*) nolobby=1;;`
arm and `[ "$nolobby" -eq 0 ] || { echo "FAIL: no lobby after ..."; fail=1; }` makes
`t329a-control-nolobby.txt`'s second line vanish and restores the old silent fall-through to
`FAIL: gun not in hand` -- the case cannot pass with the producer removed, and the quoted
`lobby-go at +5s: [nolobby]` / `(+${lobwait}s)` / `@+${gunwait}s=` fields in items 7 and 8 are text
the pre-patch script has no `echo` for. Item 8's PASS verdict, however, survives the deletion (see
note 1). No case here compares a value with itself: the 13.2 s prediction comes from the config
constants and the 13.98 s from a clock.

## Notes (non-blocking)
- REQUEST claim 8 / EVIDENCE.md section 5 — the five PASS runs do not discriminate the fix. The
  pre-patch script also passed on a warm Play; that is the dispatch's own "the next one passed". With
  the patch deleted, 5 consecutive warm Plays still end `SMOKE PASS`, so these runs are a REGRESSION
  check, not proof of the fix -- what proves the fix is item 7's `SMOKE_LOBBY_WAIT=0` control. Label
  item 8 as "the patch does not break the path that already worked" so the merge gate does not read
  it as the fault having been reproduced-and-fixed.
- `reviews/task-329a/smoke-329a-patch.md`, the non-Forest-Test branch — the old `sleep 20` is deleted
  for every place, and `nolobby` is only ever set inside `if [ "${SMOKE_PLACE:-$FT}" = "$FT" ]`, so
  elsewhere `nolobby` stays 0 and a place with no lobby now falls into the gun poll and spends up to
  `SMOKE_GUN_WAIT` (50 s) there, after which `rest=$(( S - ($(date +%s) - t0) ))` is negative and the
  end check is no longer at `S`. EVIDENCE.md section 4 item 3's "`SMOKE_PLACE` elsewhere keeps the
  old single call and the old semantics" is true of the lobby call only, not of the gun wait.
- `smoke-329a-patch.md`, `echo "position @15s=[$gr1]"` — `gr1` is now read after BOTH polls, which at
  the measured waits is ~+30 s, so the field name is wrong; EVIDENCE.md section 5 repeats it ("each
  with `position @15s` and `@end` at `y=110.5`"), and at a true +15 s the player is still at the
  lodge/pad, not at y=110.5. The label was already approximate before the patch (`sleep 15` + probe +
  `sleep 20`), so this is not made worse -- rename the field to `@after-gun` while the line is open.
- `smoke-329a-patch.md`, the lobby `case` — an empty or garbled `lob` (a dead `ftplay`, a missing
  `lobby-go.luau`) falls into `*) nolobby=1;;` and prints "the boot had not finished, so the player
  was never stepped onto a truck pad", naming a cause that was not measured. The raw answer in
  `lobby-go at +${lobwait}s: [$lob]` above it disambiguates; name the probe-failure cause in the
  message too.
- EVIDENCE.md section 1 / REQUEST claim 2 — "the 13.2 s ... predicts" is transcribed from the comment
  above `PICK_TIMEOUT_SECONDS` in `src/shared/Lobby/init.luau` ("8 + `COUNTDOWN_SECONDS` 5, plus two
  scans of slack, is 13.2 s"). The measurement is 13.98 s, which is 0.78 s past a slack the comment
  states as two scans (0.2 s). Say what the remainder is (probe sampling, the depart teleport, the
  equip) rather than presenting 13.98 as what the config predicts.
- EVIDENCE.md section 1, the timing table — the quoted range "12.2-14.5 s" takes its LOW end from
  ft2's `t_lobby` of `<=12.21`, which is an upper bound (the folder may have appeared earlier and
  nobody looked), and m1's `<=19.00` sits outside the quoted range for the same reason. Only the high
  end is load-bearing for the bound, so nothing follows from it; mark which rows are bounds.
- REQUEST "What changed" / EVIDENCE.md section 4 — `<runs-dir>/smoke.sh` is still unpatched ("the
  patch was developed and run as `smoke-329a-test.sh`"), so the fault stays live until the Director
  applies `smoke-329a.patch`, and the tracked copy is deliberately not apply-clean. Queue the apply
  plus one run of the real `smoke.sh`; nothing in the repo can detect the copy drifting from the
  patch that is actually applied.
- `smoke-329a-patch.md`, the lobby exit condition — `lobbyfail` can now only be set if `gunBefore`
  is still true after `SMOKE_LOBBY_WAIT`, so task 177's "no gun in the lobby" check is satisfied by
  any one sample in 70 s instead of the single sample it used to take. Deliberate, and argued in
  EVIDENCE.md section 3; put that sentence in the patch comment so the exit condition is not
  re-tightened later by someone reading only the `case`.

---
REVIEWER verdict on commit `1f0ce22b04cfbd4df1ee3ccad65c56832043409c` (round 1) · 2026-11-05 17:48 UTC · session cost $1.63, 24 turns · written by tools/agents.py
