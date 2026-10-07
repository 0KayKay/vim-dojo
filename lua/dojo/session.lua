-- A drill or challenge: plans rounds, generates them one ahead, scores them,
-- and hands over to the summary (SPEC.md §4–6).
local config = require("dojo.config")
local curriculum = require("dojo.curriculum")
local solver = require("dojo.solver")
local score = require("dojo.score")
local progress = require("dojo.progress")
local Rng = require("dojo.rng")
local round = require("dojo.round")

local M = {}

local cur -- the running session

local function generator(pick)
  if pick == "twostep" then
    return require("dojo.stages.twostep")
  end
  return curriculum.get(pick)
end

-- Generate a round from stage `pick` (or "twostep") until the solver finds a
-- valid par; drills also need the stage's move in the intended solution.
-- ctx: { learned, mode }
function M.make_round(pick, ctx, rng)
  local gen = generator(pick)
  for _ = 1, config.get().generate_tries do
    local seed = rng:seed()
    local task = gen.generate(Rng.new(seed), ctx)
    if task then
      task.seed = seed
      task.stage = pick
      local sol = solver.solve(task, ctx.learned, { focus = gen.focus })
      if sol and sol.cost > 0 and (ctx.mode ~= "drill" or sol.focus) and solver.check(task, sol.tokens) then
        return { task = task, sol = sol, focus = gen.focus, pick = pick }
      end
    end
  end
  error(string.format("Vim Dojo: could not generate a %s round for stage %s", ctx.mode, pick))
end

-- Which stage generates each round (SPEC.md §4 Challenge composition).
function M.plan(stage_id, mode, rng)
  local cfg = config.get()
  local p = {}
  if mode == "drill" then
    for i = 1, cfg.drill_rounds do
      p[i] = stage_id
    end
    return p
  end
  for _ = 1, cfg.challenge_focus_rounds do
    p[#p + 1] = stage_id
  end
  if curriculum.has_twostep(stage_id) then
    for _ = 1, cfg.challenge_twostep_rounds do
      p[#p + 1] = "twostep"
    end
  end
  local earlier = curriculum.before(stage_id)
  while #p < cfg.challenge_rounds do
    p[#p + 1] = #earlier > 0 and rng:pick(earlier) or stage_id
  end
  return rng:shuffle(p)
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
  s.rounds[s.i] = r
  if s.mode == "challenge" then
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
    stage = s.id,
    round_stage = r.pick,
    mode = s.mode,
    seed = r.task.seed,
    keys = table.concat(vim.tbl_map(function(k)
      return k.k
    end, res.keys)),
    count = res.count,
    par = r.par,
    intended = r.sol.display,
    time_ms = math.floor(res.time_ms),
    solved = res.solved,
    stars = r.stars,
    hint = res.hint,
    blocked = res.blocked,
  })
  -- use the pause for the slow work: alternatives, and the next round
  local t0 = vim.uv.hrtime()
  r.alts = solver.alternatives(r.task, s.learned, r.sol, { focus = r.focus })
  local more = s.i < #s.plan
  if more then
    s.next = M.make_round(s.plan[s.i + 1], { learned = s.learned, mode = s.mode }, s.rng)
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

-- stage_id: "2.1"; mode: "drill" | "challenge"; opts.seed for reproducible runs
function M.start(stage_id, mode, opts)
  M.abort()
  opts = opts or {}
  local cfg = config.get()
  local learned = curriculum.learned_through(stage_id)
  local seed = opts.seed or ((math.floor(vim.uv.hrtime() / 1000) % 2147480000) + 1)
  local rng = Rng.new(seed)
  local s = {
    id = stage_id,
    stage = curriculum.get(stage_id),
    mode = mode,
    learned = learned,
    seed = seed,
    rng = rng,
    rounds = {},
    i = 0,
    habit = (progress.setting("habit") and learned.count) and true or false,
  }
  s.plan = M.plan(stage_id, mode, rng)
  cur = s
  local buf = play_window()
  round.clear(buf)
  s.next = M.make_round(s.plan[1], { learned = learned, mode = mode }, rng)
  if mode == "challenge" and cfg.countdown_s > 0 then
    countdown(s, cfg.countdown_s, M.next_round)
  else
    M.next_round()
  end
  return s
end

return M
