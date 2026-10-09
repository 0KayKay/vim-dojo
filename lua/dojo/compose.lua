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
-- has to follow another one (3jA…, 2j$, 3lx). opts.vertical: start a few
-- lines away, about straight above or below (2jdt,), for rounds that already
-- combine two moves on their line.
function M.combine(task, rng, ctx, opts)
  opts = opts or {}
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
  local r, col
  if not ctx.learned.count then
    -- World 1, before counts: at most 3 lines and 3 cells away, 4 presses in
    -- all (decision 0014)
    for _ = 1, 20 do
      local dr = rng:int(0, 3) * (rng:chance(0.5) and 1 or -1)
      local lo = dr == 0 and 2 or 0
      local dc = rng:int(lo, math.max(lo, math.min(3, 4 - math.abs(dr)))) * (rng:chance(0.5) and 1 or -1)
      if t.lines[trow + dr] then
        r = trow + dr
        col = U.clamp(tcol + dc, 0, math.max(0, #t.lines[r] - 1))
        break
      end
    end
    if not r then
      r, col = trow, U.clamp(tcol + 2, 0, math.max(0, #t.lines[trow] - 1))
    end
  elseif opts.vertical then
    local cands = {}
    for rr = 1, #t.lines do
      if rr ~= trow and math.abs(rr - trow) <= 3 then
        cands[#cands + 1] = rr
      end
    end
    r = rng:pick(cands)
    col = U.clamp(tcol + rng:int(-2, 2), 0, math.max(0, #t.lines[r] - 1))
  else
    -- how far sideways: a few cells until word motions or f/t are known
    local spread = (ctx.learned.wb or ctx.learned.f) and 10 or 3
    r = trow
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
    if r == trow then
      local off = rng:int(2, math.max(2, spread)) * (rng:chance(0.5) and 1 or -1)
      col = U.clamp(tcol + off, 0, math.max(0, #line - 1))
    else
      col = U.clamp(tcol + rng:int(-spread, spread), 0, math.max(0, #line - 1))
    end
  end
  t.cursor = { r, col }
  return t
end

-- A task that fits on one line becomes a chain step:
-- { kind, line, goal_col | goal_line, prompt, spot, end_col, edge }
-- spot is where the step happens, end_col where the cursor is likely to be
-- afterwards, and edge marks an insertion at the line's start or end, which
-- A and I reach from anywhere on the line.
function M.line_step(task)
  if not task then
    return nil
  end
  if task.kind == "move" then
    if task.cursor[1] ~= task.goal[1] then
      return nil
    end
    local c = task.goal[2]
    return { kind = "move", line = task.lines[task.goal[1]], goal_col = c, prompt = task.prompt, spot = c, end_col = c }
  end
  if #task.lines ~= 1 or #task.goal_lines ~= 1 then
    return nil
  end
  local line, goal = task.lines[1], task.goal_lines[1]
  local from, to = text.regions({ line }, { goal })
  local typed = to.ecol - to.scol
  local end_col = typed > 0 and (to.scol + typed - 1) or U.clamp(from.scol, 0, math.max(0, #goal - 1))
  local edge = from.empty and (from.scol == 0 or from.scol == #line)
  return {
    kind = "edit",
    line = line,
    goal_line = goal,
    prompt = task.prompt,
    spot = from.scol,
    end_col = end_col,
    edge = edge,
  }
end

-- a plain "go here" step, on a letter (a highlighted space is hard to see);
-- with near, within that many cells of column `from`
function M.spot_step(rng, code, from, near)
  local line = filler(rng, code)
  local lo, hi = 0, #line - 1
  if from and near then
    lo, hi = math.max(0, from - near), math.min(#line - 1, from + near)
  end
  local cands = {}
  for c = lo, hi do
    if line:sub(c + 1, c + 1) ~= " " then
      cands[#cands + 1] = c
    end
  end
  if #cands == 0 then
    return nil
  end
  local col = rng:pick(cands)
  return {
    kind = "move",
    line = line,
    goal_col = col,
    prompt = "Move to the highlighted character",
    spot = col,
    end_col = col,
  }
end

-- Stack chain steps on separate lines with filler between them. Returns lines,
-- the row of each step, and a start cursor that is not on the first step's
-- line. opts.shuffle: rows in random order (once counts make any distance
-- easy); otherwise in step order, top down or bottom up. opts.near: the start
-- is at most that many lines and cells from the first step.
function M.layout(rng, steps, opts)
  opts = opts or {}
  local order = {}
  for i = 1, #steps do
    order[i] = i
  end
  if opts.shuffle then
    rng:shuffle(order)
  elseif rng:chance(0.5) then
    for i = 1, math.floor(#order / 2) do
      order[i], order[#order - i + 1] = order[#order - i + 1], order[i]
    end
  end
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
  if #lines == 1 or rng:chance(0.5) then -- the start must be on another line
    lines[#lines + 1] = filler(rng, code)
  end
  local cands = {}
  for r = 1, #lines do
    if r ~= rows[1] and (not opts.near or math.abs(r - rows[1]) <= opts.near) then
      cands[#cands + 1] = r
    end
  end
  if #cands == 0 then -- no other line near: add one next to the first step
    table.insert(lines, rows[1] + 1, filler(rng, code))
    for i, r in ipairs(rows) do
      if r > rows[1] then
        rows[i] = r + 1
      end
    end
    cands = { rows[1] + 1 }
  end
  local r = rng:pick(cands)
  local col
  if opts.near and not steps[1].edge then
    col = U.clamp(steps[1].spot + rng:int(-opts.near, opts.near), 0, math.max(0, #lines[r] - 1))
  else
    col = rng:int(0, math.max(0, #lines[r] - 1))
  end
  return lines, rows, { r, col }
end

-- The sub-task for chain step i, given the buffer, cursor and remembered
-- column (curswant, nil = the cursor column) before it.
function M.step_task(step, lines, cursor, curswant)
  if step.kind == "move" then
    return { kind = "move", lines = lines, cursor = cursor, curswant = curswant, goal = { step.row, step.goal_col } }
  end
  local goal = vim.deepcopy(lines)
  goal[step.row] = step.goal_line
  return { kind = "edit", lines = lines, cursor = cursor, curswant = curswant, goal_lines = goal }
end

return M
