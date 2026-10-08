-- Headless test runner (no framework, see docs/decisions/0001).
-- Usage: nvim --headless -l tests/run.lua [filter]
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.cmd.runtime("plugin/dojo.lua") -- defines :Dojo, as a plugin manager would
vim.o.showmode = false -- keep "-- INSERT --" out of the test output
package.path = root .. "/tests/?.lua;" .. package.path

-- keep test data out of the real data dir
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
require("dojo.config").setup({ data_dir = tmp })

local filter = arg and arg[1]
local files = vim.fn.glob(root .. "/tests/test_*.lua", false, true)
table.sort(files)

local passed, failed, started = 0, {}, vim.uv.hrtime()
for _, file in ipairs(files) do
  local name = vim.fn.fnamemodify(file, ":t:r")
  if not filter or name:find(filter, 1, true) then
    local ok, suite = pcall(dofile, file)
    if not ok then
      failed[#failed + 1] = name .. ": failed to load\n" .. tostring(suite)
    else
      for _, case in ipairs(suite) do
        local t0 = vim.uv.hrtime()
        local ok2, err = xpcall(case[2], debug.traceback)
        local ms = (vim.uv.hrtime() - t0) / 1e6
        if ok2 then
          passed = passed + 1
          io.stdout:write(string.format("  ok   %-14s %s (%.0f ms)\n", name, case[1], ms))
        else
          failed[#failed + 1] = name .. " › " .. case[1] .. "\n" .. tostring(err)
          io.stdout:write(string.format("  FAIL %-14s %s\n", name, case[1]))
        end
        -- tidy up windows/tabs a test may have left behind
        pcall(vim.cmd, "silent! tabonly!")
        pcall(vim.cmd, "silent! only!")
      end
    end
  end
end

io.stdout:write(string.format("\n%d passed, %d failed in %.1f s\n", passed, #failed, (vim.uv.hrtime() - started) / 1e9))
for _, f in ipairs(failed) do
  io.stdout:write("\n" .. f .. "\n")
end
vim.fn.delete(tmp, "rf")
os.exit(#failed == 0 and 0 or 1)
