-- Star rules, habit hints, progress (SPEC §6, §9).
local H = require("helpers")
local score = require("dojo.score")
local progress = require("dojo.progress")

local function rounds(spec)
  local out = {}
  for _, s in ipairs(spec) do
    out[#out + 1] = { solved = s[1] > 0, stars = s[1], count = s[2] or 2, par = s[3] or 2, time_ms = 1000 }
  end
  return out
end

return {
  {
    "round stars",
    function()
      H.eq(score.round_stars({ solved = true, count = 2 }, 2), 3)
      H.eq(score.round_stars({ solved = true, count = 1 }, 2), 3)
      H.eq(score.round_stars({ solved = true, count = 4 }, 2), 2)
      H.eq(score.round_stars({ solved = true, count = 5 }, 2), 1)
      H.eq(score.round_stars({ solved = true, count = 2, hint = true }, 2), 1)
      H.eq(score.round_stars({ solved = false, count = 2 }, 2), 0)
    end,
  },
  {
    "challenge stars: pass needs 6 of 8 solved",
    function()
      local s = score.summary(rounds({ { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 0 }, { 0 }, { 0 } }))
      H.eq(s.pass, false)
      H.eq(s.stars, 0)
      s = score.summary(rounds({ { 1 }, { 1 }, { 1 }, { 1 }, { 1 }, { 1 }, { 0 }, { 0 } }))
      H.eq(s.pass, true)
      H.eq(s.stars, 1)
    end,
  },
  {
    "challenge stars: score thresholds 2.0 and 2.75",
    function()
      H.eq(score.summary(rounds({ { 2 }, { 2 }, { 2 }, { 2 }, { 2 }, { 2 }, { 2 }, { 2 } })).stars, 2)
      -- 6 at par and 2 at par + 1 is 22 / 8 = 2.75
      H.eq(score.summary(rounds({ { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 2 }, { 2 } })).stars, 3)
      H.eq(score.summary(rounds({ { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 3 }, { 0 } })).stars, 2)
    end,
  },
  {
    "habit hints name the counted form",
    function()
      local function k(list, mode)
        local out = {}
        for c in list:gmatch(".") do
          out[#out + 1] = { k = c, mode = mode or "n" }
        end
        return out
      end
      H.eq(score.habit_hints(k("jjjjw"), 3), { "jjjj → 4j" })
      H.eq(score.habit_hints(k("jjw"), 3), {})
      H.eq(score.habit_hints(k("xxx", "i"), 3), {}, "typed text is not a habit")
      H.eq(score.habit_hints(k("wwwbbb"), 3), { "www → 3w", "bbb → 3b" })
    end,
  },
  {
    "progress: unlock, best result, save and load",
    function()
      progress.reset()
      H.ok(progress.unlocked("1.1"))
      H.ok(not progress.unlocked("1.2"))
      progress.record_drill("1.1")
      H.ok(progress.record_challenge("1.1", { stars = 1, score = 1.5 }))
      H.ok(progress.unlocked("1.2"))
      H.ok(not progress.record_challenge("1.1", { stars = 1, score = 1.2 }), "worse is not a new best")
      H.ok(progress.record_challenge("1.1", { stars = 2, score = 2.1 }))
      progress.setting("habit", true)
      progress.reset()
      local s = progress.stage("1.1")
      H.eq(s.best_stars, 2)
      H.eq(s.attempts, 3)
      H.ok(s.drill_done)
      H.eq(progress.setting("habit"), true)
      H.eq((progress.total_stars()), 2)
    end,
  },
}
