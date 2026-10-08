-- Building combined rounds and chains from basic tasks (SPEC §5, decisions
-- 0008 and 0009). Whether a round really combines moves is decided later by
-- the solver's concept tags, not here.
local words = require("dojo.words")
local text = require("dojo.text")
local U = require("dojo.stages.util")

local M = {}

local function has_punct(lines)
  for _, l in ipairs(lines) do
    if l:find("[^%w%s]") then
      return true
    end
  end
  return false
end

local function filler(rng, code)
  return code and words.code_line(rng) or words.line(rng, rng:int(4, 7))
end

-- the spot a task is about: its target, or the start of the change
local function task_spot(task)
  if task.kind == "move" then
    return task.goal[1], task.goal[2]
  end
  local from = text.regions(task.lines, task.goal_lines)
  return from.srow, from.scol
end

-- The generic combine step: put the task in a taller buffer and start the
-- cursor on another line or further along the same line, so the task's move
-- has to follow another one (3jA…, 2j$, 3lx).
function M.combine(task, rng, ctx)
  local t = vim.deepcopy(task)
  local code = has_punct(task.lines)
  local above, below = rng:int(0, 3), rng:int(0, 3)
  if above + below < 2 then
    below = 2 - above
  end
  local A, B = {}, {}
  for i = 1, above do
    A[i] = filler(rng, code)
  end
  for i = 1, below do
    B[i] = filler(rng, code)
  end
  local function wrap(ls)
    local out = {}
    vim.list_extend(out, A)
    vim.list_extend(out, ls)
    vim.list_extend(out, B)
    return out
  end
  t.lines = wrap(task.lines)
  if t.kind == "move" then
    t.goal = { task.goal[1] + above, task.goal[2] }
  else
    t.goal_lines = wrap(task.goal_lines)
  end
  local trow, tcol = task_spot(task)
  trow = trow + above
  -- how far sideways: a few cells until word motions or f/t are known
  local spread = (ctx.learned.wb or ctx.learned.f) and 10 or 3
  local r = trow
  if rng:chance(0.65) then
    local cands = {}
    for rr = 1, #t.lines do
      if rr ~= trow and math.abs(rr - trow) <= 4 then
        cands[#cands + 1] = rr
      end
    end
    r = rng:pick(cands)
  end
  local line = t.lines[r]
  local col
  if r == trow then
    local off = rng:int(2, math.max(2, spread)) * (rng:chance(0.5) and 1 or -1)
    col = U.clamp(tcol + off, 0, math.max(0, #line - 1))
  else
    col = U.clamp(tcol + rng:int(-spread, spread), 0, math.max(0, #line - 1))
  end
  t.cursor = { r, col }
  return t
end

-- A task that fits on one line becomes a chain step:
-- { kind, line, goal_col | goal_line, prompt }
function M.line_step(task)
  if not task then
    return nil
  end
  if task.kind == "move" then
    if task.cursor[1] ~= task.goal[1] then
      return nil
    end
    return { kind = "move", line = task.lines[task.goal[1]], goal_col = task.goal[2], prompt = task.prompt }
  end
  if #task.lines ~= 1 or #task.goal_lines ~= 1 then
    return nil
  end
  return { kind = "edit", line = task.lines[1], goal_line = task.goal_lines[1], prompt = task.prompt }
end

-- a plain "go here" step
function M.spot_step(rng, code)
  local line = filler(rng, code)
  return {
    kind = "move",
    line = line,
    goal_col = rng:int(0, #line - 1),
    prompt = "Move to the highlighted character",
  }
end

-- Stack chain steps on separate lines with filler between them, in shuffled
-- row order so the player travels up and down. Returns lines, the row of each
-- step, and a start cursor that is not on the first step's line.
function M.layout(rng, steps)
  local order = {}
  for i = 1, #steps do
    order[i] = i
  end
  rng:shuffle(order)
  local code = false
  for _, s in ipairs(steps) do
    if s.line:find("[^%w%s]") then
      code = true
    end
  end
  local lines, rows = {}, {}
  for _, i in ipairs(order) do
    for _ = 1, rng:int(0, 1) do
      lines[#lines + 1] = filler(rng, code)
    end
    lines[#lines + 1] = steps[i].line
    rows[i] = #lines
  end
  if rng:chance(0.5) then
    lines[#lines + 1] = filler(rng, code)
  end
  local r
  repeat
    r = rng:int(1, #lines)
  until r ~= rows[1]
  return lines, rows, { r, rng:int(0, math.max(0, #lines[r] - 1)) }
end

-- The sub-task for chain step i, given the buffer and cursor before it.
function M.step_task(step, lines, cursor)
  if step.kind == "move" then
    return { kind = "move", lines = lines, cursor = cursor, goal = { step.row, step.goal_col } }
  end
  local goal = vim.deepcopy(lines)
  goal[step.row] = step.goal_line
  return { kind = "edit", lines = lines, cursor = cursor, goal_lines = goal }
end

return M
