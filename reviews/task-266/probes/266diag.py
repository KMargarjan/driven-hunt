"""TASK 266 item 4: WHY DOES A REAL CLICK NOT COUNT AS A SHOT?

`aimshot.py --selftest` counts `ShotLanded`. This counts THREE things at once for the same clicks:

  * `ShotFired`  -- fired by `Weapon.onFireRequest` at the END of every accepted trigger,
                    unconditionally (`channel.ShotFired:FireAllClients`). This is "the trigger
                    reached the game".
  * `ShotLanded` -- fired by `onShotLanded` **only when `#res.impacts > 0`** (read it: the whole
                    `FireAllClients` block is inside that `if`). A shot that hits NOTHING sends
                    none.
  * `StateChanged` -- every publish, including a REFUSAL, which carries `refused`.

So if ShotFired >> ShotLanded, the trigger works and the shots missed; if both are 0, the click
never reached the game. Writes only under <runs-dir>.
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, r"<repo>	ools")
sys.path.insert(0, r"<runs-dir>")
import studio_mcp  # noqa: E402
import ftsid  # noqa: E402

RUNS = r"<runs-dir>"
TITLE = "*Driven Hunt Forest Test*"
GEN = "266a"
SHOTS = int(sys.argv[1]) if len(sys.argv) > 1 else 5
NO_RELOAD = "--no-reload" in sys.argv

ARM = r"""
local RS = game:GetService("ReplicatedStorage")
local GEN = "%GEN%"
if RS:GetAttribute("DHTrigGen") ~= GEN then
    RS:SetAttribute("DHTrigGen", GEN)
    RS:SetAttribute("DHTrigFired", 0)
    RS:SetAttribute("DHTrigLanded", 0)
    RS:SetAttribute("DHTrigRefused", "")
    RS:SetAttribute("DHTrigClicks", 0)
    local remotes = RS:WaitForChild("Shotgun"):WaitForChild("Remotes")
    local UIS = game:GetService("UserInputService")
    task.spawn(function()
        local a = remotes:WaitForChild("ShotFired").OnClientEvent:Connect(function()
            RS:SetAttribute("DHTrigFired", (RS:GetAttribute("DHTrigFired") or 0) + 1)
        end)
        local b = remotes:WaitForChild("ShotLanded").OnClientEvent:Connect(function()
            RS:SetAttribute("DHTrigLanded", (RS:GetAttribute("DHTrigLanded") or 0) + 1)
        end)
        local c = remotes:WaitForChild("StateChanged").OnClientEvent:Connect(function(snap)
            if type(snap) == "table" and snap.refused ~= nil then
                RS:SetAttribute("DHTrigRefused", tostring(RS:GetAttribute("DHTrigRefused")) .. tostring(snap.refused) .. " ")
            end
        end)
        local d = UIS.InputBegan:Connect(function(input, gp)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                RS:SetAttribute("DHTrigClicks", (RS:GetAttribute("DHTrigClicks") or 0) + 1)
                RS:SetAttribute("DHTrigGP", tostring(gp))
            end
        end)
        while RS:GetAttribute("DHTrigGen") == GEN do task.wait(0.5) end
        a:Disconnect() b:Disconnect() c:Disconnect() d:Disconnect()
    end)
end
local me = game:GetService("Players").LocalPlayer
local tool = me.Character and me.Character:FindFirstChildOfClass("Tool")
return string.format("armed tool=%s", tostring(tool and tool.Name))
"""

READ = r"""
local RS = game:GetService("ReplicatedStorage")
local me = game:GetService("Players").LocalPlayer
local tool = me.Character and me.Character:FindFirstChildOfClass("Tool")
return string.format("clicks=%s gameProcessed=%s ShotFired=%s ShotLanded=%s refused=[%s] tool=%s",
    tostring(RS:GetAttribute("DHTrigClicks")), tostring(RS:GetAttribute("DHTrigGP")),
    tostring(RS:GetAttribute("DHTrigFired")), tostring(RS:GetAttribute("DHTrigLanded")),
    tostring(RS:GetAttribute("DHTrigRefused")), tostring(tool and tool.Name))
"""


def flat(text):
    return " ".join(l.strip() for l in text.splitlines() if l.strip() and not l.strip().startswith("--"))


def ps(script, *args):
    return subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File",
                           os.path.join(RUNS, script), *[str(a) for a in args]],
                          capture_output=True, text=True)


def click_point():
    out = ps("winrect.ps1", "-Title", TITLE)
    line = (out.stdout or "").strip().splitlines()[-1].split()
    left, top, right, bottom = (int(v) for v in line)
    return (left + right) // 2, (top + bottom) // 2


def main():
    s = studio_mcp.Studio()
    sid = ftsid.resolve(s)
    xy = click_point()
    print("CLICK POINT", xy)
    print("ARM", (s.query("Client", flat(ARM).replace("%GEN%", GEN), studio_id=sid) or "").strip())
    for n in range(SHOTS):
        if not NO_RELOAD:
            ps("263key.ps1", "R")
            time.sleep(2.6)
        ps("park.ps1", xy[0], xy[1], "-Title", TITLE)
        time.sleep(0.35)
        out = ps("click.ps1", xy[0], xy[1], "-Title", TITLE)
        said = ((out.stdout or "") + (out.stderr or "")).strip().splitlines()
        print("  click %d: %s" % (n + 1, said[-1] if said else "?"), flush=True)
        time.sleep(1.2)
        print("     ", (s.query("Client", flat(READ), studio_id=sid) or "").strip(), flush=True)
    time.sleep(1.0)
    print((s.query("Client", flat(READ), studio_id=sid) or "").strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
