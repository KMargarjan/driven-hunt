# ESCALATE -- Task 326

## NEEDS KAREN (or the Director at the machine): no frame can be taken of the Forest Test

2026-11-01. Task 326 is fixed, gated (`[harness] PASS: 34/34 @ 889ea95c (clean tree) scope=all`)
and proven by census in Karen's own place before and after -- but **rule 5 is not met: no picture.**

`screen_capture` against the Forest Test Studio returns the SAME cached image (the lodge porch) for
six different camera/look pairs AND for a confirmed character move to the measured spot. Both
routes were tried and both report success in Luau while yielding that one frame:
`<runs-dir>/326frame.py` (parks the client camera, `CameraType = Scriptable`) and
`<runs-dir>/326shot.py` (stands the player there, server-side `PivotTo`, which the probe confirms:
`player at -3836, 105.15, 3264`). Frames: `326-before-A-eye.png` ... `326-before-S1.png`,
`326-test-cam.png`.

**The clicks that would settle it:** bring the **Driven Hunt Forest Test** window to the front and
move/resize it so its viewport is actually drawn, then re-run
`python 326shot.py <out.png> "<x>,<y>,<z>" "<x>,<y>,<z>"`. If the frame still repeats, the harness's
`screen_capture` is broken for that window and that is a harness fault to report (rule 6).

## The Rojo panel is closed in that window, so the port cannot be switched by script

The dispatch asked for the proof on `rojo :34874`. The Forest Test's **Rojo panel is not open**
(`<runs-dir>/326-screen6.png`); `rojo-port.sh` and `reconnect34874.sh` click fixed screen
coordinates and with the panel closed would have clicked into Karen's own viewport. Clicking
**Plugins -> Rojo** three times produced only the tooltip and no docked panel.

So the proof was taken the other way: `driven-hunt-karen` -- the copy `:34873` already serves, which
her Studio is connected to -- was checked out at the code commit, the place was Played, measured,
and the copy was **restored to `main` (cf2e6955)**, verified, with `rojo :34873` still holding its
original session id. Her place was never saved, published or committed. If the Director would
rather this never happened, the clicks above (open the Rojo panel, set 34874, Connect) are the
alternative, and `driven-hunt-294` is ready.

## Not a blocker, recorded: the sunk half of the target

"None sunk more than 1.5 studs" is **not met for saved map content and was not attempted**: 721 of
the 5,659 standing models in her place were already sunk more than 1.5 before this task (529 in
`Workspace.Session`, most at exactly -2.50). That is how the bought map was authored, `TreeGround`
only ever sinks, and raising saved content is a visible change nobody has asked for.
