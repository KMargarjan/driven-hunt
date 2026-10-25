"""TASK 266: ONE REAL SHOT, WITH ITS OWN KNOWN-BAD INPUT FLAG IN FRONT OF IT.

WHY THIS EXISTS AND `aimshot.py` IS NOT ENOUGH (task 266 item 4, MEASURED 2026-10-25).

`aimshot.py --selftest` answered **5 clicks -> 1 ShotLanded, SELFTEST FAIL** in the Forest Test, and
task 265 round 3 recorded the same thing as *"6 real focused clicks, 0 shots, undiagnosed"*. It is
diagnosed now, and it is not the click and not the gun:

  1. `266diag.py` counted, for the same real clicks, `UserInputService.InputBegan` on the client
     (**5 of 5, gameProcessed=false**), `ShotFired` (**0**), `ShotLanded` (**0**) and every
     `StateChanged` carrying `refused` (**none**). So the clicks arrived and the server answered
     nothing at all.
  2. `266-bound.luau` read `ContextActionService:GetAllBoundActionInfo()`:
     `DrivenHunt.Weapon.Fire{MouseButton1}` **is** bound. So the binding is not the fault.
  3. `266-who.luau` read the SERVER: `team=Drivers held=[Horn] at 3660,190,-2670`.
     **The player was a BEATER holding a HORN, 580 studs from the road.** The drive had rolled over
     to drive 2 and reassigned him (the console: *"Alhamdulilah824 is a beater at (3660, 191,
     -2670)"*), and task 265's own state probe had read `team=Shooters tool=Shotgun` in drive 1.

  THE SILENCE IS `Weapon.onFireRequest`'s FIRST GATE: `Weapon.heldId(player)` does not know a Horn,
  so `id` falls back to `Weapons.PRIMARY`, `stateOf(player, id)` is nil, and the handler does
  `return "untracked"` **with no publish of any kind**. No `ShotFired`, no `refused`, nothing on the
  wire. A click by a beater is indistinguishable, from the client, from a click that never happened.

So the instrument's fault was not the trigger: it was **clicking without checking who the player is**.
This file reads the SERVER's own answer -- team, the tool actually in the character, and the rounds
in it -- IMMEDIATELY BEFORE every click, and REFUSES to click when it is not a shooter with a loaded
gun. `0 ShotFired after a click is a FAIL of the instrument, never data` (the Director's method rule).

It also separates the two signals `aimshot` conflated:
  * `ShotFired`  -- fired at the END of every accepted trigger, unconditionally. "The trigger worked."
  * `ShotLanded` -- fired by `onShotLanded` ONLY when `#res.impacts > 0`. "The shot hit something."
A shot into the sky sends the first and not the second, so counting the second as the trigger makes
every miss look like a dead click.

Usage:
  266shot.py --check                      read the preconditions and stop
  266shot.py --kind any [--lead] [--still] [--out <name>] [--range 250]

Nothing here is in the repo: Director ops. It writes only under <runs-dir>.
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.join("<repo>", "tools"))
sys.path.insert(0, "<runs-dir>")
import studio_mcp  # noqa: E402
import ftsid  # noqa: E402

RUNS = "<runs-dir>"
TITLE = "*Driven Hunt Forest Test*"
GEN = "266b"


def arg(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        return sys.argv[i + 1] if i + 1 < len(sys.argv) else default
    return default


KIND = arg("--kind", "any")
LEAD = "--lead" in sys.argv
STILL = "--still" in sys.argv
CHECK = "--check" in sys.argv
SLUG = "--slug" in sys.argv
SHOTS = int(arg("--shots", "1"))
OUT = arg("--out", "266shot")
MAX_RANGE = float(arg("--range", "250"))

# ---------------------------------------------------------------- the preconditions (SERVER)
#
# EVERY ONE OF THESE IS A FACT ABOUT AN INSTANCE, not module state: a probe gets a FRESH module
# cache (memory: studio-mcp-execute-luau-single-line), so `Weapon.getSnapshot` from here would read
# a Weapon that has never seen a player. The team is `Player.Team`, the tool is a child of the
# character, and the rounds are the Tool's own attributes, published by the live Weapon.
PRECHECK = r"""
local Players = game:GetService("Players")
local p = Players:GetPlayers()[1]
if p == nil then return "PRE FAIL no player" end
local ch = p.Character
if ch == nil then return "PRE FAIL no character" end
local hum = ch:FindFirstChildOfClass("Humanoid")
if hum == nil or hum.Health <= 0 then return "PRE FAIL dead" end
local tool, names = nil, {}
for _, t in ipairs(ch:GetChildren()) do
    if t:IsA("Tool") then table.insert(names, t.Name) if t.Name ~= "Horn" then tool = t end end
