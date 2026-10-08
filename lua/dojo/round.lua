-- One round in the play buffer: load the task, record typed keys, apply habit
-- mode, run the clock, and detect success (SPEC.md §5).
local text = require("dojo.text")
local keys = require("dojo.keys")
local solver = require("dojo.solver")
local config = require("dojo.config")

local M = {}

local ns = vim.api.nvim_create_namespace("dojo.round")
local key_ns = vim.api.nvim_create_namespace("dojo.round.keys")
local group = vim.api.nvim_create_augroup("dojo.round", { clear = true })

local active

M.clock = function()
  return vim.uv.hrtime() / 1e6
end

function M.prepare_buffer(buf)
  solver.normalize_buffer(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].undolevels = 1000
  vim.keymap.set("n", "<Tab>", function()
    M.hint()
  end, { buffer = buf, nowait = true, desc = "Vim Dojo: show the intended solution" })
end

-- Highlights: target cell for move rounds; for edit rounds the span to change
-- and a ghost goal line under the changed lines when there is text to type.
local function decorate(buf, task)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if task.kind == "move" then
    local r, c = task.goal[1], task.goal[2]
    vim.api.nvim_buf_set_extmark(buf, ns, r - 1, c, { end_col = c + 1, hl_group = "DojoTarget", priority = 200 })
    return
  end
  local from, to = text.regions(task.lines, task.goal_lines)
  if not from.empty then
    vim.api.nvim_buf_set_extmark(buf, ns, from.srow - 1, from.scol, {
      end_row = from.erow - 1,
      end_col = from.ecol,
      hl_group = "DojoDelete",
      hl_eol = from.ecol == 0 and from.erow > from.srow,
      priority = 200,
    })
  end
  if not to.empty then
    -- ghost of each goal line that contains new text, under the last changed line
    local virt = {}
    for gr = to.srow, to.erow do
      local gl = task.goal_lines[gr] or ""
      local s = gr == to.srow and to.scol or 0
      local e = gr == to.erow and to.ecol or #gl
      virt[#virt + 1] = {
        { gl:sub(1, s), "DojoGhost" },
        { gl:sub(s + 1, e), "DojoGoal" },
        { gl:sub(e + 1), "DojoGhost" },
      }
    end
    local anchor = math.min(from.erow, #task.lines) - 1
    if from.ecol == 0 and from.erow > from.srow then
      anchor = from.erow - 2
    end
    vim.api.nvim_buf_set_extmark(buf, ns, math.max(anchor, 0), 0, { virt_lines = virt })
  end
end

function M.load(buf, win, task)
  vim.bo[buf].modifiable = true
  local ul = vim.bo[buf].undolevels
  vim.bo[buf].undolevels = -1 -- a change with undolevels -1 clears undo history
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, task.lines)
  vim.bo[buf].undolevels = ul
  vim.bo[buf].modifiable = task.kind == "edit"
  vim.bo[buf].modified = false
  decorate(buf, task)
  vim.api.nvim_win_set_cursor(win, task.cursor)
  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview({ topline = 1, leftcol = 0 })
  end)
end

function M.clear(buf)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

local function at_goal(a)
  local task = a.o.task
  if task.kind == "move" then
    local c = vim.api.nvim_win_get_cursor(a.o.win)
    return c[1] == task.goal[1] and c[2] == task.goal[2]
  end
  return text.join(vim.api.nvim_buf_get_lines(a.o.buf, 0, -1, false)) == text.join(task.goal_lines)
end

local function cleanup(a)
  if a.timer then
    a.timer:stop()
    a.timer:close()
    a.timer = nil
  end
  vim.on_key(nil, key_ns)
  vim.api.nvim_clear_autocmds({ group = group })
end

local function finish(solved)
  local a = active
  if not a or a.done then
    return
  end
  a.done = true
  active = nil
  cleanup(a)
  -- leave Insert/operator-pending mode, but only in the game's own window
  if vim.api.nvim_get_current_win() == a.o.win and vim.api.nvim_get_mode().mode ~= "n" then
    vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-n>"), "n", false)
  end
  if vim.api.nvim_buf_is_valid(a.o.buf) then
    vim.bo[a.o.buf].modifiable = false
  end
  local result = {
    solved = solved,
    count = a.count,
    keys = a.keys,
    time_ms = M.clock() - a.start,
    hint = a.hint,
    blocked = a.blocked,
  }
  vim.schedule(function()
    a.o.on_done(result)
  end)
