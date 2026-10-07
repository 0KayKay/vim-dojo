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
  return { version = 1, stages = vim.empty_dict(), settings = { habit = config.get().habit.enabled } }
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
      data.stages = decoded.stages or vim.empty_dict()
      data.settings = vim.tbl_extend("force", data.settings, decoded.settings or {})
    end
  end
  return data
end

function M.save()
  local d = M.load()
  vim.fn.mkdir(dir(), "p")
  local tmp = path("progress.json.tmp")
  local f = assert(io.open(tmp, "w"))
  f:write(vim.json.encode(d))
  f:close()
  os.rename(tmp, path("progress.json"))
end

-- forget the cached copy (tests, or after the data dir changes)
function M.reset()
  data = nil
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

function M.unlocked(id)
  local prev = curriculum.prev(id)
  return prev == nil or M.stage(prev).best_stars >= 1
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
