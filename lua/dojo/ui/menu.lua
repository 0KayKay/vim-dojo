-- Stage menu (SPEC.md §8 Menu). Entries are stages and bosses, by key.
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local progress = require("dojo.progress")
local score = require("dojo.score")

local M = {}

local line_to_key, key_to_line = {}, {}
local mapped -- the buffer that has our keymaps (it can be wiped and recreated)
local last_key -- the entry last opened, to return the cursor to it

local STATUS = " <CR> play  d drill  c challenge  ? explainer  H habit mode  q quit"

local function notify(msg)
  vim.api.nvim_echo({ { msg, "DojoWarn" } }, false, {})
end

local function locked_msg(key)
  local st = curriculum.get(key)
  if st.is_boss then
    local first = curriculum.get(curriculum.world_first(st.world))
    return string.format("%s is locked: it opens together with %s.", st.id, first.id)
  end
  local prev = curriculum.get(curriculum.prev(key))
  return string.format("%s is locked: earn a star in %s first, or beat the World %d boss.", st.id, prev.id, st.world)
end

local function selected()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  return line_to_key[row]
end

local function step(dir)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local r = row + dir
  while r >= 1 and r <= vim.api.nvim_buf_line_count(0) do
    if line_to_key[r] then
      vim.api.nvim_win_set_cursor(0, { r, 0 })
      return
    end
    r = r + dir
  end
end

-- explainer first, then the drill, then challenges; bosses: explainer, boss
function M.continue(key)
  last_key = key
  if not progress.unlocked(key) then
    notify(locked_msg(key))
    return
  end
  local st = curriculum.get(key)
  local p = progress.stage(key)
  if not p.explainer_seen then
    require("dojo.ui.explainer").show(key)
  elseif st.is_boss then
    require("dojo.session").start(key, "boss")
  elseif not p.drill_done then
    require("dojo.session").start(key, "drill")
  else
    require("dojo.session").start(key, "challenge")
  end
end

local function with_selected(fn)
  return function()
    local key = selected()
    if not key then
      return
    end
    if not progress.unlocked(key) then
      notify(locked_msg(key))
      return
    end
    last_key = key
    fn(key, curriculum.get(key))
  end
end

local function map(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", function()
    local key = selected()
    if key then
      M.continue(key)
    end
  end, o)
  -- notices go out after the start: showing a screen clears the message line
  vim.keymap.set("n", "d", with_selected(function(key, st)
    require("dojo.session").start(key, st.is_boss and "boss" or "drill")
    if st.is_boss then
      notify("Bosses have no drill; the boss starts now.")
    end
  end), o)
  vim.keymap.set("n", "c", with_selected(function(key, st)
    if st.is_boss then
      require("dojo.session").start(key, "boss")
    elseif not progress.stage(key).drill_done then
      require("dojo.session").start(key, "drill")
      notify("Do the drill first; it starts now.")
    else
      require("dojo.session").start(key, "challenge")
    end
  end), o)
  vim.keymap.set("n", "?", with_selected(function(key)
    require("dojo.ui.explainer").show(key)
  end), o)
  vim.keymap.set("n", "H", function()
    progress.setting("habit", not progress.setting("habit"))
    M.show(selected())
  end, o)
  vim.keymap.set("n", "q", function()
    layout.close()
  end, o)
  for _, k in ipairs({ "j", "<Down>" }) do
    vim.keymap.set("n", k, function()
      step(1)
    end, o)
  end
  for _, k in ipairs({ "k", "<Up>" }) do
    vim.keymap.set("n", k, function()
      step(-1)
    end, o)
  end
  vim.keymap.set("n", "gg", function()
    vim.api.nvim_win_set_cursor(0, { key_to_line[curriculum.order[1]], 0 })
  end, o)
  vim.keymap.set("n", "G", function()
    vim.api.nvim_win_set_cursor(0, { key_to_line[curriculum.order[#curriculum.order]], 0 })
  end, o)
end

function M.remember(key)
  last_key = key
end

-- the entry to put the cursor on: the one after the furthest entry with a
-- star (after a boss, the next world), else the first unlocked stage without
-- a star
local function default_focus()
  local furthest
  for i, key in ipairs(curriculum.order) do
    if progress.stage(key).best_stars > 0 then
      furthest = i
    end
  end
  local after = furthest and curriculum.order[furthest + 1]
  if after and progress.unlocked(after) then
    return after
  end
  local last
  for _, key in ipairs(curriculum.order) do
    if progress.unlocked(key) and not curriculum.get(key).is_boss then
      last = key
      if progress.stage(key).best_stars == 0 then
        return key
      end
    end
  end
  return last
end

local function status_of(st)
  local p = progress.stage(st.key)
  if not progress.unlocked(st.key) then
    return { "locked", "DojoLocked" }
  end
  if p.best_stars > 0 then
    return { score.stars_text(p.best_stars), "DojoStar" }
  end
  if st.is_boss then
    -- beatable early: say so while the world's stages are not all passed
    local last_stage = curriculum.get(curriculum.prev(st.key))
    local done = progress.stage(last_stage.key).best_stars > 0
    return { score.stars_text(0) .. (done and "   new" or "   skip ahead"), "DojoStar" }
  end
  return { score.stars_text(0) .. "   new", "DojoStar" }
end

function M.show(focus)
  local buf, win = layout.show("menu", { status = STATUS })
  if mapped ~= buf then
    map(buf)
    mapped = buf
  end
  local total, max = progress.total_stars()
  local habit = progress.setting("habit") and "on" or "off"
  local right = string.format("%d / %d ★   habit mode: %s ", total, max, habit)
  local width = vim.api.nvim_win_get_width(win)
  local rows = {
    {
      { " VIM DOJO", "DojoTitle" },
      { string.rep(" ", math.max(1, width - 9 - render.width(right))) },
      { right, "DojoDim" },
    },
  }
  line_to_key, key_to_line = {}, {}
  for w, world in ipairs(curriculum.worlds) do
    rows[#rows + 1] = { { string.format(" World %d · %s", w, world.name), "DojoWorld" } }
    local keys = vim.list_extend(vim.deepcopy(world.stages), { world.boss })
    for _, key in ipairs(keys) do
      local st = curriculum.get(key)
      rows[#rows + 1] = {
        { "     " .. render.fit(st.id, 5) },
        { render.fit(st.title, 12), st.is_boss and "DojoWarn" or "DojoKey" },
        { render.fit(st.name, 22), "DojoDim" },
        status_of(st),
      }
      line_to_key[#rows] = key
      key_to_line[key] = #rows
    end
  end
  render.draw(buf, rows)
  local key = focus or last_key or default_focus()
  vim.api.nvim_win_set_cursor(win, { key_to_line[key] or 3, 0 })
end

return M