end
local team = tostring(p.Team and p.Team.Name)
local attrs = {}
if tool then for k, v in tool:GetAttributes() do table.insert(attrs, k .. "=" .. tostring(v)) end end
table.sort(attrs)
local root = ch.PrimaryPart
local head = string.format("team=%s held=[%s] gun=%s at %s", team, table.concat(names, ","),
    tostring(tool and tool.Name),
    root and string.format("%.0f,%.0f,%.0f", root.Position.X, root.Position.Y, root.Position.Z) or "?")
if team ~= "Shooters" then return "PRE FAIL (not a shooter) " .. head end
if tool == nil then return "PRE FAIL (no gun in the character) " .. head end
return "PRE OK " .. head .. " attrs{" .. table.concat(attrs, " ") .. "}"
"""

# ---------------------------------------------------------------- arm (CLIENT)
#
# Holds the real first-person view on the chosen point (`DHTestLook`, task 263) and leaves the
# listeners that record, for each shot: the camera ray AT THE TRIGGER FRAME (`InputBegan`, the very
# event `Weapon.Input.fire` answers), the target's CFrame and `AssemblyLinearVelocity` on that same
# frame (task 265 round 2's `shotspy`, L-021), and then the server's `ShotLanded` payload paired
# with it -- part, world point, and the point in the PART'S OWN FRAME, which is the only frame in
# which "the chest" and "the rump" mean anything.
ARM = r"""
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local me = Players.LocalPlayer
local char = me and me.Character
local head = char and (char:FindFirstChild("Head") or char.PrimaryPart)
if head == nil then return "NO character" end
local eye = (head :: BasePart).Position
local KIND = "%KIND%"
local LEAD = %LEAD%
local STILL = %STILL%
local MAX_RANGE = %RANGE%
local folder = Workspace:FindFirstChild("Boars")
if folder == nil then return "NO Boars folder" end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local ignore = { char }
for _, n in ipairs({ "Boars", "Foliage", "WeaponEffects" }) do
    local f = Workspace:FindFirstChild(n)
    if f then table.insert(ignore, f) end
end
params.FilterDescendantsInstances = ignore
local target, best, blocked, moving = nil, math.huge, 0, 0
for _, part in ipairs(folder:GetChildren()) do
    if part:IsA("BasePart") and part:GetAttribute("Carcass") ~= true and part:GetAttribute("Damageable") == true then
        local species = tostring(part:GetAttribute("Species"))
        local kind = tostring(part:GetAttribute("Kind"))
        if KIND == "any" or species == KIND or kind == KIND then
            local speed = part.AssemblyLinearVelocity.Magnitude
            local wanted = if STILL then speed < 0.5 else speed > 3.0
            if wanted then
                local d = (part.Position - eye).Magnitude
                if d < MAX_RANGE and d < best then
                    if Workspace:Raycast(eye, (part.Position + Vector3.new(0, part.Size.Y * 0.25, 0)) - eye, params) == nil then
                        target, best = part, d
                    else
                        blocked += 1
                    end
                end
            else
                moving += 1
            end
        end
    end
end
if target == nil then return string.format("NO VISIBLE TARGET kind=%s still=%s blocked=%d wrongspeed=%d", KIND, tostring(STILL), blocked, moving) end
local chest = target:FindFirstChild("ZoneChest")
local aimAt = if chest then (chest :: BasePart).Position else target.Position
local leadStuds = 0
if LEAD then
    local okB, Ballistics = pcall(function() return require(RS:WaitForChild("Ballistics")) end)
    local okW, Weapons = pcall(function() return require(RS:WaitForChild("Weapons")) end)
    if okB and okW then
        local tool = nil
        for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") and t.Name ~= "Horn" then tool = t end end
        local id = tool and Weapons.idForToolName(tool.Name)
        local row = id and Weapons.ROWS[id]
        if row ~= nil then
            local shot = Ballistics.shotFor(row, tostring((row.AMMO_KINDS and row.AMMO_KINDS[1]) or "Slug"))
            if shot ~= nil then
                local t = Ballistics.timeToRange(shot, (aimAt - eye).Magnitude)
                local push = target.AssemblyLinearVelocity * t
                leadStuds = push.Magnitude
                aimAt = aimAt + push
            end
        end
    end
