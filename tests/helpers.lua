local H = {}

function H.eq(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

function H.ok(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

function H.learned(list)
  local s = {}
  for _, f in ipairs(list) do
    s[f] = true
  end
  return s
end

-- Wait for vim.schedule'd work and timers to run.
function H.settle(ms)
  vim.wait(ms or 20, function()
    return false
  end)
end

-- Feed keys as if typed and let Neovim process them.
function H.type(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
  H.settle(5)
end

return H
