-- Star rules and habit hints (SPEC.md §6).
local config = require("dojo.config")

local M = {}

-- result: { solved, count, hint }
function M.round_stars(result, par)
  if not result.solved then
    return 0
  end
  if result.hint then
    return 1
  end
  if result.count <= par then
    return 3
  end
  if result.count <= par + config.get().star2_slack then
    return 2
  end
  return 1
end

-- rounds: list of { solved, stars, count, par, time_ms }
function M.summary(rounds)
  local cfg = config.get()
  local n, solved, at_par, sum, time = #rounds, 0, 0, 0, 0
  for _, r in ipairs(rounds) do
    if r.solved then
      solved = solved + 1
      time = time + r.time_ms
      if r.count <= r.par and not r.hint then
        at_par = at_par + 1
      end
    end
    sum = sum + r.stars
  end
  local score = n > 0 and sum / n or 0
  local pass = n > 0 and solved / n >= cfg.pass_ratio
  local stars = 0
  if pass then
    stars = 1
    if score >= cfg.score_for_2 then
      stars = 2
    end
    if score >= cfg.score_for_3 then
      stars = 3
    end
  end
  return {
    rounds = n,
    solved = solved,
    at_par = at_par,
    score = score,
    pass = pass,
    stars = stars,
    avg_time_s = solved > 0 and time / solved / 1000 or 0,
  }
end

local hint_keys = { h = true, j = true, k = true, l = true, w = true, b = true, e = true, x = true }

-- keys: list of { k = display key, mode = mode when typed }
-- returns hints like "jjjj → 4j", one per run of repeated presses
function M.habit_hints(keys, run_len)
  run_len = run_len or config.get().habit_hint_run
  local out = {}
  local i = 1
  while i <= #keys do
    local k = keys[i]
    local j = i
    if hint_keys[k.k] and k.mode == "n" then
      while keys[j + 1] and keys[j + 1].k == k.k and keys[j + 1].mode == "n" do
        j = j + 1
      end
      local n = j - i + 1
      if n >= run_len then
        out[#out + 1] = string.format("%s → %d%s", string.rep(k.k, n), n, k.k)
      end
    end
    i = j + 1
  end
  return out
end

-- stars as text, e.g. 2 -> "★★☆"
function M.stars_text(n, max)
  max = max or 3
  return string.rep("★", n) .. string.rep("☆", max - n)
end

return M
