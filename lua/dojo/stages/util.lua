-- Small helpers shared by stage generators.
local U = {}

-- words as {s = first col, e = last col (0-based, inclusive), w = text}
function U.spans(line)
  local out = {}
  for s, w in line:gmatch("()(%S+)") do
    out[#out + 1] = { s = s - 1, e = s - 1 + #w - 1, w = w }
  end
  return out
end

function U.first_nonblank(line)
  return (line:find("%S") or 1) - 1
end

function U.copy(list)
  local out = {}
  for i, v in ipairs(list) do
    out[i] = v
  end
  return out
end

-- column where word i starts in a line built from words joined by " "
function U.start_of(ws, i)
  local col = 0
  for k = 1, i - 1 do
    col = col + #ws[k] + 1
  end
  return col
end

function U.clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

-- In challenges, sometimes start the cursor somewhere else on the row, so the
-- round needs a move first (that's where moves combine).
function U.maybe_wander(rng, ctx, col, line, chance)
  if ctx.mode == "challenge" and rng:chance(chance or 0.35) then
    return rng:int(0, #line - 1)
  end
  return col
end

-- is c punctuation (not a letter, digit or space)?
function U.is_punct(c)
  return c:match("[^%w%s]") ~= nil
end

return U
