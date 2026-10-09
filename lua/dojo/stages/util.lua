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

-- is c punctuation (not a letter, digit or space)?
function U.is_punct(c)
  return c:match("[^%w%s]") ~= nil
end

-- An edit "up to a punctuation mark" on a code-like line, for operators with
-- f/t (SPEC §7 World 4). kinds: any of "dt", "df", "ct".
function U.operator_to_punct(rng, kinds)
  local words = require("dojo.words")
  local L = words.code_line(rng)
  local sp = U.spans(L)
  for _ = 1, 60 do
    local p = rng:int(0, #L - 1)
    local ch = L:sub(p + 1, p + 1)
    local starts = {}
    for _, s in ipairs(sp) do
      if s.s <= p - 4 and s.s >= p - 18 then
        starts[#starts + 1] = s.s
      end
    end
    if U.is_punct(ch) and #starts > 0 then
      local col = rng:pick(starts)
      if not L:sub(col + 2, p):find(ch, 1, true) then
        local kind = rng:pick(kinds)
        -- f takes the mark itself, t stops before it
        local keep = (kind == "df" or kind == "cf") and p + 2 or p + 1
        if kind == "dt" then
          return { kind = "edit", lines = { L }, cursor = { 1, col }, goal_lines = { L:sub(1, col) .. L:sub(p + 1) }, prompt = "Delete the struck-through text" }
        elseif kind == "df" then
          return { kind = "edit", lines = { L }, cursor = { 1, col }, goal_lines = { L:sub(1, col) .. L:sub(p + 2) }, prompt = "Delete the struck-through text" }
        else
          local new = words.pick(rng, 1, { max_len = 5 })[1]
          if new:sub(1, 1) ~= L:sub(col + 1, col + 1) then
            return {
              kind = "edit",
              lines = { L },
              cursor = { 1, col },
              goal_lines = { L:sub(1, col) .. new .. L:sub(keep) },
              prompt = "Replace the struck-through text with the green text",
            }
          end
        end
      end
    end
  end
end

return U
