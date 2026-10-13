local words = require("dojo.words")
local U = require("dojo.stages.util")

-- ten lines long enough that a column up to 6 exists on every line
local function tall(rng)
  return words.lines(rng, 10, 4, 6)
end

local function move(lines, cursor, goal)
  return { kind = "move", lines = lines, cursor = cursor, goal = goal, prompt = "Move to the highlighted character" }
end

-- Counts open World 2 (decision 0014): j and k by the relative line numbers,
-- and x for a few stray letters. h and l take no counts.
return {
  key = "counts",
  title = "counts",
  name = "Repeat with a count",
  kind = "move",
  adds = { "count" },
  focus = { { "count" } },
  explainer = {
    heading = "Repeat a move with a count",
    keys = {
      { "4j", "four lines down" },
      { "3k", "three lines up" },
      { "2x", "delete two characters" },
    },
    example = {
      before = { "sun sky sea", "red map cup", "[o]wl box key" },
      keys = "2k",
      after = { "[s]un sky sea", "red map cup", "owl box key" },
    },
    combos = {
      { "3jA…", "down three lines, then append" },
      { "4kx", "up four lines, then delete" },
    },
    tip = "Read the relative number next to the target line, type it, then j or k. h and l take no counts. From now on habit mode blocks a fourth press in a row in challenges (H in the menu).",
  },
  generate = function(rng, _)
    if rng:chance(0.3) then
      local line, goal, col = require("dojo.stages.x").stray(rng, 2, 3)
      return {
        kind = "edit",
        lines = { line },
        cursor = { 1, col },
        goal_lines = { goal },
        prompt = "Delete the struck-through letters",
      }
    end
    local lines = tall(rng)
    for _ = 1, 50 do
      local r = rng:int(1, #lines)
      local c = rng:int(0, 6)
      local r2 = r + (rng:chance(0.5) and 1 or -1) * rng:int(2, 8)
      if lines[r2] then
        return move(lines, { r, c }, { r2, c })
      end
    end
  end,
  -- a count to reach the line, then a move or edit from World 1 there
  combined = function(rng, ctx)
    local lines = tall(rng)
    local r = rng:int(1, #lines)
    local r2 = r + (rng:chance(0.5) and 1 or -1) * rng:int(2, 6)
    if not lines[r2] then
      return nil
    end
    local kind = rng:pick({ "move", "append", "insert", "x" })
    if kind == "move" then
      local c = rng:int(0, math.min(#lines[r], #lines[r2]) - 1)
      local c2 = U.clamp(c + rng:pick({ -3, -2, -1, 1, 2, 3 }), 0, #lines[r2] - 1)
      return move(lines, { r, c }, { r2, c2 })
    end
    local t = require("dojo.stages." .. kind).generate(rng, ctx)
    if not t then
      return nil
    end
    lines[r2] = t.lines[1]
    local goal = U.copy(lines)
    goal[r2] = t.goal_lines[1]
    local spot = kind == "append" and rng:int(0, #lines[r] - 1) or t.cursor[2] + rng:int(-2, 2)
    return {
      kind = "edit",
      lines = lines,
      cursor = { r, U.clamp(spot, 0, #lines[r] - 1) },
      goal_lines = goal,
      prompt = t.prompt,
    }
  end,
}
