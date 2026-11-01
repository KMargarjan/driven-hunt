# ESCALATE -- Task 326

## NEEDS KAREN (or the Director at the machine): the Forest Test proof at the code commit

2026-11-01 ~18:55 UTC. Task 326's fix is committed (`a69a1b63`), the full one-player gate is
`PASS: 34/34 ... (clean tree) scope=all`, and the BEFORE census in Karen's place is measured and
in `reviews/task-326/REQUEST.md`. **The AFTER census in her place is not, and I could not take it
myself.**

What it needs: her Forest Test (place 130094961655666) pointed at `rojo :34874`, which is now
serving `C:\Users\karen\Desktop\driven-hunt-294`.

Why I stopped instead of working around it: the Rojo panel is **not open** in that Studio window
(`<runs-dir>/326-screen.png`, taken 18:52 UTC -- the window shows the Terrain Editor, no Rojo
panel). `<runs-dir>/rojo-port.sh` and `reconnect34874.sh` click fixed screen coordinates, so with
the panel closed they would have clicked blind into the viewport of Karen's own place.

### The exact clicks
1. In the **Driven Hunt Forest Test** Studio window: **Plugins** tab -> **Rojo** -> **Open Rojo**
   (the panel).
2. In the panel, set the port to **34874** and press **Connect**.
3. Accept the confirmation dialog if one is shown (it lists what Rojo will remove).
4. Tell the Builder, or run it directly:
   - `cd <runs-dir> && python 326play.py start`, wait ~70 s
   - `python 326play.py console | grep "ForestTestBoot] places"` -- the line must now carry
     `... left in the air ...` and `... re-seated ...`; the main line does not
   - `python 326census.py Server --out 326-census-play-326.json` then
     `python 326report.py 326-census-play-326.json`
   - `python 326play.py stop`
5. **Put her place back on `:34873`** (same panel) and check the panel shows it.

### What the after census must show (the task's target)
Zero models with a trunk base more than **0.3** studs above the terrain under its own footprint.
Before, at main: **646** in `DrivePlaces` (worst 1812.81) and **4** in `Workspace.Session`
(29.0 / 34.4 / 53.5 / 65.2).

The "none sunk more than 1.5 studs" half of the target is **not met for saved map content and was
not attempted**: 721 of the 5,659 standing models in her place are already sunk more than 1.5
studs (529 of them in `Workspace.Session`, most of them at exactly -2.50), which is how that map
was authored. `TreeGround` only ever sinks a tree -- raising saved content is a different question
and a visible change Karen has not asked for. Everything this task PLANTS is sunk `sinkFor`, 0.6.

## Rule 5 could not be met: no frame
`screen_capture` against that Studio returned the SAME cached image for six different cameras and
for a confirmed character move (`<runs-dir>/326-before-A-eye.png` ... `326-before-S1.png`, all the
lodge porch). `326frame.py` parks the client camera and `326shot.py` stands the player at the
measured spot; both report success in Luau and both yield that frame. Whatever the cause, no
picture from that window is evidence of anything right now, and none is claimed.
