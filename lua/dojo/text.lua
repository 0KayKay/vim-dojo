-- Helpers on buffer text: joining, positions, and the diff region between a
-- round's start text and its goal.
local M = {}

function M.join(lines)
  return table.concat(lines, "\n")
end

function M.split(s)
  return vim.split(s, "\n", { plain = true })
end

function M.lcp(a, b)
  local n = math.min(#a, #b)
  local i = 0
  while i < n and a:byte(i + 1) == b:byte(i + 1) do
    i = i + 1
  end
  return i
end

function M.lcs(a, b)
  local la, lb = #a, #b
  local n = math.min(la, lb)
  local i = 0
  while i < n and a:byte(la - i) == b:byte(lb - i) do
    i = i + 1
  end
  return i
end

-- Kept prefix/suffix lengths between start text a and goal b, non-overlapping.
function M.kept(a, b)
  local p = M.lcp(a, b)
  local s = math.min(M.lcs(a, b), math.min(#a, #b) - p)
  return p, s
end

-- line start offsets (0-based) for a joined text
function M.line_starts(s)
  local starts = { 0 }
  local pos = 1
  while true do
    local nl = s:find("\n", pos, true)
    if not nl then
      break
    end
    starts[#starts + 1] = nl -- 0-based offset of the char after "\n"
    pos = nl + 1
  end
  return starts
end

-- (row 1-based, col 0-based) -> 0-based offset
function M.offset(starts, row, col)
  return (starts[row] or 0) + col
end

-- 0-based offset -> row (1-based), col (0-based)
function M.pos(starts, off)
  local row = 1
  for i = 2, #starts do
    if starts[i] <= off then
      row = i
    else
      break
    end
  end
  return row, off - starts[row]
end

-- Changed region in the start text: {srow, scol, erow, ecol} with the end
-- exclusive, rows 1-based and cols 0-based; plus the same for the goal text.
function M.regions(lines, goal_lines)
  local a, b = M.join(lines), M.join(goal_lines)
  local p, s = M.kept(a, b)
  local sa, sb = M.line_starts(a), M.line_starts(b)
  local r1, c1 = M.pos(sa, p)
  local r2, c2 = M.pos(sa, #a - s)
  local g1r, g1c = M.pos(sb, p)
  local g2r, g2c = M.pos(sb, #b - s)
  return { srow = r1, scol = c1, erow = r2, ecol = c2, empty = (#a - s) <= p },
    { srow = g1r, scol = g1c, erow = g2r, ecol = g2c, empty = (#b - s) <= p }
end

local function blank(c)
  return c == "" or c == " " or c == "\n"
end

local function wordchar(c)
  return c ~= "" and c:match("[%w_]") ~= nil
end

-- Kept prefix/suffix lengths as a person would mark the change (decision
-- 0016). A pure insertion or deletion can sit anywhere along a run of
-- repeated text with the same result; it is slid to a word boundary when
-- there is one ("tent " before "test", not "nt te"), preferring a span that
-- starts with a letter. Without one, it stays put, so a stray letter inside a
-- word stays marked as that letter. A replacement is widened to whole words.
function M.aligned(a, b)
  local p, s = M.kept(a, b)
  local da, db = #a - s - p, #b - s - p
  if da > 0 and db > 0 then
    while p > 0 and wordchar(a:sub(p, p)) and (wordchar(a:sub(p + 1, p + 1)) or wordchar(b:sub(p + 1, p + 1))) do
      p = p - 1
    end
    while s > 0 do
      local after = a:sub(#a - s + 1, #a - s + 1)
      local last_a, last_b = a:sub(#a - s, #a - s), b:sub(#b - s, #b - s)
      if wordchar(after) and (wordchar(last_a) or wordchar(last_b)) then
        s = s - 1
      else
        break
      end
    end
    return p, s
  end
  if da == 0 and db == 0 then
    return p, s
  end
  -- T: the text without the span; X: the span, inserted at p
  local T, X = (da == 0) and a or b, (da == 0) and b:sub(p + 1, p + db) or a:sub(p + 1, p + da)
  local function aligned_at(q, x)
    local left = q == 0 or blank(T:sub(q, q)) or blank(x:sub(1, 1))
    local right = q == #T or blank(T:sub(q + 1, q + 1)) or blank(x:sub(-1))
    return left and right
  end
  local cands = { { p, X } }
  local q, x = p, X
  while q > 0 and T:sub(q, q) == x:sub(-1) do -- slide left
    x = T:sub(q, q) .. x:sub(1, -2)
    q = q - 1
    cands[#cands + 1] = { q, x }
  end
  q, x = p, X
  while q < #T and T:sub(q + 1, q + 1) == x:sub(1, 1) do -- slide right
    x = x:sub(2) .. T:sub(q + 1, q + 1)
    q = q + 1
    cands[#cands + 1] = { q, x }
  end
  local best
  for _, c in ipairs(cands) do
    if aligned_at(c[1], c[2]) then
      if not blank(c[2]:sub(1, 1)) then
        best = c
        break
      end
      best = best or c
    end
  end
  best = best or cands[1]
  return best[1], #T - best[1]
end

-- Like regions(), with the span aligned to words (for the marks a player sees).
function M.aligned_regions(lines, goal_lines)
  local a, b = M.join(lines), M.join(goal_lines)
  local p, s = M.aligned(a, b)
  local sa, sb = M.line_starts(a), M.line_starts(b)
  local r1, c1 = M.pos(sa, p)
  local r2, c2 = M.pos(sa, #a - s)
  local g1r, g1c = M.pos(sb, p)
  local g2r, g2c = M.pos(sb, #b - s)
  return { srow = r1, scol = c1, erow = r2, ecol = c2, empty = (#a - s) <= p },
    { srow = g1r, scol = g1c, erow = g2r, ecol = g2c, empty = (#b - s) <= p },
    b:sub(p + 1, #b - s)
end

return M