end
me:SetAttribute("DHTestLookOff", nil)
me:SetAttribute("DHTestLook", string.format("%f,%f,%f", aimAt.X, aimAt.Y, aimAt.Z))
RS:SetAttribute("DH266Target", target.Name)
RS:SetAttribute("DH266Aim", string.format("%f,%f,%f", aimAt.X, aimAt.Y, aimAt.Z))
RS:SetAttribute("DH266Track", (RS:GetAttribute("DH266Track") or 0) + 1)
do
    local RunService = game:GetService("RunService")
    local mine = RS:GetAttribute("DH266Track")
    local tracked = target
    local wantLead = LEAD
    task.spawn(function()
        while RS:GetAttribute("DH266Track") == mine and tracked.Parent ~= nil do
            local eyeNow = head and (head :: BasePart).Position
            local zone = tracked:FindFirstChild("ZoneChest")
            local p = if zone then (zone :: BasePart).Position else tracked.Position
            if wantLead and eyeNow then
                local okB, Ballistics = pcall(function() return require(RS:WaitForChild("Ballistics")) end)
                local okW, Weapons = pcall(function() return require(RS:WaitForChild("Weapons")) end)
                if okB and okW then
                    local t2 = nil
                    for _, tl in ipairs(char:GetChildren()) do if tl:IsA("Tool") and tl.Name ~= "Horn" then t2 = tl end end
                    local id2 = t2 and Weapons.idForToolName(t2.Name)
                    local row2 = id2 and Weapons.ROWS[id2]
                    local shot2 = row2 and Ballistics.shotFor(row2, tostring((row2.AMMO_KINDS and row2.AMMO_KINDS[1]) or "Slug"))
                    if shot2 then
                        p = p + tracked.AssemblyLinearVelocity * Ballistics.timeToRange(shot2, (p - eyeNow).Magnitude)
                    end
                end
            end
            me:SetAttribute("DHTestLook", string.format("%f,%f,%f", p.X, p.Y, p.Z))
            RunService.RenderStepped:Wait()
        end
    end)
end
local GEN = "%GEN%"
if RS:GetAttribute("DH266Gen") ~= GEN then
    RS:SetAttribute("DH266Gen", GEN)
    RS:SetAttribute("DH266Fired", 0)
    RS:SetAttribute("DH266Landed", 0)
    RS:SetAttribute("DH266Refused", "")
    RS:SetAttribute("DH266Clicks", 0)
    RS:SetAttribute("DH266Trigger", "")
    RS:SetAttribute("DH266Rows", "")
    RS:SetAttribute("DH266Mark", "")
    local remotes = RS:WaitForChild("Shotgun"):WaitForChild("Remotes")
    task.spawn(function()
        local trigger = nil
        local a = UIS.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            RS:SetAttribute("DH266Clicks", (RS:GetAttribute("DH266Clicks") or 0) + 1)
            local cam = Workspace.CurrentCamera.CFrame
            local name = tostring(RS:GetAttribute("DH266Target"))
            local part = Workspace:FindFirstChild("Boars") and Workspace.Boars:FindFirstChild(name)
            trigger = { cam = cam, cf = part and part.CFrame, v = part and part.AssemblyLinearVelocity, t = Workspace:GetServerTimeNow() }
            RS:SetAttribute("DH266Trigger", string.format("ray %.3f,%.3f,%.3f -> %.4f,%.4f,%.4f | %s v=%.2f at %s",
                cam.Position.X, cam.Position.Y, cam.Position.Z, cam.LookVector.X, cam.LookVector.Y, cam.LookVector.Z,
                name, trigger.v and trigger.v.Magnitude or -1,
                trigger.cf and string.format("%.2f,%.2f,%.2f", trigger.cf.Position.X, trigger.cf.Position.Y, trigger.cf.Position.Z) or "?"))
        end)
        local b = remotes:WaitForChild("ShotFired").OnClientEvent:Connect(function()
            RS:SetAttribute("DH266Fired", (RS:GetAttribute("DH266Fired") or 0) + 1)
        end)
        local c = remotes:WaitForChild("ShotLanded").OnClientEvent:Connect(function(payload)
            if type(payload) ~= "table" or type(payload.impacts) ~= "table" or #payload.impacts == 0 then return end
            RS:SetAttribute("DH266Landed", (RS:GetAttribute("DH266Landed") or 0) + 1)
            local rows = {}
            for i, pos in ipairs(payload.impacts) do
                local part = payload.parts and payload.parts[i]
                local localTxt, zone = "?", "?"
                if typeof(part) == "Instance" and part:IsA("BasePart") then
                    local lp = part.CFrame:PointToObjectSpace(pos)
                    localTxt = string.format("%.3f,%.3f,%.3f", lp.X, lp.Y, lp.Z)
                    zone = tostring(part:GetAttribute("HitZone") or part.Name)
                end
                local across = -1
                if trigger ~= nil then
                    local to = pos - trigger.cam.Position
                    across = (to - trigger.cam.LookVector * to:Dot(trigger.cam.LookVector)).Magnitude
                end
                table.insert(rows, string.format("[%d] %s zone=%s world %.2f,%.2f,%.2f local %s ACROSS %.3f",
                    i, typeof(part) == "Instance" and part.Name or tostring(part), zone, pos.X, pos.Y, pos.Z, localTxt, across))
            end
            RS:SetAttribute("DH266Rows", table.concat(rows, " ;; "))
        end)
        local d = remotes:WaitForChild("HitMarker").OnClientEvent:Connect(function(payload)
            if type(payload) ~= "table" then return end
            RS:SetAttribute("DH266Mark", tostring(RS:GetAttribute("DH266Mark")) ..
                string.format("%s/%s ", tostring(payload.kind), tostring(payload.zone)))
        end)
        local e = remotes:WaitForChild("StateChanged").OnClientEvent:Connect(function(snap)
            if type(snap) ~= "table" then return end
            if snap.refused ~= nil then
                RS:SetAttribute("DH266Refused", tostring(RS:GetAttribute("DH266Refused")) .. tostring(snap.refused) .. " ")
            end
            if type(snap.loaded) == "table" and type(snap.selected) == "number" then
                RS:SetAttribute("DH266Ammo", string.format("selected=%d loaded=%s|%s reserve{Buck=%s Slug=%s} open=%s",
                    snap.selected, tostring(snap.loaded[1]), tostring(snap.loaded[2]),
                    tostring(snap.reserve and snap.reserve.Buck), tostring(snap.reserve and snap.reserve.Slug),
                    tostring(snap.open)))
            end
        end)
        while RS:GetAttribute("DH266Gen") == GEN do task.wait(0.5) end
        a:Disconnect() b:Disconnect() c:Disconnect() d:Disconnect() e:Disconnect()
    end)
