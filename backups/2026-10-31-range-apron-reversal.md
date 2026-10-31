# 2026-10-31 -- the range's apron reversal (task 317), archived by task 321

**Why it went.** Task 321 made each range animal run ONE pass: it enters at one end of the span, crosses
it, leaves at the other, and is removed. There is no turn-around any more, so the machinery that spent
one at a walk inside the apron has nothing to do. Karen, 2026-10-31, after playing 319: *"it's the same
animal running we need each time it run on one side new one comes ... in between need to wait to long to
get another animal"*. MEASURED on main in her place (`<runs-dir>/321-pass.luau` at `d7ae1929`): one
animal, four crossings, **7.12 s out of sight between them** -- and that 7.12 s IS this reversal.

**What went, from `src/server/Range/init.luau`:** `Range.CONFIG.TURN_STUDS_PER_SECOND` (2.5),
`TURN_ALIGN_STUDS` (0.3), `TURN_PROGRESS_STUDS` (0.1), `TURN_STRAIGHT_RATIO` (0.02), `TURN_SLOW_STUDS`
(10), `TURN_MAX_SECONDS` (6); the `turnDone` and `inSpan` functions; the `turning` / `turningSince` /
`turnLastX` / `turnLastZ` fields of `Trial`; the leg flip in `order` and the brake and pivot speed
override beside it. `TURN_AIM_STUDS` (6) SURVIVES, renamed `AIM_MIN_STUDS`: it is the floor of the
pure-pursuit lookahead, which the lane line still needs at a walk. `PASS_MAX_SECONDS` replaces
`TURN_MAX_SECONDS` as the guard on an animal that never arrives.

**The task-317 findings this keeps on the record.** A 180-degree reversal at 24 studs/s has a turning
radius the 20-stud apron cannot hold: on main it put the animal 19.7 studs off its own lane line INSIDE
the span, 144.7 studs from a shooter who had picked 125. Eight measured cycles brought it to 0.3 studs
by braking to a walk BEFORE the pivot and steering at a lane-line point `AIM_SECONDS` ahead. The
lane-line steering is the half that stayed; the braking and the pivot went with the turn-around itself.

**The spec case archived with it** (`tests/server/range.spec.luau`, "walks the reversal only OUTSIDE the
span, never inside it"). It asserted that the walk WAS issued out in the apron (`outsideAtTurn > 0`),
which is false by construction now, and that it was never issued inside the span, which is now true
because no such speed exists. Verbatim:

```lua
		-- THE REVERSAL IS SPENT OUTSIDE THE SPAN, AND THE GUARD IS THE POINT OF THE CASE: the turn
		-- walk may never be issued INSIDE the span, or the crossing the board teaches would be
		-- slowed by it. Both halves, in one case: it IS issued out there, and it is NEVER issued in.
		it("walks the reversal only OUTSIDE the span, never inside it", function()
			local clock, now = newClock()
			local fake = newFakeBoars()
			expect(select(1, startRange(fake, now, nil, nil, nil, true))).to.equal(true)
			expect(Range.setPace(1, "run")).to.equal(true)
			local trial = Range.trialOf(1) :: any
			local asked = trial.speedStudsPerSecond
			local anchor = Vector3.new(DEV_ROW.x, 0, DEV_ROW.z)
			local lo, hi = RangeData.sightSpanFor(anchor, 1, LAYOUT, trial.distanceStuds, true)
			-- A FEW SECONDS OF LANE before the counting starts, so the animal is under way rather
			-- than sitting at the end it was released from.
			advance(fake, clock, 4)
			expect(fake.at(1)).to.be.ok()
			local insideAtTurn, outsideAtTurn, insideAtPace = 0, 0, 0
			local dt = 1 / 60
			for _ = 1, math.floor((6 * RangeData.laneLength(LAYOUT) / asked + 4) / dt) do
				clock.t += dt
				fake.advance(dt)
				Range.step(dt)
				local leads = fake.leadsAt(1)
				local last = leads[#leads]
				local here = fake.at(1) :: any
				if last ~= nil and here ~= nil then
					local x = here.position.X
					local inside = x >= lo and x <= hi
					if last.speed == Range.CONFIG.TURN_STUDS_PER_SECOND then
						if inside then
							insideAtTurn += 1
						else
							outsideAtTurn += 1
						end
					elseif inside and last.speed == asked then
						insideAtPace += 1
					end
				end
			end
			-- NEVER INSIDE. This is the guard; it is 0 on main too, which is why the next two lines
			-- are what make the case fail there.
			expect(insideAtTurn).to.equal(0)
			-- ...AND IT REALLY HAPPENED OUT THERE. On main every order is the pace speed, so this
			-- is 0 and the case is red.
			expect(outsideAtTurn > 0).to.equal(true)
			-- ...and the span itself is still run at the pace that was asked for.
			expect(insideAtPace > 0).to.equal(true)
			TestKit.note(
				string.format(
					"range 317: reversal walk issued on %d steps outside the span, %d inside; %d at-pace steps inside",
					outsideAtTurn,
					insideAtTurn,
					insideAtPace
				)
			)
			Range.stop()
		end)
```
