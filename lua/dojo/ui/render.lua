-- Draw rows of highlighted segments into a scratch buffer.
local M = {}

local ns = vim.api.nvim_create_namespace("dojo.render")

-- rows: list of strings, or lists of segments { text, hl_group? }
function M.draw(buf, rows)
  local lines, marks = {}, {}
  for i, row in ipairs(rows) do
    if type(row) == "string" then
      lines[i] = row
    else
      local s = ""
      for _, seg in ipairs(row) do
        local t = seg[1] or ""
        if seg[2] and #t > 0 then
          marks[#marks + 1] = { i - 1, #s, #s + #t, seg[2] }
        end
        s = s .. t
      end
      lines[i] = s
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
end

-- display width of a string
function M.width(s)
  return vim.fn.strdisplaywidth(s)
end

-- pad or cut s to exactly w display cells
function M.fit(s, w)
  local dw = M.width(s)
  if dw <= w then
    return s .. string.rep(" ", w - dw)
  end
  local out = vim.fn.strcharpart(s, 0, math.max(0, w - 1))
  while M.width(out) > w - 1 do
    out = vim.fn.strcharpart(out, 0, vim.fn.strchars(out) - 1)
  end
  return out .. "…" .. string.rep(" ", w - 1 - M.width(out))
end

-- greedy word wrap
function M.wrap(s, w)
  local out, line = {}, ""
  for word in s:gmatch("%S+") do
    if line == "" then
      line = word
    elseif M.width(line) + 1 + M.width(word) <= w then
      line = line .. " " .. word
    else
      out[#out + 1] = line
      line = word
    end
  end
  if line ~= "" then
    out[#out + 1] = line
  end
  return out
end

-- "text [x] more" -> segments with the bracketed char highlighted as a cursor
function M.cursor_line(s, base_hl, cursor_hl)
  local segs = {}
  local a, b, inner = s:find("%[(.-)%]")
  if not a then
    return { { s, base_hl } }
  end
  segs[#segs + 1] = { s:sub(1, a - 1), base_hl }
  segs[#segs + 1] = { inner, cursor_hl }
  segs[#segs + 1] = { s:sub(b + 1), base_hl }
  return segs
end

return M
