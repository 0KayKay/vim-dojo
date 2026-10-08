-- Turning keys into readable Vim notation.
local M = {}

local special = {
  ["\27"] = "<Esc>",
  ["\r"] = "<CR>",
  ["\n"] = "<NL>",
  ["\t"] = "<Tab>",
  [" "] = "␣",
}

-- Raw solver keys (plain bytes) -> display string, e.g. "cwfoo\27" -> "cwfoo<Esc>"
function M.display(raw)
  return (raw:gsub("[%z\1-\31 ]", function(c)
    return special[c] or ("<C-" .. string.char(c:byte() + 64) .. ">")
  end))
end

-- One typed key as received by vim.on_key -> display string
function M.typed(key)
  local t = vim.fn.keytrans(key)
  if t == "<Space>" then
    return "␣"
  elseif t == "<lt>" then
    return "<"
  end
  return t
end

-- number of keys in raw solver keys (all ASCII, one byte per key)
function M.cost(raw)
  return #raw
end

return M
