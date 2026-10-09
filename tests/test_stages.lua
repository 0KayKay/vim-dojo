-- Every stage and boss, many seeds: rounds generate, par is found, every
-- solution replays to the goal, and every round meets its requirement
-- (SPEC §5 and §9 Tests, decisions 0008 and 0009).
local H = require("helpers")
local Rng = require("dojo.rng")
local solver = require("dojo.solver")
local curriculum = require("dojo.curriculum")
local session = require("dojo.session")
local moves = require("dojo.moves")
local compose = require("dojo.compose")

local SEEDS = tonumber(vim.env.DOJO_SEEDS) or 200
-- budget: 500 ms per round (SPEC §9); the tests allow 800 ms, per step in
-- chains, for slow CI machines
local BUDGET_MS = 800

local function ctx(key, mode)
  local st = curriculum.get(key)
  return { learned = curriculum.learned_through(key), mode = mode, key = key, world = st.world }
end

-- world: the round's world; World 1 allows 4 presses of h j k l in all
local function common(r, what, world)
  local task, sol = r.task, r.sol
  H.ok(not table.concat(task.lines, "\n"):find(solver.SENTINEL, 1, true), "sentinel in text: " .. what)
  H.ok(sol.cost > 0, "round already solved at start: " .. what)
  for _, part in ipairs(task.steps or { r }) do -- chains: per step
    local why = session.unnatural(part.sol, world == 1 and 4 or nil)
    H.ok(not why, string.format("unnatural par (%s): %s %s", tostring(why), what, part.sol.display))
  end
end

local function uses_world(concepts, w)
  for f in pairs(curriculum.world_families(w)) do
    if concepts[f] then
      return true
    end
  end
  return false
end

local cases = {}

