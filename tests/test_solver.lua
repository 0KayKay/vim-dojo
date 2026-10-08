local H = require("helpers")
local solver = require("dojo.solver")

local all_motions = { "hjkl", "wb", "e", "line", "count" }

local function move(lines, cursor, goal)
  return { kind = "move", lines = lines, cursor = cursor, goal = goal }
end
local function edit(lines, cursor, goal_lines)
  return { kind = "edit", lines = lines, cursor = cursor, goal_lines = goal_lines }
end

local lorem = {
  "lorem ipsum dolor sit amet consectetur adipiscing elit sed",
  "    do eiusmod tempor incididunt ut labore et dolore magna",
  "aliqua ut enim ad minim veniam quis nostrud exercitation",
  "ullamco laboris nisi ut aliquip ex ea commodo consequat",
  "duis aute irure dolor in reprehenderit in voluptate velit",
  "esse cillum dolore eu fugiat nulla pariatur excepteur sint",
}

return {
  {
    "3w is par 2",
    function()
      local r = solver.solve(move({ "the quick brown fox jumps over" }, { 1, 0 }, { 1, 16 }), H.learned(all_motions))
      H.eq(r.cost, 2)
      H.eq(r.keys, "3w")
    end,
  },
  {
    "$ is par 1",
    function()
      local r = solver.solve(move({ "the quick brown fox" }, { 1, 4 }, { 1, 18 }), H.learned({ "hjkl", "line" }))
      H.eq(r.keys, "$")
    end,
  },
  {
    "without counts, jjj is par 3",
    function()
      local r = solver.solve(move(lorem, { 1, 0 }, { 4, 0 }), H.learned({ "hjkl" }))
      H.eq(r.keys, "jjj")
    end,
  },
  {
    "cost counts keys, not commands (3kw, not 2k9b)",
    function()
      local r = solver.solve(move(lorem, { 5, 0 }, { 2, 4 }), H.learned(all_motions))
      H.eq(r.cost, 3)
    end,
  },
  {
    "curswant after $ is modelled",
    function()
      local t = move({ "abc", "abcdefgh" }, { 1, 0 }, { 2, 7 })
      H.ok(solver.check(t, { { keys = "$" }, { keys = "j" } }), "$ then j should reach the end of the longer line")
    end,
  },
  {
    "dt, deletes up to the comma",
    function()
      -- two words before the comma, so de alone is not enough
      local t = edit({ "call(one two, three);" }, { 1, 5 }, { "call(, three);" })
      local r = solver.solve(t, H.learned({ "hjkl", "wb", "e", "line", "d", "f", "t" }))
      H.eq(r.cost, 3) -- dt, and dfo both work
      H.ok(solver.check(t, r.tokens))
      -- with counts, d2e also ties at 3 keys; focus on t picks dt,
      local r2 = solver.solve(
        t,
        H.learned({ "hjkl", "wb", "e", "line", "count", "d", "f", "t" }),
        { focus = { { "d", "t" } } }
      )
      H.eq(r2.keys, "dt,")
    end,
  },
  {
    "change a word costs 6 (ce or cw + 3 letters + Esc)",
    function()
      local t = edit({ "foo zip qux" }, { 1, 4 }, { "foo bar qux" })
      local r = solver.solve(t, H.learned({ "hjkl", "wb", "e", "line", "count", "d", "c", "x", "ia" }))
      H.eq(r.cost, 6)
      H.ok(solver.check(t, r.tokens), "solution replays")
    end,
  },
  {
    "insert a missing word with i",
    function()
      local t = edit({ "the brown fox" }, { 1, 4 }, { "the quick brown fox" })
      local r = solver.solve(t, H.learned({ "hjkl", "ia" }))
      H.eq(r.display, "iquick␣<Esc>")
      H.eq(r.cost, 8)
    end,
  },
  {
    "append at line end with A",
    function()
      local t = edit({ "the brown" }, { 1, 0 }, { "the brown fox" })
      local r = solver.solve(t, H.learned({ "hjkl", "ia", "AI" }))
      H.eq(r.display, "A␣fox<Esc>")
    end,
  },
  {
    "dd deletes a line",
    function()
      local t = edit({ "a b", "c d", "e f" }, { 2, 0 }, { "a b", "e f" })
      local r = solver.solve(t, H.learned({ "hjkl", "lines" }))
      H.eq(r.keys, "dd")
    end,
  },
  {
    "smaller counts break ties: 2k…d$, not 09bd$ across lines",
    function()
      local t = edit(
        { "else gain key poem mail trip", "soft rope pink sort meal lady cash", "club girl food lock" },
        { 3, 18 },
        { "else gain key poem ", "soft rope pink sort meal lady cash", "club girl food lock" }
      )
      local r = solver.solve(t, H.learned({ "hjkl", "count", "wb", "e", "line", "d" }), { focus = { { "d" } } })
      H.eq(r.cost, 5)
      H.eq(r.keys:sub(1, 2), "2k", r.keys)
    end,
  },
  {
    "2x beats xx on ties (fewer commands)",
    function()
      local t = edit({ "the brxqown fox" }, { 1, 6 }, { "the brown fox" })
      local r = solver.solve(t, H.learned({ "hjkl", "x", "count" }))
      H.eq(r.keys, "2x")
      local r2 = solver.solve(t, H.learned({ "hjkl", "x" }))
      H.eq(r2.keys, "xx")
    end,
  },
  {
    "focus breaks ties toward the taught move",
    function()
      -- target is both 1 word and 5 cells away: w (1 key) wins anyway
      local t = move({ "abcd efgh" }, { 1, 0 }, { 1, 5 })
      local r = solver.solve(t, H.learned({ "hjkl", "wb" }), { focus = { { "wb" } } })
      H.eq(r.keys, "w")
      H.ok(r.focus)
    end,
  },
  {
    "alternatives include a solution without counts",
    function()
      local t = move({ "the quick brown fox jumps over" }, { 1, 0 }, { 1, 16 })
      local learned = H.learned(all_motions)
      local best = solver.solve(t, learned, { focus = { { "wb" } } })
      local alts = solver.alternatives(t, learned, best, { focus = { { "wb" } } })
      local found = false
      for _, a in ipairs(alts) do
        H.ok(solver.check(t, a.tokens), "alternative replays: " .. a.keys)
        H.ok(a.cost <= best.cost + 2)
        if a.keys == "www" then
          found = true
        end
      end
      H.ok(found, "expected www among " .. vim.inspect(vim.tbl_map(function(a)
        return a.keys
      end, alts)))
    end,
  },
  {
    "the solver leaves registers and the last f/t search alone",
    function()
      vim.fn.setreg('"', "mine")
      vim.fn.setreg("-", "small")
      vim.fn.setreg("1", "one")
      vim.fn.setcharsearch({ char = "z", forward = 1, ["until"] = 0 })
      local cb = vim.o.clipboard
      local t = edit({ "call(one two, three);" }, { 1, 5 }, { "call(, three);" })
      H.ok(solver.solve(t, H.learned({ "hjkl", "wb", "e", "line", "x", "d", "f", "t" })))
      H.eq(vim.fn.getreg('"'), "mine")
      H.eq(vim.fn.getreg("-"), "small")
      H.eq(vim.fn.getreg("1"), "one")
      H.eq(vim.fn.getcharsearch().char, "z")
      H.eq(vim.o.clipboard, cb)
    end,
  },
  {
    "unsolvable within the cost limit returns nil",
    function()
      local t = move(lorem, { 1, 0 }, { 6, 40 })
      H.eq(solver.solve(t, H.learned({ "hjkl" }), { max_cost = 4 }), nil)
    end,
  },
}
