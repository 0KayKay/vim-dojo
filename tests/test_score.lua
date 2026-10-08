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
      progress.wipe()
      H.ok(progress.unlocked("hjkl"))
      H.ok(not progress.unlocked("counts"))
      progress.record_drill("hjkl")
      H.ok(progress.record_challenge("hjkl", { stars = 1, score = 1.5 }))
      H.ok(progress.unlocked("counts"))
      H.ok(not progress.record_challenge("hjkl", { stars = 1, score = 1.2 }), "worse is not a new best")
      H.ok(progress.record_challenge("hjkl", { stars = 2, score = 2.1 }))
      progress.setting("habit", false)
      progress.reset() -- reload from disk
      local s = progress.stage("hjkl")
      H.eq(s.best_stars, 2)
      H.eq(s.attempts, 3)
      H.ok(s.drill_done)
      H.eq(progress.setting("habit"), false)
      H.eq((progress.total_stars()), 2)
    end,
  },
  {
    "progress: habit mode is on for new players",
    function()
      progress.wipe()
      H.eq(progress.setting("habit"), true)
    end,
  },
  {
    "progress: bosses open with their world and let you skip ahead",
    function()
      progress.wipe()
      H.ok(progress.unlocked("boss_1"), "the first boss is open from the start")
      H.ok(not progress.unlocked("boss_2"))
      H.ok(not progress.unlocked("word"))
      progress.record_challenge("boss_1", { stars = 1, score = 1.5 })
      H.ok(progress.unlocked("word"), "the next world opens")
      H.ok(progress.unlocked("boss_2"))
      H.ok(progress.unlocked("append"), "the rest of the beaten world opens too")
      H.ok(not progress.unlocked("word_end"))
    end,
  },
  {
    "progress: version 1 files move to stage keys",
    function()
      progress.wipe()
      local dir = progress.dir()
      vim.fn.mkdir(dir, "p")
      local f = assert(io.open(dir .. "/progress.json", "w"))
      f:write(vim.json.encode({
        stages = {
          ["1.2"] = { explainer_seen = true, drill_done = true, best_stars = 3, best_score = 3, attempts = 2 },
          ["2.4"] = { explainer_seen = true, drill_done = true, best_stars = 2, best_score = 2.4, attempts = 1 },
          ["3.2"] = { explainer_seen = true, drill_done = false, best_stars = 0, best_score = 0, attempts = 0 },
        },
        settings = { habit = false },
      }))
      f:close()
      progress.reset()
      H.eq(progress.stage("x").best_stars, 3, "1.2 was x")
      H.eq(progress.stage("counts").best_stars, 2, "2.4 was counts")
      H.ok(progress.stage("lines").explainer_seen, "3.2 was dd")
      H.eq(progress.setting("habit"), true, "habit mode is the new default")
      H.ok(progress.unlocked("insert"), "after a passed stage")
      H.ok(progress.unlocked("delete"), "v1 3.1 was open after 2.4, though 2.B now comes first")
      H.ok(not progress.unlocked("word"), "v1 2.1 was locked too")
      progress.reset() -- saved as version 2
      local raw = vim.json.decode(table.concat(vim.fn.readfile(dir .. "/progress.json"), "\n"))
      H.eq(raw.version, 2)
      H.eq(raw.stages.x.best_stars, 3)
      H.eq(raw.stages["1.2"], nil)
    end,
  },
  {
    "concept report: averages per move and the weakest one",
    function()
      local function r(stars, ...)
        local c = {}
        for _, f in ipairs({ ... }) do
          c[f] = true
        end
        return { stars = stars, solved = stars > 0, concepts = c }
      end
      local list, weakest = score.concept_report({
        r(3, "wb", "count"),
        r(3, "wb", "line"),
        r(1, "line", "e"),
        r(2, "e", "count"),
        r(3, "hjkl"),
      })
      local names = {}
      for _, st in ipairs(list) do
        names[#names + 1] = st.fam
      end
      H.eq(names, { "wb", "count", "line", "e" }, "best first, one-off moves left out")
      H.eq(weakest.fam, "e")
      H.eq(weakest.avg, 1.5)
      local _, none = score.concept_report({ r(3, "wb"), r(3, "wb") })
      H.eq(none, nil, "nothing to sharpen when every round was at par")
    end,
  },
}