for _, key in ipairs(curriculum.order) do
  local st = curriculum.get(key)
  if not st.is_boss then
    local focus = moves.focus_set(st.focus)
    local variants = curriculum.can_combine(key) and { "basic", "combined" } or { "basic" }
    for _, mode in ipairs({ "drill", "challenge" }) do
      for _, variant in ipairs(variants) do
        cases[#cases + 1] = {
          string.format("stage %s %s %s %s: %d seeds", st.id, key, mode, variant, SEEDS),
          function()
            local c = ctx(key, mode)
            local rng = Rng.new(1000 + curriculum.index(key) * 7 + (mode == "drill" and 0 or 3))
            local slowest = 0
            for _ = 1, SEEDS do
              local t0 = vim.uv.hrtime()
              local r = session.make_round({ key = key, variant = variant }, c, rng)
              slowest = math.max(slowest, (vim.uv.hrtime() - t0) / 1e6)
              local what = string.format("seed %d %s", r.task.seed, r.sol.keys)
              common(r, what, st.world)
              H.ok(solver.check(r.task, r.sol.tokens), "intended does not replay: " .. what)
              if st.world == 1 then
                H.ok(not r.concepts.count, "World 1 has no counts: " .. what)
              end
              -- every round needs the stage's move (decision 0008)
              H.ok(r.sol.focus, "solution skips the stage move: " .. what)
              if variant == "combined" then
                local others = moves.other_moves(r.concepts, focus)
                H.ok(#others >= 1, "combined round uses no other move: " .. what)
              end
            end
            io.stdout:write(string.format("        slowest round %.0f ms\n", slowest))
            H.ok(slowest < BUDGET_MS, string.format("round generation too slow: %.0f ms", slowest))
          end,
        }
      end
    end
  end
end

-- bosses: mixed rounds and chains from the world's stages
for w = 1, #curriculum.worlds do
  local key = curriculum.world_boss(w)
  local n = math.max(10, math.floor(SEEDS / 4))
  cases[#cases + 1] = {
    string.format("boss %d.B mixed: %d seeds use the world and two moves", w, n),
    function()
      local c = ctx(key, "boss")
      local rng = Rng.new(500 + w)
      local slowest = 0
      for _ = 1, n do
        local t0 = vim.uv.hrtime()
        local r = session.make_round({ variant = "mixed" }, c, rng)
        slowest = math.max(slowest, (vim.uv.hrtime() - t0) / 1e6)
        local what = string.format("seed %d %s", r.task.seed, r.sol.keys)
        common(r, what, w)
        H.ok(solver.check(r.task, r.sol.tokens), "does not replay: " .. what)
        H.ok(uses_world(r.concepts, w), "no move from this world: " .. what)
        H.ok(#moves.other_moves(r.concepts) >= 2, "fewer than two moves: " .. what)
      end
      io.stdout:write(string.format("        slowest round %.0f ms\n", slowest))
      H.ok(slowest < BUDGET_MS, string.format("round generation too slow: %.0f ms", slowest))
    end,
  }
  for _, steps in ipairs({ 2, 3 }) do
    cases[#cases + 1] = {
      string.format("boss %d.B %d-step chains: %d seeds replay step by step", w, steps, n),
      function()
        local c = ctx(key, "boss")
        local rng = Rng.new(700 + w * 10 + steps)
        local slowest = 0
        for _ = 1, n do
          local t0 = vim.uv.hrtime()
          local r = session.make_round({ variant = "chain", steps = steps }, c, rng)
          slowest = math.max(slowest, (vim.uv.hrtime() - t0) / 1e6)
          local task = r.task
          local what = string.format("seed %d %s", task.seed, r.sol.display)
          common(r, what, w)
          H.eq(#task.steps, steps, what)
          H.ok(uses_world(r.concepts, w), "no move from this world: " .. what)
          -- replay each step's intended keys from where the last one ended
          local state = { lines = task.lines, cursor = task.cursor }
          local par = 0
          for i, step in ipairs(task.steps) do
            local sub = compose.step_task(step, state.lines, state.cursor, state.curswant)
            H.ok(solver.check(sub, step.sol.tokens), string.format("step %d does not replay: %s", i, what))
            par = par + step.sol.cost
            state = solver.run(sub, step.sol.tokens)
          end
          H.eq(par, r.sol.cost, "chain par is the sum of the steps: " .. what)
        end
        io.stdout:write(string.format("        slowest round %.0f ms\n", slowest))
        H.ok(slowest < BUDGET_MS * steps, string.format("chain generation too slow: %.0f ms", slowest))
      end,
    }
  end
end

cases[#cases + 1] = {
  "plans: drills basics first, challenges all new-move, bosses end with chains",
  function()
    local cfg = require("dojo.config").get()
    local rng = Rng.new(3)
    local d = session.plan("word", "drill", rng)
    H.eq(#d, cfg.drill_basic_rounds + cfg.drill_combined_rounds)
    H.eq(d[1].variant, "basic")
    H.eq(d[#d].variant, "combined")
    local c = session.plan("word", "challenge", rng)
    H.eq(#c, cfg.challenge_rounds)
    local nc = 0
    for _, s in ipairs(c) do
      H.eq(s.key, "word")
      nc = nc + (s.variant == "combined" and 1 or 0)
    end
    H.eq(nc, cfg.challenge_combined_rounds)
    -- the first stage has nothing to combine with
    for _, s in ipairs(session.plan("hjkl", "challenge", rng)) do
      H.eq(s.variant, "basic")
    end
    local b = session.plan("boss_2", "boss", rng)
    H.eq(#b, cfg.boss_mixed_rounds + #cfg.boss_chains)
    H.eq(b[1].variant, "mixed")
    H.eq(b[#b].variant, "chain")
    -- mixed rounds take turns among the world's stages
    local seen = {}
    for _, spec in ipairs(b) do
      if spec.variant == "mixed" then
        seen[spec.key] = (seen[spec.key] or 0) + 1
      end
    end
    -- four stages, six turns: each one once or twice
    for _, k in ipairs({ "counts", "word", "word_end", "line_edges" }) do
      H.ok(seen[k] == 1 or seen[k] == 2, k .. " " .. tostring(seen[k]))
    end
    -- in World 1 only the editing stages can mix two moves
    seen = {}
    for _, spec in ipairs(session.plan("boss_1", "boss", rng)) do
      if spec.variant == "mixed" then
        seen[spec.key] = (seen[spec.key] or 0) + 1
      end
    end
    H.eq(seen, { x = 2, insert = 2, append = 2 })
    -- World 1's first stage can't mix two moves on its own: it falls back
    local c1 = ctx("boss_1", "boss")
    for _ = 1, 5 do
      local r = session.make_round({ key = "hjkl", variant = "mixed" }, c1, rng)
      H.ok(#moves.other_moves(r.concepts) >= 2, r.sol.keys)
    end
  end,
}

cases[#cases + 1] = {
  "boss mixed rounds as planned: each turn uses its stage's move",
  function()
    for w = 1, #curriculum.worlds do
      local key = curriculum.world_boss(w)
      local c = ctx(key, "boss")
      local rng = Rng.new(900 + w)
      for _ = 1, 3 do
        for _, spec in ipairs(session.plan(key, "boss", rng)) do
          if spec.variant == "mixed" then
            local r = session.make_round(spec, c, rng)
            local what = string.format("%s seed %d %s", spec.key, r.task.seed, r.sol.keys)
            H.ok(r.sol.focus, "the turn's move is missing: " .. what)
            H.ok(uses_world(r.concepts, w), "no move from this world: " .. what)
            H.ok(#moves.other_moves(r.concepts) >= 2, "fewer than two moves: " .. what)
          end
        end
      end
    end
  end,
}

cases[#cases + 1] = {
  "alternatives replay and stay within par + 2",
  function()
    local rng = Rng.new(77)
    for _, key in ipairs(curriculum.order) do
      local st = curriculum.get(key)
      if not st.is_boss then
        local c = ctx(key, "challenge")
        for _ = 1, 10 do
          local r = session.make_round({ key = key, variant = "basic" }, c, rng)
          for _, a in ipairs(solver.alternatives(r.task, c.learned, r.sol, { focus = r.focus })) do
            H.ok(solver.check(r.task, a.tokens), "alternative does not replay: " .. a.keys)
            H.ok(a.cost <= r.sol.cost + 2)
            H.ok(a.keys ~= r.sol.keys)
          end
        end
      end
    end
  end,
}

cases[#cases + 1] = {
  "unnatural pars are spotted (SPEC §7)",
  function()
    local function sol(...)
      local t = {}
      for _, k in ipairs({ ... }) do
        t[#t + 1] = { keys = k }
      end
      return { tokens = t }
    end
    H.ok(session.unnatural(sol("l", "l", "l", "l")), "four cells with l")
    H.ok(session.unnatural(sol("l", "j", "h", "x", "h", "l")), "four h/l presses in all")
    H.ok(not session.unnatural(sol("j", "l", "l", "l", "x")), "three cells and a line")
    H.ok(session.unnatural(sol("k", "k", "k", "k")), "four lines with k")
    H.ok(session.unnatural(sol("5w")), "five words")
    H.ok(session.unnatural(sol("d6b")), "six words back, with d")
    H.ok(not session.unnatural(sol("8j", "4w")), "lines by count, four words")
    H.ok(session.unnatural(sol("4j", "4j", "x", "4j")), "the same counted move three times")
    H.ok(not session.unnatural(sol("j", "j", "l", "l", "x"), 4), "four presses in World 1")
    H.ok(session.unnatural(sol("j", "j", "l", "l", "l", "x"), 4), "five presses in World 1")
  end,
}

cases[#cases + 1] = {
  "alternatives that habit mode would block are spotted",
  function()
    local function sol(...)
      local t = {}
      for _, k in ipairs({ ... }) do
        t[#t + 1] = { keys = k }
      end
      return { tokens = t }
    end
    H.ok(session.habit_breaking(sol("k", "k", "k", "k", "l", "a␣bear<Esc>")))
    H.ok(not session.habit_breaking(sol("k", "k", "k", "l", "a␣bear<Esc>")), "three presses are fine")
    H.ok(not session.habit_breaking(sol("3k", "3k", "3k")), "counted moves are the good habit")
    H.ok(not session.habit_breaking(sol("x", "x", "x")), "x is not a habit key")
  end,
}

return cases
