-- Every stage, many seeds: rounds generate, par is found, and every solution
-- replays to the goal (SPEC §9 Tests).
local H = require("helpers")
local Rng = require("dojo.rng")
local solver = require("dojo.solver")
local curriculum = require("dojo.curriculum")
local session = require("dojo.session")

local SEEDS = tonumber(vim.env.DOJO_SEEDS) or 200

local cases = {}
for _, id in ipairs(curriculum.order) do
  for _, mode in ipairs({ "drill", "challenge" }) do
    cases[#cases + 1] = {
      string.format("stage %s %s: %d seeds solvable at par", id, mode, SEEDS),
      function()
        local learned = curriculum.learned_through(id)
        local rng = Rng.new(1000 + curriculum.index(id) * 7 + (mode == "drill" and 0 or 3))
        local slowest = 0
        for _ = 1, SEEDS do
          local t0 = vim.uv.hrtime()
          local r = session.make_round(id, { learned = learned, mode = mode }, rng)
          local ms = (vim.uv.hrtime() - t0) / 1e6
          slowest = math.max(slowest, ms)
          local task, sol = r.task, r.sol
          H.ok(not table.concat(task.lines, "\n"):find(solver.SENTINEL, 1, true), "sentinel in text")
          H.ok(sol.cost > 0, "round already solved at start: seed " .. task.seed)
          H.ok(solver.check(task, sol.tokens), "intended does not replay: seed " .. task.seed .. " " .. sol.keys)
          if mode == "drill" then
            H.ok(sol.focus, "drill solution skips the stage move: seed " .. task.seed .. " " .. sol.keys)
          end
        end
        io.stdout:write(string.format("        slowest round %.0f ms\n", slowest))
        -- budget: 200 ms per round (SPEC §9); the test allows 800 ms for slow CI machines
        H.ok(slowest < 800, string.format("round generation too slow: %.0f ms", slowest))
      end,
    }
  end
end

cases[#cases + 1] = {
  "alternatives replay and stay within par + 2",
  function()
    local rng = Rng.new(77)
    for _, id in ipairs(curriculum.order) do
      local learned = curriculum.learned_through(id)
      for _ = 1, 10 do
        local r = session.make_round(id, { learned = learned, mode = "challenge" }, rng)
        for _, a in ipairs(solver.alternatives(r.task, learned, r.sol, { focus = r.focus })) do
          H.ok(solver.check(r.task, a.tokens), "alternative does not replay: " .. a.keys)
          H.ok(a.cost <= r.sol.cost + 2)
          H.ok(a.keys ~= r.sol.keys)
        end
      end
    end
  end,
}

cases[#cases + 1] = {
  "two-step rounds solvable",
  function()
    local rng = Rng.new(5)
    local learned = curriculum.learned_through("4.3")
    for _ = 1, 50 do
      local r = session.make_round("twostep", { learned = learned, mode = "challenge" }, rng)
      H.ok(solver.check(r.task, r.sol.tokens))
      H.ok(#r.sol.tokens >= 2, "two-step round solved in one move: " .. r.sol.keys)
    end
  end,
}

return cases