end
local chestLocal = "none"
if chest then
    local lp = target.CFrame:PointToObjectSpace((chest :: BasePart).Position)
    chestLocal = string.format("%.3f,%.3f,%.3f", lp.X, lp.Y, lp.Z)
end
return string.format("AIM %s/%s chestLocal=%s v=%.2f lead=%.2f range=%.1f aimAt %.2f,%.2f,%.2f eye %.2f,%.2f,%.2f",
    target.Name, tostring(target:GetAttribute("Kind")), chestLocal, target.AssemblyLinearVelocity.Magnitude,
    leadStuds, (aimAt - eye).Magnitude, aimAt.X, aimAt.Y, aimAt.Z, eye.X, eye.Y, eye.Z)
"""

READ = r"""
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local me = game:GetService("Players").LocalPlayer
local cam = Workspace.CurrentCamera.CFrame
local raw = string.split(tostring(me:GetAttribute("DHTestLook")), ",")
local off = -1
if #raw == 3 then
    local p3 = Vector3.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0, tonumber(raw[3]) or 0)
    local to = p3 - cam.Position
    if to.Magnitude > 1e-3 then
        off = math.deg(math.acos(math.clamp(cam.LookVector:Dot(to.Unit), -1, 1)))
    end
end
return string.format("offTarget=%.3f deg clicks=%s ShotFired=%s ShotLanded=%s refused=[%s] mark=[%s]\n  TRIGGER %s\n  SERVER  %s",
    off, tostring(RS:GetAttribute("DH266Clicks")), tostring(RS:GetAttribute("DH266Fired")),
    tostring(RS:GetAttribute("DH266Landed")), tostring(RS:GetAttribute("DH266Refused")),
    tostring(RS:GetAttribute("DH266Mark")), tostring(RS:GetAttribute("DH266Ammo")),
    tostring(RS:GetAttribute("DH266Trigger")), tostring(RS:GetAttribute("DH266Rows")))
