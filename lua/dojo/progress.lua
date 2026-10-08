-- Saved progress (SPEC.md §9 Saved data): progress.json and rounds.jsonl in
-- stdpath("data")/dojo, or config.data_dir.
local config = require("dojo.config")
local curriculum = require("dojo.curriculum")

local M = {}
local data

local function dir()
  return config.get().data_dir or (vim.fn.stdpath("data") .. "/dojo")
end

local function path(name)
  return dir() .. "/" .. name
end

local function fresh()
  return { version = 2, stages = vim.empty_dict(), settings = { habit = config.get().habit.enabled } }
end

-- version 1 saved stages by display number (docs/decisions/0010)
M.V1_KEYS = {
  ["1.1"] = "hjkl",
  ["1.2"] = "x",
  ["1.3"] = "insert",
  ["1.4"] = "append",
  ["2.1"] = "word",
  ["2.2"] = "word_end",
  ["2.3"] = "line_edges",
  ["2.4"] = "counts",
  ["3.1"] = "delete",
  ["3.2"] = "lines",
  ["3.3"] = "change",
  ["4.1"] = "find",
  ["4.2"] = "till",
}

-- version 1's order, to tell which stages were open
local V1_ORDER = { "1.1", "1.2", "1.3", "1.4", "2.1", "2.2", "2.3", "2.4", "3.1", "3.2", "3.3", "4.1", "4.2", "4.3" }

local function migrate_v1(decoded)
  local old = decoded.stages or {}
  local stages = vim.empty_dict()
  for id, st in pairs(old) do
    local key = M.V1_KEYS[id]
    if key and type(st) == "table" then
      stages[key] = st
    end
  end
  -- v1 opened a stage once the one before it had a star; keep those open
  -- even where a boss now sits in between (decision 0010)
  for i, id in ipairs(V1_ORDER) do
    local key = M.V1_KEYS[id]
    local prev = old[V1_ORDER[i - 1]]
    if key and (i == 1 or (type(prev) == "table" and (prev.best_stars or 0) >= 1)) then
      stages[key] = stages[key]
        or { explainer_seen = false, drill_done = false, best_stars = 0, best_score = 0, attempts = 0 }
      stages[key].opened = true
    end
  end
  -- habit mode is on by default from version 2 on (decision 0011)
  return stages, { habit = true }
end

function M.load()
  if data then
    return data
  end
  data = fresh()
  local f = io.open(path("progress.json"), "r")
  if f then
    local raw = f:read("*a")
    f:close()
    local ok, decoded = pcall(vim.json.decode, raw)
    if ok and type(decoded) == "table" then
      if (decoded.version or 1) < 2 then
        data.stages, data.settings = migrate_v1(decoded)
        data.migrated = true
        M.save()
      else
        data.stages = decoded.stages or vim.empty_dict()
        data.settings = vim.tbl_extend("force", data.settings, decoded.settings or {})
      end
    end
  end
  return data
end

function M.save()
  local d = M.load()
  vim.fn.mkdir(dir(), "p")
  local tmp = path("progress.json.tmp")
  local f = assert(io.open(tmp, "w"))
  f:write(vim.json.encode({ version = 2, stages = d.stages, settings = d.settings }))
  f:close()
  vim.uv.fs_rename(tmp, path("progress.json")) -- replaces the old file, on Windows too
end

-- forget the cached copy (tests, or after the data dir changes)
function M.reset()
  data = nil
end

-- delete saved progress and the round log (tests)
function M.wipe()
  data = nil
  os.remove(path("progress.json"))
  os.remove(path("rounds.jsonl"))
end

function M.stage(id)
  local d = M.load()
  local s = d.stages[id]
  if not s then
    s = { explainer_seen = false, drill_done = false, best_stars = 0, best_score = 0, attempts = 0 }
    d.stages[id] = s
  end
  return s
end

local function passed(key)
  return M.stage(key).best_stars >= 1
end

-- SPEC §9 Unlock rules: the first stage; after a passed entry; a stage that
-- has a star itself or was open in a version 1 save; every stage of a world
-- whose boss is beaten (skip ahead). A boss opens with its world's first stage.
function M.unlocked(key)
  local st = curriculum.get(key)
  if st.is_boss then
    return M.unlocked(curriculum.world_first(st.world))
  end
  local prev = curriculum.prev(key)
  return prev == nil
    or passed(key)
    or passed(prev)
    or M.stage(key).opened == true -- open in a version 1 save
    or passed(curriculum.world_boss(st.world))
end

function M.mark_explainer(id)
  M.stage(id).explainer_seen = true
  M.save()
end

function M.record_drill(id)
  local s = M.stage(id)
  s.drill_done = true
  s.explainer_seen = true
  M.save()
end

-- summary from score.summary(); returns true when this is a new best
function M.record_challenge(id, summary)
  local s = M.stage(id)
  s.attempts = s.attempts + 1
  local best = summary.stars > s.best_stars or (summary.stars == s.best_stars and summary.score > s.best_score)
  if best then
    s.best_stars = summary.stars
    s.best_score = summary.score
  end
  M.save()
  return best
end

function M.total_stars()
  local total = 0
  for _, id in ipairs(curriculum.order) do
    total = total + M.stage(id).best_stars
  end
  return total, #curriculum.order * 3
end

function M.setting(name, value)
  local d = M.load()
  if value ~= nil then
    d.settings[name] = value
    M.save()
  end
  return d.settings[name]
end

function M.log_round(entry)
  vim.fn.mkdir(dir(), "p")
  local f = io.open(path("rounds.jsonl"), "a")
  if f then
    f:write(vim.json.encode(entry) .. "\n")
    f:close()
  end
end

M.dir = dir

return M
