-- Move families and the candidate keys the solver may try. A family is what a
-- stage teaches ("wb", "count", "d", ...). Every candidate carries the set of
-- families it uses, which drives tie-breaking, drill checks and alternatives.
local M = {}

M.labels = {
  hjkl = "h j k l",
  x = "x",
  ia = "i a",
  AI = "A I",
  wb = "w b",
  e = "e",
  line = "0 ^ $",
  count = "counts",
  d = "d",
  dd = "dd",
  c = "c",
  f = "f F",
  t = "t T",
}

-- order used when listing learned moves
M.order = { "hjkl", "x", "ia", "AI", "wb", "e", "line", "count", "d", "dd", "c", "f", "t" }

local function tok(keys, fams, extra)
  local set = {}
  for _, f in ipairs(fams) do
    set[f] = true
  end
  local t = { keys = keys, cost = #keys, fams = set }
  if extra then
    for k, v in pairs(extra) do
      t[k] = v
    end
  end
  return t
end
M.tok = tok

-- Counts: 2-9 where the count is easy to see (relative line numbers, word
-- starts), 2-4 for single characters, which nobody counts at a glance
-- (docs/decisions/0007-count-limits.md).
local counted = { "2", "3", "4", "5", "6", "7", "8", "9" }
local counted_chars = { "2", "3", "4" }

-- characters f/t may target on a line: every non-space byte, once
local function find_chars(line)
  local seen, out = {}, {}
  for i = 1, #line do
    local c = line:sub(i, i)
    if c ~= " " and not seen[c] then
      seen[c] = true
      out[#out + 1] = c
    end
  end
  return out
end

-- Motions available on a line. Each has keys, cost, fams; `rowlevel` marks
-- motions whose operator form acts on whole lines or line edges.
function M.motions(learned, line)
  local out = {}
  local function simple(k, fam, rowlevel)
    out[#out + 1] = tok(k, { fam }, { rowlevel = rowlevel })
    if learned.count then
      for _, n in ipairs((k == "h" or k == "l") and counted_chars or counted) do
        out[#out + 1] = tok(n .. k, { fam, "count" }, { rowlevel = rowlevel })
      end
    end
  end
  if learned.hjkl then
    simple("h", "hjkl")
    simple("j", "hjkl", true)
    simple("k", "hjkl", true)
    simple("l", "hjkl")
  end
  if learned.wb then
    simple("w", "wb")
    simple("b", "wb")
  end
  if learned.e then
    simple("e", "e")
  end
  if learned.line then
    out[#out + 1] = tok("0", { "line" }, { rowlevel = true })
    out[#out + 1] = tok("^", { "line" }, { rowlevel = true })
    out[#out + 1] = tok("$", { "line" }, { rowlevel = true })
  end
  if (learned.f or learned.t) and line then
    for _, c in ipairs(find_chars(line)) do
      if learned.f then
        out[#out + 1] = tok("f" .. c, { "f" })
        out[#out + 1] = tok("F" .. c, { "f" })
      end
      if learned.t then
        out[#out + 1] = tok("t" .. c, { "t" })
        out[#out + 1] = tok("T" .. c, { "t" })
      end
    end
  end
  return out
end

local function with(fams_set, extra)
  local list = {}
  for f in pairs(fams_set) do
    list[#list + 1] = f
  end
  for _, f in ipairs(extra) do
    list[#list + 1] = f
  end
  return list
end

-- Edits that change text directly (x, d{motion}, dd).
function M.edits(learned, motions)
  local out = {}
  if learned.x then
    out[#out + 1] = tok("x", { "x" })
    if learned.count then
      for _, n in ipairs(counted_chars) do
        out[#out + 1] = tok(n .. "x", { "x", "count" })
      end
    end
  end
  if learned.d then
    for _, m in ipairs(motions) do
      out[#out + 1] = tok("d" .. m.keys, with(m.fams, { "d" }), { rowlevel = m.rowlevel })
    end
  end
  if learned.dd then
    out[#out + 1] = tok("dd", { "dd" }, { rowlevel = true })
    if learned.count then
      for _, n in ipairs(counted) do
        out[#out + 1] = tok(n .. "dd", { "dd", "count" }, { rowlevel = true })
      end
    end
  end
  return out
end

-- Commands that end in Insert mode. The solver appends the text to type and
-- <Esc>, working the text out from the goal.
function M.finishers(learned, motions)
  local out = {}
  if learned.ia then
    out[#out + 1] = tok("i", { "ia" })
    out[#out + 1] = tok("a", { "ia" })
  end
  if learned.AI then
    out[#out + 1] = tok("A", { "AI" }, { rowlevel = true })
    out[#out + 1] = tok("I", { "AI" }, { rowlevel = true })
  end
  if learned.c then
    for _, m in ipairs(motions) do
      out[#out + 1] = tok("c" .. m.keys, with(m.fams, { "c" }), { rowlevel = m.rowlevel })
    end
  end
  return out
end

-- Does a candidate use the focus? focus = list of family sets, e.g.
-- { {"d","t"}, {"c","f"} }; a candidate matches when it has every family of
-- one set.
function M.matches(t, focus)
  if not focus then
    return false
  end
  for _, set in ipairs(focus) do
    local all = true
    for _, f in ipairs(set) do
      if not t.fams[f] then
        all = false
        break
      end
    end
    if all then
      return true
    end
  end
  return false
end

function M.learned_label(learned)
  local parts = {}
  for _, f in ipairs(M.order) do
    if learned[f] then
      parts[#parts + 1] = M.labels[f]
    end
  end
  return table.concat(parts, " · ")
end

return M
