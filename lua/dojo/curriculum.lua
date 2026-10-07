-- Worlds and stages in teaching order (SPEC.md §7, docs/decisions/0004).
local M = {}

M.worlds = {
  { name = "First steps", stages = { "s1_1", "s1_2", "s1_3", "s1_4" } },
  { name = "Words and lines", stages = { "s2_1", "s2_2", "s2_3", "s2_4" } },
  { name = "Operators", stages = { "s3_1", "s3_2", "s3_3" } },
  { name = "Find in the line", stages = { "s4_1", "s4_2", "s4_3" } },
}

-- the stage whose challenges start mixing in two-step rounds
M.twostep_from = "2.4"

M.order = {} -- stage ids in order
local by_id, index = {}, {}
for w, world in ipairs(M.worlds) do
  for _, mod in ipairs(world.stages) do
    local st = require("dojo.stages." .. mod)
    st.world = w
    by_id[st.id] = st
    M.order[#M.order + 1] = st.id
    index[st.id] = #M.order
  end
end

function M.get(id)
  return by_id[id]
end

function M.index(id)
  return index[id]
end

function M.next(id)
  return M.order[(index[id] or 0) + 1]
end

function M.prev(id)
  local i = index[id]
  return i and i > 1 and M.order[i - 1] or nil
end

-- stage ids before id
function M.before(id)
  local out = {}
  for i = 1, (index[id] or 1) - 1 do
    out[#out + 1] = M.order[i]
  end
  return out
end

-- set of move families known once stage id has been taught
function M.learned_through(id)
  local set = {}
  for i = 1, index[id] or 0 do
    for _, f in ipairs(by_id[M.order[i]].adds) do
      set[f] = true
    end
  end
  return set
end

function M.has_twostep(id)
  return index[id] >= index[M.twostep_from]
end

return M
