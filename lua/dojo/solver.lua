-- Finds par: the fewest keystrokes that solve a round with the learned moves.
--
-- Uniform-cost search over states (text, cursor, curswant). Candidate keys are
-- executed for real with :normal! in a hidden scratch buffer, so every Vim rule
-- is modelled exactly (see docs/decisions/0003-solver-runs-real-neovim.md).
local moves = require("dojo.moves")
local text = require("dojo.text")
local marks = require("dojo.marks")
local keys = require("dojo.keys")
local config = require("dojo.config")

local M = {}

-- Typed into Insert mode to find where typing starts. Generators never use it.
M.SENTINEL = "`"
local SENT = M.SENTINEL

local scratch

-- Buffer options that change motions; the play buffer uses the same values.
function M.normalize_buffer(buf)
  vim.bo[buf].iskeyword = "@,48-57,_,192-255"
  vim.bo[buf].swapfile = false
end

local function scratch_win()
  if scratch and vim.api.nvim_buf_is_valid(scratch.buf) and vim.api.nvim_win_is_valid(scratch.win) then
    return scratch
  end
  local buf = vim.api.nvim_create_buf(false, true)
  M.normalize_buffer(buf)
  vim.bo[buf].undolevels = -1
  vim.bo[buf].bufhidden = "hide"
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = 40,
    height = 5,
    hide = true,
    focusable = false,
    noautocmd = true,
    style = "minimal",
  })
  vim.wo[win].wrap = false
  scratch = { buf = buf, win = win }
  return scratch
end

-- registers the solver's x/d/c would overwrite
local REGS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", '"' }

-- Run fn in the hidden scratch window without touching the user's session:
-- no autocommands, no clipboard provider, registers and the last f/t search
-- restored afterwards (AGENTS.md rule 5).
local function with_scratch(fn)
  local sw = scratch_win()
  local ei, cb = vim.o.eventignore, vim.o.clipboard
  vim.o.eventignore = "all"
  vim.o.clipboard = ""
  local regs = {}
  for _, r in ipairs(REGS) do
    regs[r] = vim.fn.getreginfo(r)
  end
  local cs = vim.fn.getcharsearch()
  local ok, res = pcall(vim.api.nvim_win_call, sw.win, function()
    return fn(sw.buf, sw.win)
  end)
  for _, r in ipairs(REGS) do
    if regs[r].regcontents then
      vim.fn.setreg(r, regs[r])
    else
      vim.fn.setreg(r, "")
    end
  end
  vim.fn.setcharsearch(cs)
  vim.o.clipboard = cb
  vim.o.eventignore = ei
  if not ok then
    error(res, 0)
  end
  return res
end

-- the marks a player sees, drawn in the scratch buffer too: inline ghost
-- text shifts the columns j and k aim for (dojo.marks)
local mark_ns = vim.api.nvim_create_namespace("dojo.solver.marks")

local function mark(buf, task, lines)
  if task.kind == "edit" then
    marks.edit(buf, mark_ns, lines, task.goal_lines)
  else
    vim.api.nvim_buf_clear_namespace(buf, mark_ns, 0, -1)
  end
end

local function restore(st)
  vim.fn.winrestview({ lnum = st.row, col = st.col, curswant = st.cw, topline = 1, leftcol = 0 })
end