"""

RELEASE = """local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
RS:SetAttribute("DH266Track", (RS:GetAttribute("DH266Track") or 0) + 1000)
Players.LocalPlayer:SetAttribute("DHTestLookOff", true) return "released" """


def flat(text):
    return " ".join(l.strip() for l in text.splitlines()
                    if l.strip() and not l.strip().startswith("--"))


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

    pre = (s.query("Server", flat(PRECHECK), studio_id=sid) or "").strip()
    print("PRECHECK", pre)
    if CHECK:
        return 0
    # THE KNOWN-BAD INPUT FLAG, IN FRONT OF THE CLICK (the Director's method rule). A beater's click
    # is answered by `return "untracked"` with no publish at all, so without this the run produces
    # silence and the silence looks like a defect in the gun.
    if not pre.startswith("PRE OK"):
        print("REFUSED: the player cannot fire. This is an INSTRUMENT fault, not data.")
        return 2

    xy = click_point()
    print("CLICK POINT", xy)
    if SLUG:
        # X IS THE PLAYER'S OWN AMMO SWITCH. Buckshot's range is 100 studs (`Shotgun.CONFIG.RANGE_STUDS`)
        # and the drive's animals stand 120-170 studs out, so a buckshot "miss" at that range is the
        # AMMO and not the aim -- measured twice on 2026-10-25 before this flag existed.
        ps("263key.ps1", "X")
        time.sleep(1.0)
    ps("park.ps1", xy[0], xy[1], "-Title", TITLE)
    time.sleep(0.35)

    code = (flat(ARM).replace("%KIND%", KIND).replace("%LEAD%", "true" if LEAD else "false")
                     .replace("%STILL%", "true" if STILL else "false")
                     .replace("%RANGE%", str(MAX_RANGE)).replace("%GEN%", GEN))
    line = ""
    for _ in range(int(arg("--poll", "25"))):
        line = (s.query("Client", code, studio_id=sid) or "").strip()
        if line.startswith("AIM"):
            break
        time.sleep(1.2)
    print("ARM", line)
    if not line.startswith("AIM"):
        return 2
    time.sleep(0.4)

    for n in range(SHOTS):
        # The gun is reloaded with the player's own R key before every shot; the HELD VIEW TRACKS the
        # animal every rendered frame, so the 2.6 s the reload costs no longer moves the aim off it
        # (task 265's own fault: a fixed point plus a walking animal).
        ps("263key.ps1", "R")
        time.sleep(2.8)
        pre2 = (s.query("Server", flat(PRECHECK), studio_id=sid) or "").strip()
        if not pre2.startswith("PRE OK"):
            print("REFUSED before shot %d:" % (n + 1), pre2)
            return 2
        # WAIT FOR THE CROSSING INSTEAD OF DEMANDING ONE. The drive brings a sounder past the stand
        # in waves: MEASURED 2026-10-25, nine animals inside 17-64 studs at 24 studs/s for about ten
        # seconds, then nothing within 90 studs for a minute. Buckshot's range is 100 studs
        # (`Shotgun.CONFIG.RANGE_STUDS`), so a shot taken between waves cannot reach whatever it is
        # aimed at and its miss says nothing about the aim.
        line = ""
        for _ in range(int(arg("--poll", "25"))):
            line = (s.query("Client", code, studio_id=sid) or "").strip()
            if line.startswith("AIM"):
                break
            time.sleep(1.2)
        print("REARM", line)
        if not line.startswith("AIM"):
            print("  no target for shot %d" % (n + 1))
            continue
        time.sleep(0.25)
        ps("park.ps1", xy[0], xy[1], "-Title", TITLE)
        time.sleep(0.2)
        out = ps("click.ps1", xy[0], xy[1], "-Title", TITLE)
        said = ((out.stdout or "") + (out.stderr or "")).strip().splitlines()
        print("CLICK %d" % (n + 1), said[-1] if said else "?")
        time.sleep(1.4)
        print((s.query("Client", flat(READ), studio_id=sid) or "").strip())
        print("  AMMO   ", (s.query("Client",
            'local RS=game:GetService("ReplicatedStorage") return tostring(RS:GetAttribute("DH266Ammo"))',
            studio_id=sid) or "").strip())
        print("  ROWS   ", (s.query("Client",
            'local RS=game:GetService("ReplicatedStorage") local r=tostring(RS:GetAttribute("DH266Rows")) RS:SetAttribute("DH266Rows","") return r',
            studio_id=sid) or "").strip())
    print("  AMMO   ", (s.query("Client",
        'local RS=game:GetService("ReplicatedStorage") return tostring(RS:GetAttribute("DH266Ammo"))',
        studio_id=sid) or "").strip())
    path = os.path.join(RUNS, OUT + ".png")
    saved, _ = s.capture(path, None, None, studio_id=sid)
    print("FRAME", saved)
    s.query("Client", flat(RELEASE), studio_id=sid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
