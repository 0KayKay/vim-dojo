-- Worlds, stages and bosses in teaching order (SPEC.md §7, decisions 0010 and
-- 0012). Stages are identified by stable keys; display ids like "2.1" or "2.B"
-- come from the order and are never saved.
local M = {}

M.worlds = {
  { name = "First steps", stages = { "hjkl", "counts", "x", "insert", "append" }, boss = "boss_1" },
  { name = "Words and lines", stages = { "word", "word_end", "line_edges" }, boss = "boss_2" },
  { name = "Operators", stages = { "delete", "change", "lines" }, boss = "boss_3" },
  { name = "Find in the line", stages = { "find", "till" }, boss = "boss_4" },
}

M.order = {} -- keys of all entries (stages and bosses) in order
local by_key, index = {}, {}

local function add(st, w, id)
  st.world = w
  st.id = id
  by_key[st.key] = st
  M.order[#M.order + 1] = st.key
  index[st.key] = #M.order
end

for w, world in ipairs(M.worlds) do
  for i, key in ipairs(world.stages) do
    local st = require("dojo.stages." .. key)
    assert(st.key == key, "stage file " .. key .. " has key " .. tostring(st.key))
    add(st, w, w .. "." .. i)
  end
  local next_world = M.worlds[w + 1]
  add(require("dojo.stages.boss").make(w, world, next_world and next_world.name), w, w .. ".B")
end

function M.get(key)
  return by_key[key]
end

function M.index(key)
  return index[key]
end

function M.next(key)
  return M.order[(index[key] or 0) + 1]
end

function M.prev(key)
  local i = index[key]
  return i and i > 1 and M.order[i - 1] or nil
end

-- set of move families known once entry `key` is reached (a boss knows its
-- whole world, even when played early to skip ahead)
function M.learned_through(key)
  local set = {}
  for i = 1, index[key] or 0 do
    for _, f in ipairs(by_key[M.order[i]].adds) do
      set[f] = true
    end
  end
  return set
end

-- set of move families taught in world w
function M.world_families(w)
  local set = {}
  for _, key in ipairs(M.worlds[w].stages) do
    for _, f in ipairs(by_key[key].adds) do
      set[f] = true
    end
  end
  return set
end

function M.world_first(w)
  return M.worlds[w].stages[1]
end

function M.world_boss(w)
  return M.worlds[w].boss
end

-- the stage that teaches a move family
function M.stage_for_family(f)
  for _, key in ipairs(M.order) do
    if vim.tbl_contains(by_key[key].adds, f) then
      return by_key[key]
    end
  end
end

-- non-boss stages up to and including `key`, optionally only from world w
function M.stages_through(key, w)
  local out = {}
  for i = 1, index[key] or 0 do
    local st = by_key[M.order[i]]
    if not st.is_boss and (not w or st.world == w) then
      out[#out + 1] = st.key
    end
  end
  return out
end

-- can a stage's rounds combine its move with another move family?
function M.can_combine(key)
  local st = by_key[key]
  local focus = require("dojo.moves").focus_set(st.focus)
  for f in pairs(M.learned_through(key)) do
    if f ~= "count" and not focus[f] then
      return true
    end
  end
  return false
end

return M
