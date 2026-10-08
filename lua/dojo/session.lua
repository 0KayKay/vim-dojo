-- A drill, challenge or boss: plans rounds, generates them one ahead, checks
-- each against its requirement, scores them, and hands over to the summary
-- (SPEC.md §4–6, decisions 0008 and 0009).
local config = require("dojo.config")
local curriculum = require("dojo.curriculum")
local solver = require("dojo.solver")
local score = require("dojo.score")
local progress = require("dojo.progress")
local moves = require("dojo.moves")
local compose = require("dojo.compose")
local Rng = require("dojo.rng")
local round = require("dojo.round")

local M = {}

local cur -- the running session

-- Round specs in a plan:
--   { key = stage, variant = "basic" | "combined" }   drill and challenge rounds
--   { key = stage, variant = "mixed" }                boss: two move families
--   { variant = "chain", steps = n }                  boss: n steps in a row
function M.plan(key, mode, rng)
  local cfg = config.get()
  local p = {}
  if mode == "boss" then
    -- mixed rounds take turns among the world's stages, so the stages whose
    -- rounds combine most easily don't win every pick
    local keys = vim.tbl_filter(function(k)
      return curriculum.can_mix(k, key)
    end, curriculum.stages_through(key, curriculum.get(key).world))
    rng:shuffle(keys)
    for i = 1, cfg.boss_mixed_rounds do
      p[#p + 1] = { key = keys[(i - 1) % #keys + 1], variant = "mixed" }
    end
    for _, n in ipairs(cfg.boss_chains) do
      p[#p + 1] = { variant = "chain", steps = n }
    end
    return p
  end
  local combinable = curriculum.can_combine(key)
  if mode == "drill" then
    local nb, nc = cfg.drill_basic_rounds, cfg.drill_combined_rounds
    if not combinable then
      nb, nc = nb + nc, 0
    end
    for _ = 1, nb do
      p[#p + 1] = { key = key, variant = "basic" }
    end
    for _ = 1, nc do
      p[#p + 1] = { key = key, variant = "combined" }
    end
    return p -- basics first, then combined
  end
  local nc = combinable and math.min(cfg.challenge_combined_rounds, cfg.challenge_rounds) or 0
  for _ = 1, cfg.challenge_rounds - nc do
    p[#p + 1] = { key = key, variant = "basic" }
  end
  for _ = 1, nc do
    p[#p + 1] = { key = key, variant = "combined" }
  end
  return rng:shuffle(p)
end

local function uses_world(concepts, w)
  local fams = curriculum.world_families(w)
  for f in pairs(concepts) do
    if fams[f] then
      return true
    end
  end
  return false
end

-- Solutions that use one capped move three times (4l4l4l, 4l4ll4l) teach
-- nothing but patience; such rounds are generated again.
local function clunky(sol)
  local seen = {}
  for _, t in ipairs(sol.tokens) do
    seen[t.keys] = (seen[t.keys] or 0) + 1
    if seen[t.keys] >= 3 then
      return true
    end
  end
  return false
end
M.clunky = clunky

-- Would habit mode block this solution? Three presses of one habit key in a
-- row (kkk); typed text does not count.
function M.habit_breaking(sol)
  local habit = config.get().habit.keys
  local run, prev = 0, nil
  for _, t in ipairs(sol.tokens) do
    if #t.keys == 1 and habit:find(t.keys, 1, true) then
      run = t.keys == prev and run + 1 or 1
      prev = t.keys
      if run >= 3 then
        return true
      end
    else
      run, prev = 0, nil
    end
  end
  return false
end

-- a task from a stage: basic, the stage's own combined generator, or the
-- generic combine step
local function stage_task(st, variant, rng, gctx)
  if variant == "basic" then
    return st.generate(rng, gctx)
  end
  local t = st.combined and st.combined(rng, gctx)
  if t then
    return t
  end
  local base = st.generate(rng, gctx)
  return base and compose.combine(base, rng, gctx)
end

-- does a solved round meet its spec's requirement?
local function meets(spec, st, sol, ctx)
  local concepts = moves.concepts(sol)
  if spec.variant == "basic" then
    return sol.focus
  elseif spec.variant == "combined" then
    return sol.focus and #moves.other_moves(concepts, moves.focus_set(st.focus)) >= 1
  else -- mixed
    return uses_world(concepts, ctx.world) and #moves.other_moves(concepts) >= 2
  end
end

local function make_chain(spec, ctx, rng)
  local gctx = { learned = ctx.learned, mode = ctx.mode, variant = "basic" }
  local world_keys = curriculum.stages_through(ctx.key, ctx.world)
  local all_keys = curriculum.stages_through(ctx.key)
  for _ = 1, config.get().generate_tries do
    local seed = rng:seed()
    local r = Rng.new(seed)
    local steps, ok = {}, true
    for i = 1, spec.steps do
      local step
      for _ = 1, 30 do
        local key = (i == 1 and r:pick(world_keys)) or (not r:chance(0.25) and r:pick(all_keys)) or nil
        if key then
          local st = curriculum.get(key)
          local task = (r:chance(0.5) and st.combined and st.combined(r, gctx)) or st.generate(r, gctx)
          step = compose.line_step(task)
          if step then
            step.stage, step.focus = key, st.focus
          end
        else
          step = compose.spot_step(r, false)
        end
        if step then
          break
        end
      end
      if not step then
        ok = false
        break
      end
      steps[i] = step
    end
    if ok then
      r:shuffle(steps) -- the step from this world is not always first
      local lines, rows, cursor = compose.layout(r, steps)
      local state = { lines = lines, cursor = cursor }
      local sols, total, keys, displays, tokens = {}, 0, "", {}, {}
      for i, st in ipairs(steps) do
        st.row = rows[i]
        local sub = compose.step_task(st, state.lines, state.cursor)
        local sol = solver.solve(sub, ctx.learned, { focus = st.focus, max_cost = config.get().solver.max_cost_chain_step })
        if not sol or sol.cost == 0 or clunky(sol) or not solver.check(sub, sol.tokens) then
          ok = false
          break
        end
        st.sol = sol
        sols[#sols + 1] = sol
        total = total + sol.cost
        keys = keys .. sol.keys
        displays[#displays + 1] = sol.display
        vim.list_extend(tokens, sol.tokens)
        state = solver.run(sub, sol.tokens)
      end
      local concepts = ok and moves.concepts(unpack(sols)) or {}
      if ok and uses_world(concepts, ctx.world) then
        return {
          task = { kind = "chain", lines = lines, cursor = cursor, steps = steps, seed = seed, stage = "chain" },
          sol = { cost = total, keys = keys, display = table.concat(displays, " · "), tokens = tokens },
          pick = "chain",
          variant = "chain",
          concepts = concepts,
        }
      end
    end
  end
  error(string.format("Vim Dojo: could not generate a %d-step chain", spec.steps))
end

-- Generate a round for a plan spec until it is solvable and meets its
-- requirement. ctx: { learned, mode, key (the session's stage or boss), world }
function M.make_round(spec, ctx, rng)
  if type(spec) == "string" then
    spec = { key = spec, variant = "basic" } -- shorthand used by tests
  end
  if spec.variant == "chain" then
    return make_chain(spec, ctx, rng)
  end
  local tries = config.get().generate_tries
  local world_keys = curriculum.stages_through(ctx.key, ctx.world)
  local gctx = { learned = ctx.learned, mode = ctx.mode, variant = spec.variant }
  for i = 1, tries do
    -- a mixed round falls back to any stage of the world when its own stage
    -- can't combine with two moves (h j k l alone, say)
    local candidates = world_keys
    if spec.key and not (spec.variant == "mixed" and i > tries / 2) then
      candidates = { spec.key }
    end
    local seed = rng:seed()
    local r = Rng.new(seed)
    local st = curriculum.get(r:pick(candidates))
    local task = stage_task(st, spec.variant == "mixed" and "combined" or spec.variant, r, gctx)
    if task then
      task.seed = seed
      task.stage = st.key
      local sol = solver.solve(task, ctx.learned, { focus = st.focus })
      if sol and sol.cost > 0 and not clunky(sol) and meets(spec, st, sol, ctx) and solver.check(task, sol.tokens) then
        return {
          task = task,
          sol = sol,
          focus = st.focus,
          pick = st.key,
          variant = spec.variant,
          concepts = moves.concepts(sol),
        }
      end
    end
  end
  error(string.format("Vim Dojo: could not generate a %s round for %s", spec.variant, tostring(spec.key or ctx.key)))
end

function M.current()
  return cur
end

function M.abort()
  round.abort()
  if cur then
    cur = nil
    require("dojo.ui.layout").close_hud()
  end
end

local function hud()
  return require("dojo.ui.hud")
end

local function play_window()
  return require("dojo.ui.layout").play()
end

local function ctx_of(s)
  return { learned = s.learned, mode = s.mode, key = s.id, world = s.stage.world }
end

function M.next_round()
  local s = cur
  if not s then
    return
  end
  local cfg = config.get()
  s.i = s.i + 1
  local r = s.next
  s.next = nil
  r.index = s.i
  r.step = 1
  s.rounds[s.i] = r
  if s.mode ~= "drill" then
    r.limit_ms = (cfg.time_base_s + cfg.time_per_key_s * r.sol.cost) * 1000
  end
  local buf, win = play_window()
  hud().round(s, r)
  round.start({
    buf = buf,
    win = win,
    task = r.task,
    limit_ms = r.limit_ms,
    habit = s.habit,
    on_done = function(res)
      M.round_done(s, r, res)
    end,
    on_tick = function(elapsed)
      r.elapsed = elapsed
      if cur == s then
        hud().tick(s, r, elapsed)
      end
    end,
    on_step = function(step)
      r.step = step
      hud().tick(s, r, r.elapsed)
    end,
    on_hint = function()
      hud().hint(s, r)
    end,
    on_blocked = function(key)
      hud().blocked(s, r, key)
    end,
  })
end

function M.round_done(s, r, res)
  if cur ~= s then
    return
  end
  local cfg = config.get()
  r.result = res
  r.solved = res.solved
  r.count = res.count
  r.time_ms = res.time_ms
  r.hint = res.hint
  r.par = r.sol.cost
  r.stars = score.round_stars(res, r.par)
  r.hints = s.learned.count and score.habit_hints(res.keys) or {}
  hud().result(s, r)
  progress.log_round({
    time = os.time(),
    stage = s.stage.key,
    round_stage = r.pick,
    mode = s.mode,
    kind = r.variant,
    seed = r.task.seed,
    keys = table.concat(vim.tbl_map(function(k)
      return k.k
    end, res.keys)),
    count = res.count,
    par = r.par,
    intended = r.sol.display,
    concepts = (function()
      local list = vim.tbl_keys(r.concepts or {})
      table.sort(list)
      return list
    end)(),
    time_ms = math.floor(res.time_ms),
    limit_ms = r.limit_ms,
    solved = res.solved,
    stars = r.stars,
    hint = res.hint,
    blocked = res.blocked,
  })
  -- use the pause for the slow work: alternatives, and the next round
  local t0 = vim.uv.hrtime()
  if r.variant ~= "chain" then
    r.alts = solver.alternatives(r.task, s.learned, r.sol, { focus = r.focus })
    if s.learned.count then
      r.alts = vim.tbl_filter(function(a)
        return not M.habit_breaking(a)
      end, r.alts)
    end
    hud().result(s, r) -- again, now with the alternatives
  end
  local more = s.i < #s.plan
  if more then
    s.next = M.make_round(s.plan[s.i + 1], ctx_of(s), s.rng)
  end
  local spent = (vim.uv.hrtime() - t0) / 1e6
  local pause = res.solved and cfg.pause_success_ms or cfg.pause_fail_ms
  vim.defer_fn(function()
    if cur ~= s then
      return
    end
    if more then
      M.next_round()
    else
      M.finish()
    end
  end, math.max(0, math.floor(pause - spent)))
end

function M.finish()
  local s = cur
  if not s then
    return
  end
  cur = nil
  local sum = score.summary(s.rounds)
  local newbest = false
  if s.mode == "drill" then
    progress.record_drill(s.id)
  else
    newbest = progress.record_challenge(s.id, sum)
  end
  require("dojo.ui.layout").close_hud()
  require("dojo.ui.summary").show(s, sum, newbest)
end

local function countdown(s, n, done)
  if cur ~= s then
    return
  end
  if n <= 0 then
    s.last = nil
    done()
    return
  end
  hud().countdown(s, n)
  vim.defer_fn(function()
    countdown(s, n - 1, done)
  end, 1000)
end

-- key: a stage or boss key; mode: "drill" | "challenge" | "boss" (bosses always
-- run as "boss"); opts.seed for reproducible runs
function M.start(key, mode, opts)
  M.abort()
  opts = opts or {}
  local cfg = config.get()
  local stage = curriculum.get(key)
  if stage.is_boss then
    mode = "boss"
  end
  local learned = curriculum.learned_through(key)
  local seed = opts.seed or ((math.floor(vim.uv.hrtime() / 1000) % 2147480000) + 1)
  local rng = Rng.new(seed)
  local s = {
    id = key,
    stage = stage,
    mode = mode,
    learned = learned,
    seed = seed,
    rng = rng,
    rounds = {},
    i = 0,
    -- habit mode only in timed rounds, once counts are known (decision 0011)
    habit = (mode ~= "drill" and progress.setting("habit") and learned.count) and true or false,
  }
  s.plan = M.plan(key, mode, rng)
  cur = s
  require("dojo.ui.menu").remember(key)
  local buf = play_window()
  round.clear(buf)
  s.next = M.make_round(s.plan[1], ctx_of(s), rng)
  if mode ~= "drill" and cfg.countdown_s > 0 then
    countdown(s, cfg.countdown_s, M.next_round)
  else
    M.next_round()
  end
  return s
end

return M
