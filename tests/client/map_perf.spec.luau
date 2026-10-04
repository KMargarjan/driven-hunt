--!nocheck
-- map_perf.spec: WHAT THE MAP COSTS A FRAME, measured on the client that draws it.
--
-- IT ASSERTS ONLY A CATASTROPHE CEILING AND REPORTS THE REST, and that is deliberate (design, "Client
-- specs"). The machine this runs on is Karen's, nobody controls it, and a tight threshold here would
-- be a flaky spec -- which this repo has already decided is worse than no spec (TASKS.md rows
-- 82a(c)/(d)). The number that DECIDES anything is measurement M7, read by a human from the note
-- this case prints; what the ceiling catches is the map having made the game unplayable outright.
--
-- Design: docs/design/map-generator.md, "Client specs" and "The measured gate, and the two numbers
-- to turn"
-- Note:   docs/research/2026-10-04-forest-block1.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage:WaitForChild("Map"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- 120 frames is the design's own sample. At 60 fps that is two seconds, which is short enough not to
-- stretch the run and long enough that one stutter does not become the median.
local FRAMES = 120
-- A CATASTROPHE, not a target: 100 ms is six frames at 60 fps. A map that pushes the 95th percentile
-- past this is not slow, it is broken.
local P95_CEILING_SECONDS = 0.100

local function percentile(sorted: { number }, fraction: number): number
	local index = math.clamp(math.ceil(#sorted * fraction), 1, #sorted)
	return sorted[index]
end

return function()
	describe("the map's frame cost", function()
		it("draws without a catastrophe, and reports the median for the Director to read", function()
			local deltas: { number } = {}
			local connection
			connection = RunService.RenderStepped:Connect(function(delta)
				if #deltas < FRAMES then
					table.insert(deltas, delta)
				end
			end)
			local deadline = os.clock() + 10
			while #deltas < FRAMES and os.clock() < deadline do
				task.wait()
			end
			connection:Disconnect()
			-- A client that never rendered has nothing to say, and saying nothing is better than
			-- reporting a percentile of three samples as if it meant something.
			if #deltas < FRAMES / 2 then
				TestKit.note(string.format("map_perf: only %d frames in 10 s; no measurement taken", #deltas))
				return
			end
			table.sort(deltas)
			local median = percentile(deltas, 0.5)
			local p95 = percentile(deltas, 0.95)
			-- WHERE the camera was, because a frame time without a place is not a measurement: the
			-- forest costs a different number on the road than it does in the rim.
			local camera = Workspace.CurrentCamera
			local where = if camera then camera.CFrame.Position else Vector3.zero
			TestKit.note(
				string.format(
					"map_perf (%s): median %.1f ms, p95 %.1f ms over %d frames at (%.0f, %.0f, %.0f)",
					Map.EXPECTED_WORLD,
					median * 1000,
					p95 * 1000,
					#deltas,
					where.X,
					where.Y,
					where.Z
				)
			)
			if p95 > P95_CEILING_SECONDS then
				error(
					string.format(
						"the 95th-percentile frame took %.0f ms, over the %.0f ms catastrophe ceiling",
						p95 * 1000,
						P95_CEILING_SECONDS * 1000
					),
					0
				)
			end
		end)

		it("streams the world the contract says it streams", function()
			-- A CHARACTER IN THE VOID MEASURES FINE, which is why this looks DOWN rather than at a
			-- number: this project has shipped "measured correct, looked wrong" before. If streaming
			-- has not delivered the ground under the player, a downward ray finds nothing.
			expect(Workspace.StreamingEnabled).to.equal(Map.STREAMING.enabled)
			local player = game:GetService("Players").LocalPlayer
			local character = player and player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root == nil then
				TestKit.note("map_perf: no character yet, so the ground check is dormant")
				return
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			local hit = Workspace:Raycast((root :: BasePart).Position, Vector3.new(0, -24, 0), params)
			if hit == nil then
				error("a downward ray from the character found no ground within 24 studs: the player is in the void", 0)
			end
			TestKit.note(
				string.format(
					"map_perf: ground %.1f studs below the root, %s",
					((root :: BasePart).Position - hit.Position).Magnitude,
					if hit.Instance then hit.Instance.Name else "terrain"
				)
			)
		end)
	end)
end