end

local function check()
  local a = active
  if not a or a.done then
    return
  end
  if vim.api.nvim_get_current_win() ~= a.o.win then
    return
  end
  local m = vim.api.nvim_get_mode()
  if m.mode ~= "n" or m.blocking then
    return
  end
  if at_goal(a) then
    finish(true)
  end
end

local habit_set = {}
local function habit_blocks(a, typed, now)
  local h = config.get().habit
  if not habit_set[h.keys] then
    local s = {}
    for c in h.keys:gmatch(".") do
      s[c] = true
    end
    habit_set[h.keys] = s
  end
  if not habit_set[h.keys][typed] then
    a.prev_typed = typed
    return false
  end
  -- a press right after a count digit starts fresh: 3j is the good habit
  if a.prev_typed and a.prev_typed:match("^[1-9]$") then
    a.runs[typed] = nil
  end
  a.prev_typed = typed
  local run = a.runs[typed]
  if run and now - run.t0 < h.window_ms then
    run.n = run.n + 1
  else
    run = { t0 = now, n = 1 }
    a.runs[typed] = run
  end
  return run.n > h.grace
end

-- keys whose next key is an argument (a character or register), not a command
local takes_arg = { f = true, F = true, t = true, T = true, r = true, m = true, q = true, ['"'] = true, ["'"] = true, ["`"] = true }

local function is_mouse(typed)
  local t = vim.fn.keytrans(typed)
  return t:find("Mouse", 1, true) or t:find("Scroll", 1, true) or t:find("Release", 1, true) or t:find("Drag", 1, true)
end

local function on_key(_, typed)
  local a = active
  if not a or a.done or typed == nil or typed == "" then
    return
  end
  if vim.api.nvim_get_current_win() ~= a.o.win then
    return
  end
  if is_mouse(typed) then
    return "" -- keyboard only (SPEC §5): clicks would beat par
  end
  local mode = vim.api.nvim_get_mode().mode
  if a.arg_next then
    -- the character after f/t/r/…: record it, but it is not a command
    a.arg_next = false
    a.prev_typed = nil
    a.count = a.count + 1
    a.keys[#a.keys + 1] = { k = keys.typed(typed), mode = "arg" }
    vim.schedule(check)
    return
  end
  if mode == "n" and (typed == "\t" or typed == "\27") then
    return -- hint key, or <Esc> that changes nothing: free
  end
  if (mode == "n" or mode:sub(1, 2) == "no") and takes_arg[typed] then
    a.arg_next = true
  end
  if a.o.habit and mode == "n" and habit_blocks(a, typed, M.clock()) then
    a.blocked = a.blocked + 1
    if a.o.on_blocked then
      vim.schedule(function()
        a.o.on_blocked(typed)
      end)
    end
    return ""
  end
  if not a.o.habit then
    a.prev_typed = typed
  end
  a.count = a.count + 1
  a.keys[#a.keys + 1] = { k = keys.typed(typed), mode = mode }
  vim.schedule(check)
end

-- o: { buf, win, task, limit_ms (nil = untimed), habit (bool),
--      on_done(result), on_tick(elapsed_ms), on_hint(), on_blocked(key) }
function M.start(o)
  M.abort()
  M.load(o.buf, o.win, o.task)
  local a = { o = o, keys = {}, count = 0, hint = false, blocked = 0, runs = {}, start = M.clock() }
  active = a
  vim.on_key(on_key, key_ns)
  vim.api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "ModeChanged" }, {
    group = group,
    callback = function()
      vim.schedule(check)
    end,
  })
  a.timer = vim.uv.new_timer()
  a.timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      if active ~= a or a.done then
        return
      end
      local elapsed = M.clock() - a.start
      if o.on_tick then
        o.on_tick(elapsed)
      end
      if o.limit_ms and elapsed >= o.limit_ms then
        finish(false)
      end
    end)
  )
end

function M.hint()
  local a = active
  if a and not a.done then
    a.hint = true
    if a.o.on_hint then
      a.o.on_hint()
    end
  end
end

-- stop without reporting a result
function M.abort()
  local a = active
  if a then
    a.done = true
    active = nil
    cleanup(a)
  end
end

function M.is_active()
  return active ~= nil
end

-- for tests: force a timeout check now
function M._tick()
  local a = active
  if a and a.o.limit_ms and M.clock() - a.start >= a.o.limit_ms then
    finish(false)
  end
end

M.ns = ns

return M