-- The column j and k aim for at the start: given (chains), or the cursor's
-- screen column with the marks drawn, as Neovim sets it when the round loads.
local function start_cw(buf, task)
  if task.curswant then
    return task.curswant
  end
  mark(buf, task, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  vim.api.nvim_win_set_cursor(0, task.cursor)
  return vim.fn.winsaveview().curswant
end

local function normal(k)
  vim.cmd("silent! normal! " .. k)
end

-- Solve a task.
-- task: { kind = "move"|"edit", lines, cursor = {row, col}, goal = {row, col} | goal_lines }
-- learned: set of move families
-- Does an edit leave every line but `row` alone? A charwise operator can
-- reach into another line (cb from column 0 changes the word at the end of
-- the line above). That is legal Vim but not what the game teaches, so the
-- solver leaves such edits out; j/k and line edges are line-wise anyway.
local function on_row(old, new, row)
  local ol = vim.split(old, "\n", { plain = true })
  local nl = vim.split(new, "\n", { plain = true })
  if #ol ~= #nl then
    return false
  end
  for i = 1, #ol do
    if i ~= row and ol[i] ~= nl[i] then
      return false
    end
  end
  return true
end

local function charwise_operator(t)
  return (t.fams.d or t.fams.c) and not t.rowlevel
end

-- the count a token repeats its move by: 4j -> 4, d2w -> 2, 3dd -> 3, w -> 1
local function count_of(t)
  return tonumber(t.keys:match("^(%d)") or t.keys:match("^[dc](%d)")) or 1
end

-- opts: { focus = { {fam, ...}, ... }, ban = function(token) -> bool, max_cost = n }
-- returns { cost, keys, display, tokens, focus } or nil
function M.solve(task, learned, opts)
  opts = opts or {}
  local cfg = config.get().solver
  local is_edit = task.kind == "edit"
  local maxcost = opts.max_cost or (is_edit and cfg.max_cost_edit or cfg.max_cost_move)
  local focus, ban = opts.focus, opts.ban

  local start = text.join(task.lines)
  local goal = is_edit and text.join(task.goal_lines) or nil
  local grow, gcol
  if not is_edit then
    grow, gcol = task.goal[1], task.goal[2]
  end
  local P0, S0, gprefix, gsuffix = 0, 0, "", ""
  -- need_typing: the goal has text the start lacks, so a finisher must type it
  local need_typing = false
  if is_edit then
    P0, S0 = text.kept(start, goal)
    gprefix = goal:sub(1, P0)
    gsuffix = S0 > 0 and goal:sub(#goal - S0 + 1) or ""
    need_typing = #goal - S0 > P0
  end

  -- Lower bound on the keys still needed from a text (admissible, for pruning).
  -- Typing rounds end with a finisher: one command key, at least one typed
  -- character and <Esc>; typed text is at least the new part minus what the
  -- remaining old text could still supply.
  local hcache = {}
  local function h_text(t)
    if t == goal then
      return 0
    end
    local v = hcache[t]
    if not v then
      if need_typing then
        local p, s = text.kept(t, goal)
        v = 2 + math.max(1, (#goal - p - s) - (#t - p - s))
      else
        v = 1
      end
      hcache[t] = v
    end
    return v
  end

  return with_scratch(function(buf)
    local cur_text, marked_text
    local cache = {}
    local function info(t)
      local c = cache[t]
      if not c then
        c = { lines = text.split(t), starts = text.line_starts(t) }
        cache[t] = c
      end
      return c
    end
    local function load(t)
      if cur_text ~= t then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, info(t).lines)
        cur_text = t
      end
      if marked_text ~= t then
        mark(buf, task, info(t).lines)
        marked_text = t
      end
    end
    local function buffer_text()
      local t = text.join(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      cur_text = t
      return t
    end

    local motion_cache, edit_cache = {}, {}
    local function motions_for(line)
      local m = motion_cache[line]
      if not m then
        m = moves.motions(learned, line)
        motion_cache[line] = m
      end
      return m
    end
    local function edits_for(line)
      local e = edit_cache[line]
      if not e then
        local mv = motions_for(line)
        e = { edits = moves.edits(learned, mv), finishers = moves.finishers(learned, mv) }
        edit_cache[line] = e
      end
      return e
    end

    -- an edited text must still be able to become the goal
    local function ok_text(t)
      if t == goal then
        return true
      end
      if #t < P0 + S0 then
        return false
      end
      if t:sub(1, P0) ~= gprefix then
        return false
      end
      if S0 > 0 and t:sub(#t - S0 + 1) ~= gsuffix then
        return false
      end
      return true
    end

    -- Only try edits near the part that still differs from the goal.
    -- Finishers complete the goal in one go, so they must start at an edge of
    -- that part (a shared letter can shift the edge, hence the margin of 2).
    local function near(n, rowlevel, finisher)
      local inf = info(n.text)
      local js, je = P0, #n.text - S0
      if rowlevel then
        local r1 = text.pos(inf.starts, js)
        local r2 = text.pos(inf.starts, math.max(js, je - 1))
        return n.row >= r1 and n.row <= r2
      end
      local off = text.offset(inf.starts, n.row, n.col)
      if finisher then
        return (off >= js - 2 and off <= js) or (off >= je and off <= je + 2)
      end
      return off >= js - 1 and off <= je
    end

    local nodes, buckets = {}, {}
    local best_goal = math.huge
    local edits_tried = {}
    local function keyof(t, row, col, cw)
      if cw > 100000 then
        cw = -1
      end
      return (is_edit and t or "") .. "\0" .. row .. ":" .. col .. ":" .. cw
    end
    -- Among equally short solutions: the stage's move, then fewer commands,
    -- then smaller counts (2kwd$ reads better than 09bd$), then by keys.
    local function better(a, b)
      if a.focus ~= b.focus then
        return a.focus
      end
      if a.ntok ~= b.ntok then
        return a.ntok < b.ntok
      end
      if a.nsum ~= b.nsum then
        return a.nsum < b.nsum
      end
      return a.keys < b.keys
    end
    local function is_goal(n)
      if is_edit then
        return n.text == goal
      end
      return n.row == grow and n.col == gcol
    end
    local function h(n)
      if is_edit then
        return h_text(n.text)
      end
      return (n.row == grow and n.col == gcol) and 0 or 1
    end
    local function push(n)
      n.h = n.h or h(n)
      if n.cost + n.h > math.min(maxcost, best_goal) then
        return
      end
      if is_goal(n) and n.cost < best_goal then
        best_goal = n.cost
      end
      local old = nodes[n.key]
      if old == nil or n.cost < old.cost then
        nodes[n.key] = n
        local b = buckets[n.cost]
        if not b then
          b = {}
          buckets[n.cost] = b
        end
        b[#b + 1] = n.key
      elseif n.cost == old.cost and not old.expanded and better(n, old) then
        nodes[n.key] = n
      end
    end
    local function child(n, t, ntext, v)
      local c = {
        text = ntext,
        row = v.lnum,
        col = v.col,
        cw = v.curswant,
        cost = n.cost + t.cost,
        ntok = n.ntok + 1,
        nsum = n.nsum + count_of(t),
        keys = n.keys .. t.keys,
        focus = n.focus or moves.matches(t, focus),
        parent = n,
        tok = t,
      }
      if ntext == n.text and not is_edit then
        c.h = (c.row == grow and c.col == gcol) and 0 or 1
      elseif ntext == n.text then
        c.h = n.h
      end
      c.key = keyof(ntext, c.row, c.col, c.cw)
      return c
    end
    local function run(n, k)
      load(n.text)
      restore(n)
      normal(k)
    end

    local function try_finisher(n, t)
      run(n, t.keys .. SENT .. "\27")
      local t2 = buffer_text()
      local o = t2:find(SENT, 1, true)
      if not o then
        return
      end
      local rest = t2:sub(1, o - 1) .. t2:sub(o + 1)
      local need = #goal - #rest
      if need <= 0 or rest:sub(1, o - 1) ~= goal:sub(1, o - 1) or rest:sub(o) ~= goal:sub(o + need) then
        return
      end
      local typed = goal:sub(o, o + need - 1)
      if typed:find("[\n`]") then
        return
      end
      if charwise_operator(t) and not on_row(n.text, rest, n.row) then
        return
      end
      local full = { keys = t.keys .. typed .. "\27", cost = t.cost + #typed + 1, fams = t.fams, typed = typed }
      push({
        text = goal,
        row = 0,
        col = 0,
        cw = 0,
        h = 0,
        cost = n.cost + full.cost,
        ntok = n.ntok + 1,
        nsum = n.nsum + count_of(t),
        keys = n.keys .. full.keys,
        focus = n.focus or moves.matches(t, focus),
        parent = n,
        tok = full,
        goal = true,
        key = "GOAL",
      })
    end

    local function expand(n)
      local line = info(n.text).lines[n.row] or ""
      for _, t in ipairs(motions_for(line)) do
        if n.cost + t.cost + n.h <= math.min(maxcost, best_goal) and not (ban and ban(t)) then
          run(n, t.keys)
          push(child(n, t, n.text, vim.fn.winsaveview()))
        end
      end
      if not is_edit then
        return
      end
      -- edits don't depend on curswant: try them once per text and position
      local ek = n.text .. "\0" .. n.row .. ":" .. n.col
      if edits_tried[ek] then
        return
      end
      edits_tried[ek] = true
      local e = edits_for(line)
      -- an operator with f/t only helps when it targets a character in or
      -- next to the part that still differs
      local js, je = P0, #n.text - S0
      local targets = {}
      for i = math.max(1, js - 1), math.min(#n.text, je + 3) do
        targets[n.text:sub(i, i)] = true
      end
      local function useful(t)
        if t.fams.f or t.fams.t then
          return targets[t.keys:sub(-1)] == true
        end
        return true
      end
      -- when text must be typed, one deletion before the finisher is enough
      -- (c covers delete + type in one command)
      -- and once c is learned, delete-then-insert never beats c{motion}
      local deletions = not need_typing or (n.text == start and not learned.c and P0 + S0 < #start)
      -- a changed region spanning lines is only reachable with line-wise edits
      local multiline = n.text:sub(P0 + 1, #n.text - S0):find("\n", 1, true) ~= nil
      if deletions then
        for _, t in ipairs(e.edits) do
          if
            (t.rowlevel or not multiline)
            and useful(t)
            and n.cost + t.cost <= math.min(maxcost, best_goal)
            and not (ban and ban(t))
            and near(n, t.rowlevel)
          then
            run(n, t.keys)
            local nt = buffer_text()
            if nt ~= n.text and ok_text(nt) and not (charwise_operator(t) and not on_row(n.text, nt, n.row)) then
              push(child(n, t, nt, vim.fn.winsaveview()))
            end
          end
        end
      end
      if need_typing then
        for _, t in ipairs(e.finishers) do
          if
            n.cost + t.cost + 2 <= math.min(maxcost, best_goal)
            and useful(t)
            and not (ban and ban(t))
            and near(n, t.rowlevel, true)
          then
            try_finisher(n, t)
          end
        end
      end
    end

    load(start)
    local s0 = {
      text = start,
      row = task.cursor[1],
      col = task.cursor[2],
      cw = start_cw(buf, task), -- chains: the column j/k remember
      cost = 0,
      ntok = 0,
      nsum = 0,
      keys = "",
      focus = false,
    }
    s0.key = keyof(start, s0.row, s0.col, s0.cw)
    push(s0)

    local found
    for cost = 0, maxcost do
      local b = buckets[cost]
      if b then
        for _, k in ipairs(b) do
          local n = nodes[k]
          if n.cost == cost and is_goal(n) and (not found or better(n, found)) then
            found = n
          end
        end
        if found then
          break
        end
        for _, k in ipairs(b) do
          local n = nodes[k]
          if n.cost == cost and not n.expanded and not n.goal and n.cost + n.h <= best_goal then
            n.expanded = true
            expand(n)
          end
        end
      end
    end
    if not found then
      return nil
    end
    local toks = {}
    local n = found
    while n.parent do
      table.insert(toks, 1, n.tok)
      n = n.parent
    end
    return {
      cost = found.cost,
      keys = found.keys,
      display = keys.display(found.keys),
      tokens = toks,
      focus = found.focus,
    }
  end)
end

-- Up to two other solutions within par + slack: one without the intended
-- solution's main move, one without counts.
function M.alternatives(task, learned, best, opts)
  opts = opts or {}
  local slack = config.get().solver.alt_slack
  local out, seen = {}, { [best.keys] = true }
  local function try(banfn)
    local r = M.solve(task, learned, { focus = opts.focus, ban = banfn, max_cost = best.cost + slack })
    if r and not seen[r.keys] then
      seen[r.keys] = true
      out[#out + 1] = r
    end
  end
  local main
  for _, t in ipairs(best.tokens) do
    if moves.matches(t, opts.focus) then
      main = t
      break
    end
  end
  main = main or best.tokens[#best.tokens]
  if main then
    local banned = {}
    for f in pairs(main.fams) do
      if f ~= "count" then
        banned[f] = true
      end
    end
    try(function(t)
      for f in pairs(banned) do
        if t.fams[f] then
          return true
        end
      end
      return false
    end)
  end
  for _, t in ipairs(best.tokens) do
    if t.fams.count then
      try(function(x)
        return x.fams.count == true
      end)
      break
    end
  end
  return out
end

-- Replay tokens from a task's start; returns { lines, cursor, curswant }
-- afterwards. Chains use it to start each step where the intended path leaves
-- off, including the column j and k remember (after $, the line end).
function M.run(task, tokens)
  return with_scratch(function(buf, win)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, task.lines)
    restore({ row = task.cursor[1], col = task.cursor[2], cw = start_cw(buf, task) })
    for _, t in ipairs(tokens) do
      mark(buf, task, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      normal(t.keys)
    end
    return {
      lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
      cursor = vim.api.nvim_win_get_cursor(win),
      curswant = vim.fn.winsaveview().curswant,
    }
  end)
end

-- Replay a solution token by token in the scratch buffer; true if it reaches
-- the goal. Used by tests and as a safety check when generating rounds.
function M.check(task, tokens)
  return with_scratch(function(buf, win)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, task.lines)
    restore({ row = task.cursor[1], col = task.cursor[2], cw = start_cw(buf, task) })
    for _, t in ipairs(tokens) do
      mark(buf, task, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      normal(t.keys)
    end
    if task.kind == "edit" then
      return text.join(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) == text.join(task.goal_lines)
    end
    local c = vim.api.nvim_win_get_cursor(win)
    return c[1] == task.goal[1] and c[2] == task.goal[2]
  end)
end

return M
