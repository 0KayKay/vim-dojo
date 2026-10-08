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

return M
