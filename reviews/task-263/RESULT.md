PASS (item 5 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the code in this change is a
Studio-only instrument -- `TestLook.current` answers nil outside Studio, so nothing a player sees
changed and there is no production frame to photograph. What was SEEN is the Builder's described
frame `263-aimshot-h5.png` (hit card `HIT - .416`, kill line `Alhamdulilah824 FEMALE BOAR head 27 m
RIFLE`, Hud `DRIVE 2 / 3:30 / HUNTER`) and the four gun frames -- a described screenshot I cannot
open is not a blocking finding. What was NOT seen by anybody is item 5: task 261's items 1, 2(a) and
3 were never re-proved on Karen's path, and 261 item 3 is CORE -- nobody has watched a shot deer on
the road lie still since the fix. The instruments to do it now exist and are proved; the proof does
not.

## Notes (non-blocking)
- `tests/client/camera_client.spec.luau`, `it("moves the REAL camera, holds it there, and gives it back")` — NO pcall/restore. If any assert in the first half throws (`expect(steered >= 8)`, the `Dot` pair), the case exits with `DHTestLook` set and `DHTestLookOff` unset, so the camera is HELD 85 degrees off for the rest of the session and every later case that needs the view fails for a reason that is not its own. The `DHPose` case 25 lines above it is the file's own pattern: write, `pcall`, restore on both paths, then `error(why, 0)`. Use it — this is the cascade task 252 spent a whole task unpicking.
- `src/client/Camera/init.luau`, `update`'s testLook branch — this is the first thing in the repo that makes `Camera.lookAt` a no-op for a sustained window: the hold re-applies the angles every frame, so `pendingLookAt` can never land while it is set. `tests/client/zz_tie_to_a_tree.spec.luau`'s own header says it runs *"while camera_client.spec is asserting about that camera"* and it stages its shot with `Camera.lookAt(aimAt)`. The window is ~16 frames out of a 60-240 s replay, so the risk is small and it is test-only — but it is a new flake path in the one file with a flake history, and the pcall fix above does not close it.
- `src/client/Camera/Mode.luau`, `Mode.anglesToward` header — *"Used by Camera.lookAt ... and by nothing else today."* It had two callers before this change (`faceTowards`) and has three now. Stale citation; the change made it one caller staler.
- `src/client/Camera/TestLook.luau` header — `Design: docs/design/camera.md (sections 3, 9.3)`. Section 9.3 is *"Server spec additions for the `Sight`"*, which is not what this file does. The research note it cites does exist.
- `tools/agents.py`, `review()` — the comment that explains the reading order still says *"the rules come from the 61-line digest"* while the same commit updated `REVIEWER_PROMPT.md` to 85. The same comment says a count must not be written into the code, so it is arguing against itself; drop the figure rather than update it.
- `reviews/task-263/REQUEST.md` claim 10 — *"12 selftest cases"*. The new block has 14 `check()` calls (3 pass shapes + 1 FINDINGS + 8 malformed + 2 reader-agreement).
- `reviews/task-263/REQUEST.md` claim 8 — *"they are not the same engine identity"* is true of the objects (a replicated payload vs an Attachment) but not of the NUMBER: the client builds that Attachment from the server's payload, so `3352.76,169.66,-3196.78` matching itself is by construction. What the pair actually proves is that the client's draw path consumed the payload and parented the impact under `ZoneHead` -- worth having, and worth saying in those words. The independent facts in that run are the zone name, the local offset `0.015,0.174,1.351` and the frame.
- `src/client/Camera/init.luau`, `update` — the hold drops a running `faceTowards` (`facingTarget, facingLeft = nil, 0`) without touching `stats.facingCancels` or `facingsDone`, so a probe cannot tell "the hold took it" from "it arrived". One counter, or one sentence saying the silence is deliberate.
- Item 5, for the Director — the next round for 261 starts from its items 1, 2(a) and 3 on Karen's path, with `aimshot.py` and the held look now in hand. Nothing in this change advances it and the request says so plainly (rule 8).

---
REVIEWER verdict on commit `930a374a91601d53e6cd9e34cb5b7162513dce5e` (round 1) · 2026-10-25 13:03 UTC · session cost $2.38, 29 turns · written by tools/agents.py
