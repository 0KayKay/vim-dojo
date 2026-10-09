-- End to end: menu, drill, challenge, summary, unlock (SPEC §11).
local H = require("helpers")
local config = require("dojo.config")
local session = require("dojo.session")
local round = require("dojo.round")
local progress = require("dojo.progress")

local function wait_round(i)
  return vim.wait(3000, function()
    local s = session.current()
    return s ~= nil and s.i == i and round.is_active()
  end, 10)
end

-- play the running session by typing each round's intended solution; chain
-- steps one at a time, as a player would
local function play_all()
  local n = #session.current().plan
  for i = 1, n do
    H.ok(wait_round(i), "round " .. i .. " did not start")
    local r = session.current().rounds[i]
    if r.task.kind == "chain" then
      for _, step in ipairs(r.task.steps) do
        vim.api.nvim_feedkeys(step.sol.keys, "xt", false)
        H.settle(20)
      end
    else
      vim.api.nvim_feedkeys(r.sol.keys, "xt", false)
      H.settle(20)
    end
  end
  vim.wait(3000, function()
    return session.current() == nil
  end, 10)
end

local function buffer_name()
  return vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
end

local function buffer_text()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

return {
  {
    "menu shows worlds, stars and locks",
    function()
      progress.wipe()
      require("dojo").open()
      H.ok(buffer_name():match("dojo://menu$"), "menu buffer")
      local t = buffer_text()
      H.ok(t:find("VIM DOJO", 1, true))
      H.ok(t:find("World 4 · Find in the line", 1, true))
      H.ok(t:find("locked", 1, true))
      H.ok(t:find("0 / 51", 1, true))
      H.ok(t:find("1.B", 1, true) and t:find("skip ahead", 1, true), "bosses can be tried early")
    end,
  },
  {
    "a drill played at par ends in its summary and is saved",
    function()
      progress.wipe()
      require("dojo").open()
      session.start("hjkl", "drill", { seed = 4242 })
      play_all()
      H.ok(buffer_name():match("dojo://summary$"), "summary buffer")
      H.ok(buffer_text():find("Drill complete", 1, true))
      H.ok(progress.stage("hjkl").drill_done)
    end,
  },
  {
    "a challenge played at par earns 3 stars and unlocks the next stage",
    function()
      progress.wipe()
      local saved = config.get().countdown_s
      config.get().countdown_s = 0
      require("dojo").open()
      session.start("hjkl", "challenge", { seed = 98 })
      H.ok(not session.current().habit, "no habit mode before counts are learned")
      session.start("counts", "drill", { seed = 98 })
      H.ok(not session.current().habit, "no habit mode in drills")
      session.start("counts", "challenge", { seed = 99 })
      H.ok(session.current().habit, "habit mode is on in challenges once counts are known")
      play_all()
      config.get().countdown_s = saved
      H.ok(buffer_name():match("dojo://summary$"), "summary buffer")
      H.ok(buffer_text():find("★★★", 1, true), "three stars shown")
      H.eq(progress.stage("counts").best_stars, 3)
      H.ok(progress.unlocked("word"))
    end,
  },
  {
    "the round log gets one line per round",
    function()
      local f = io.open(progress.dir() .. "/rounds.jsonl")
      H.ok(f, "rounds.jsonl exists")
      local n = 0
      for line in f:lines() do
        local entry = vim.json.decode(line)
        H.ok(entry.stage and entry.keys and entry.par)
        n = n + 1
      end
      f:close()
      H.eq(n, config.get().challenge_rounds, "one line per challenge round")
    end,
  },
  {
    ":q in a round goes back to the menu",
    function()
      progress.wipe()
      require("dojo").open()
      session.start("hjkl", "drill", { seed = 7 })
      H.ok(wait_round(1))
      H.type(":q<CR>")
      H.settle(50)
      H.eq(session.current(), nil, "session aborted")
      H.ok(buffer_name():match("dojo://menu$"), "back in the menu")
    end,
  },
  {
    ":Dojo during a round stops it and shows the menu",
    function()
      progress.wipe()
      require("dojo").open()
      session.start("hjkl", "drill", { seed = 11 })
      H.ok(wait_round(1))
      vim.cmd("Dojo")
      H.settle(30)
      H.eq(session.current(), nil)
      H.ok(not round.is_active())
      H.ok(buffer_name():match("dojo://menu$"))
    end,
  },
  {
    "opening and closing the game leaves no empty buffers behind",
    function()
      require("dojo.ui.layout").close()
      vim.cmd("silent! %bwipe!")
      local function listed()
        return #vim.fn.getbufinfo({ buflisted = 1 })
      end
      local before = listed()
      local maps = #vim.api.nvim_get_keymap("n") + #vim.api.nvim_get_keymap("i")
      for _ = 1, 3 do
        require("dojo").open()
        require("dojo.ui.layout").close()
      end
      H.eq(listed(), before)
      H.eq(#vim.api.nvim_get_keymap("n") + #vim.api.nvim_get_keymap("i"), maps, "no global keymaps")
    end,
  },
  {
    "menu keymaps survive a wiped buffer",
    function()
      require("dojo").open()
      vim.cmd("silent! %bwipe!")
      require("dojo").open()
      local maps = vim.api.nvim_buf_get_keymap(0, "n")
      H.ok(#maps > 5, "menu has its keymaps again")
    end,
  },
  {
    "the header shows par, round and learned moves",
    function()
      progress.wipe()
      require("dojo").open()
      session.start("word", "drill", { seed = 3 })
      H.ok(wait_round(1))
      local hud = vim.fn.bufnr("dojo://hud")
      local t = table.concat(vim.api.nvim_buf_get_lines(hud, 0, -1, false), "\n")
      H.ok(t:find("round 1/6", 1, true), t)
      H.ok(t:find("Drill · basics", 1, true), t)
      H.ok(t:find("par ", 1, true))
      H.ok(t:find("Learned: h j k l  x  i a  A I  counts  w b", 1, true), t)
      session.abort()
    end,
  },
  {
    "a boss played at par: chains advance step by step, the summary names moves",
    function()
      progress.wipe()
      local saved = config.get().countdown_s
      config.get().countdown_s = 0
      require("dojo").open()
      require("dojo.ui.explainer").show("boss_1")
      local t = buffer_text()
      H.ok(t:find("Which move when", 1, true), t)
      local s = session.start("boss_1", "challenge", { seed = 5 })
      H.eq(s.mode, "boss", "a boss always runs as a boss")
      play_all()
      config.get().countdown_s = saved
      H.ok(buffer_name():match("dojo://summary$"), "summary buffer")
      t = buffer_text()
      H.ok(t:find("World 1 boss complete", 1, true), t)
      H.ok(t:find("By move", 1, true), t)
      H.ok(t:find(" · ", 1, true), "chain steps are listed: " .. t)
      H.eq(progress.stage("boss_1").best_stars, 3)
      -- beating a boss opens the next world, and skips what is left of this one
      H.ok(progress.unlocked("counts"))
      H.ok(progress.unlocked("append"))
    end,
  },
  {
    "every explainer and the menu fit an 80 x 24 screen",
    function()
      progress.wipe()
      require("dojo").open()
      local win = vim.api.nvim_get_current_win()
      local rows = 24 - 2 -- status line and command line
      H.ok(vim.api.nvim_buf_line_count(0) <= rows, "menu has " .. vim.api.nvim_buf_line_count(0) .. " rows")
      for _, key in ipairs(require("dojo.curriculum").order) do
        require("dojo.ui.explainer").show(key)
        local n = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
        H.ok(n <= rows, key .. " explainer has " .. n .. " rows")
        for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          H.ok(vim.fn.strdisplaywidth(l) <= 80, key .. " explainer line too wide: " .. l)
        end
      end
    end,
  },
  {
    "every stage and boss plays end to end at par (SPEC §11)",
    function()
      progress.wipe()
      local cfg = config.get()
      local saved = { cfg.countdown_s, cfg.pause_success_ms }
      cfg.countdown_s, cfg.pause_success_ms = 0, 0
      require("dojo").open()
      local curriculum = require("dojo.curriculum")
      for i, key in ipairs(curriculum.order) do
        local modes = curriculum.get(key).is_boss and { "boss" } or { "drill", "challenge" }
        for _, mode in ipairs(modes) do
          session.start(key, mode, { seed = 1000 + i })
          play_all()
          H.ok(buffer_name():match("dojo://summary$"), key .. " " .. mode .. " did not reach its summary")
        end
        H.eq(progress.stage(key).best_stars, 3, key .. " at par earns 3 stars")
      end
      cfg.countdown_s, cfg.pause_success_ms = saved[1], saved[2]
    end,
  },
  {
    "<CR> in the menu opens the stage page, which names its next step",
    function()
      progress.wipe()
      progress.record_drill("hjkl")
      progress.record_challenge("hjkl", { stars = 1, score = 1.5 })
      require("dojo").open()
      require("dojo.ui.menu").show("hjkl")
      H.type("<CR>")
      H.settle(20)
      H.ok(buffer_name():match("dojo://explainer$"), "the stage page, not the challenge")
      H.eq(session.current(), nil)
      local status = vim.wo.statusline
      H.ok(status:find("start the challenge", 1, true), status)
      require("dojo.ui.menu").show("x")
      H.type("<CR>")
      H.settle(20)
      H.ok(vim.wo.statusline:find("start the drill", 1, true), vim.wo.statusline)
    end,
  },
  {
    "a round from a summary can be looked at and played again, unsaved",
    function()
      progress.wipe()
      local cfg = config.get()
      local saved = cfg.countdown_s
      cfg.countdown_s = 0
      require("dojo").open()
      session.start("x", "challenge", { seed = 31 })
      play_all()
      H.ok(buffer_name():match("dojo://summary$"))
      local before = progress.stage("x").attempts
      local log = #vim.fn.readfile(progress.dir() .. "/rounds.jsonl")
      H.type("j")
      H.type("<CR>")
      H.settle(20)
      H.ok(buffer_name():match("dojo://review$"), "the review screen")
      local hud = table.concat(vim.api.nvim_buf_get_lines(vim.fn.bufnr("dojo://hud"), 0, -1, false), "\n")
      H.ok(hud:find("round 2 of 8", 1, true), hud)
      H.ok(hud:find("par ", 1, true), hud)
      local shown = require("dojo.ui.review")._round()
      H.eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), shown.task.lines, "the text as the round started")
      H.eq(vim.api.nvim_win_get_cursor(0), shown.task.cursor, "the cursor where it started")
      -- :q during a replay goes back to the review, not the menu
      H.type("p")
      H.ok(vim.wait(2000, round.is_active, 10))
      H.type(":q<CR>")
      H.settle(50)
      H.ok(buffer_name():match("dojo://review$"), ":q in a replay: " .. buffer_name())
      H.ok(not round.is_active(), "the replay stopped")
      H.type("p")
      H.ok(vim.wait(2000, round.is_active, 10), "the replay starts")
      H.ok(buffer_name():match("dojo://play$"))
      H.eq(session.current(), nil, "a replay is not a session")
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(
        require("dojo.ui.review")._round().sol.keys, true, false, true), "xt", false)
      H.ok(vim.wait(3000, function()
        return buffer_name():match("dojo://review$") ~= nil
      end, 10), "back on the review after the replay")
      hud = table.concat(vim.api.nvim_buf_get_lines(vim.fn.bufnr("dojo://hud"), 0, -1, false), "\n")
      H.ok(hud:find("Again", 1, true), hud)
      H.type("q")
      H.settle(20)
      H.ok(buffer_name():match("dojo://summary$"), "back on the summary")
      H.eq(vim.api.nvim_win_get_cursor(0)[1], 6, "on round 2 again")
      H.eq(progress.stage("x").attempts, before, "nothing saved")
      H.eq(#vim.fn.readfile(progress.dir() .. "/rounds.jsonl"), log, "nothing logged")
      cfg.countdown_s = saved
    end,
  },
  {
    "after a timeout the summary says that u undoes a slip",
    function()
      progress.wipe()
      local cfg = config.get()
      local saved = { cfg.countdown_s, cfg.time_base_s, cfg.time_per_key_s, cfg.pause_fail_ms }
      cfg.countdown_s, cfg.time_base_s, cfg.time_per_key_s, cfg.pause_fail_ms = 0, 0.2, 0, 0
      require("dojo").open()
      session.start("hjkl", "challenge", { seed = 5 })
      H.ok(vim.wait(8000, function()
        return session.current() == nil
      end, 20), "the challenge ran out")
      cfg.countdown_s, cfg.time_base_s, cfg.time_per_key_s, cfg.pause_fail_ms = saved[1], saved[2], saved[3], saved[4]
      local t = buffer_text()
      H.ok(t:find("time out", 1, true), t)
      H.ok(t:find("A slip? u undoes it", 1, true), t)
    end,
  },
  {
    ":Dojo from a review or a replay leaves just the menu",
    function()
      progress.wipe()
      local cfg = config.get()
      local saved = cfg.countdown_s
      cfg.countdown_s = 0
      require("dojo").open()
      -- windows in the game tab, without the solver's hidden scratch float
      local function windows()
        return vim.tbl_filter(function(w)
          return vim.api.nvim_win_get_config(w).relative == ""
        end, vim.api.nvim_tabpage_list_wins(0))
      end
      session.start("hjkl", "drill", { seed = 12 })
      play_all()
      H.type("<CR>")
      H.settle(20)
      H.ok(buffer_name():match("dojo://review$"))
      vim.cmd("Dojo")
      H.settle(20)
      H.ok(buffer_name():match("dojo://menu$"))
      H.eq(#windows(), 1, "no header left over the menu")
      -- and from a replay
      session.start("hjkl", "drill", { seed = 13 })
      play_all()
      H.type("<CR>")
      H.settle(20)
      H.type("p")
      H.ok(vim.wait(2000, round.is_active, 10))
      vim.cmd("Dojo")
      H.settle(20)
      H.ok(not round.is_active(), "the replay stopped")
      H.ok(buffer_name():match("dojo://menu$"))
      H.eq(#windows(), 1, "no header left over the menu")
      cfg.countdown_s = saved
    end,
  },
  {
    "habit mode's message suggests a count, or for l a word motion",
    function()
      progress.wipe()
      local cfg = config.get()
      local saved = cfg.countdown_s
      cfg.countdown_s = 0
      require("dojo").open()
      session.start("word", "challenge", { seed = 21 })
      H.ok(wait_round(1))
      local hud = vim.fn.bufnr("dojo://hud")
      local function header()
        return table.concat(vim.api.nvim_buf_get_lines(hud, 0, -1, false), "\n")
      end
      H.type("l")
      H.type("l")
      H.type("l")
      H.type("l")
      H.settle(30)
      H.ok(header():find("llll blocked. Try a word motion, like w e", 1, true), header())
      H.type("j")
      H.type("j")
      H.type("j")
      H.type("j")
      H.settle(30)
      H.ok(header():find("jjjj blocked. Try a count, like 4j", 1, true), header())
      session.abort()
      cfg.countdown_s = saved
    end,
  },
}
