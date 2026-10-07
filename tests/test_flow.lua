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

-- play the running session by typing each round's intended solution
local function play_all(n)
  for i = 1, n do
    H.ok(wait_round(i), "round " .. i .. " did not start")
    local r = session.current().rounds[i]
    vim.api.nvim_feedkeys(r.sol.keys, "xt", false)
    H.settle(20)
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
      H.ok(t:find("0 / 42", 1, true))
    end,
  },
  {
    "a drill played at par ends in its summary and is saved",
    function()
      progress.wipe()
      require("dojo").open()
      session.start("1.1", "drill", { seed = 4242 })
      play_all(config.get().drill_rounds)
      H.ok(buffer_name():match("dojo://summary$"), "summary buffer")
      H.ok(buffer_text():find("Drill complete", 1, true))
      H.ok(progress.stage("1.1").drill_done)
    end,
  },
  {
    "a challenge played at par earns 3 stars and unlocks the next stage",
    function()
      progress.wipe()
      local saved = config.get().countdown_s
      config.get().countdown_s = 0
      require("dojo").open()
      session.start("2.4", "challenge", { seed = 99 })
      play_all(config.get().challenge_rounds)
      config.get().countdown_s = saved
      H.ok(buffer_name():match("dojo://summary$"), "summary buffer")
      H.ok(buffer_text():find("★★★", 1, true), "three stars shown")
      H.eq(progress.stage("2.4").best_stars, 3)
      H.ok(progress.unlocked("3.1"))
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
      session.start("1.1", "drill", { seed = 7 })
      H.ok(wait_round(1))
      H.type(":q<CR>")
      H.settle(50)
      H.eq(session.current(), nil, "session aborted")
      H.ok(buffer_name():match("dojo://menu$"), "back in the menu")
    end,
  },
  {
    "the header shows par, round and learned moves",
    function()
      progress.wipe()
      require("dojo").open()
      session.start("2.1", "drill", { seed = 3 })
      H.ok(wait_round(1))
      local hud = vim.fn.bufnr("dojo://hud")
      local t = table.concat(vim.api.nvim_buf_get_lines(hud, 0, -1, false), "\n")
      H.ok(t:find("round 1/5", 1, true), t)
      H.ok(t:find("par ", 1, true))
      H.ok(t:find("Learned: h j k l  x  i a  A I  w b", 1, true), t)
      session.abort()
    end,
  },
}
