-- Word list and line builders for round text. Words are lowercase letters only,
-- so word motions behave the same as WORD motions on prose lines.
local M = {}

M.list = {
  "able", "acid", "aged", "also", "area", "army", "away", "baby", "back", "ball",
  "band", "bank", "base", "bath", "bear", "beat", "been", "bell", "belt", "best",
  "bird", "blow", "blue", "boat", "body", "bold", "bone", "book", "born", "both",
  "bowl", "bulk", "burn", "bush", "busy", "cake", "calm", "came", "camp", "card",
  "care", "cart", "case", "cash", "cast", "cell", "chat", "chip", "city", "clay",
  "club", "coal", "coat", "code", "cold", "cook", "cool", "cope", "copy", "core",
  "corn", "cost", "crew", "crop", "dark", "data", "dawn", "deal", "dear", "deep",
  "desk", "dial", "diet", "disk", "dock", "door", "dose", "down", "draw", "drop",
  "drum", "duck", "dust", "duty", "each", "earn", "east", "easy", "edge", "else",
  "even", "ever", "face", "fact", "fair", "fall", "farm", "fast", "fear", "feel",
  "film", "find", "fine", "fire", "firm", "fish", "flag", "flat", "flow", "fold",
  "folk", "food", "foot", "form", "fork", "free", "frog", "fuel", "full", "fund",
  "gain", "game", "gate", "gift", "girl", "glad", "glow", "goal", "gold", "golf",
  "good", "grab", "gray", "grid", "grow", "gulf", "hair", "half", "hall", "hand",
  "hang", "hard", "harm", "hat", "head", "heal", "heat", "help", "herb", "hero",
  "hill", "hint", "hold", "hole", "home", "hook", "hope", "horn", "host", "hour",
  "huge", "hunt", "idea", "inch", "iron", "item", "jazz", "join", "jump", "jury",
  "keen", "keep", "kick", "kind", "king", "kite", "knee", "knot", "lady", "lake",
  "lamp", "land", "lane", "last", "late", "lead", "leaf", "lean", "left", "lens",
  "life", "lift", "like", "line", "link", "lion", "list", "load", "loan", "lock",
  "logo", "long", "loop", "lord", "loud", "love", "luck", "made", "mail", "main",
  "make", "mark", "mask", "meal", "melt", "menu", "mild", "milk", "mind", "mint",
  "mode", "mood", "moon", "most", "move", "much", "nail", "name", "navy", "near",
  "neat", "neck", "nest", "news", "nice", "node", "nose", "note", "oven", "pace",
  "pack", "page", "pain", "pair", "palm", "park", "part", "path", "peak", "pear",
  "pick", "pine", "pink", "pipe", "plan", "play", "plot", "plug", "poem", "pole",
  "pond", "pool", "port", "pour", "pull", "pure", "push", "race", "rail", "rain",
  "rank", "rare", "read", "real", "rest", "rice", "rich", "ride", "ring", "rise",
  "road", "rock", "role", "roof", "room", "root", "rope", "rose", "rule", "rush",
  "safe", "sail", "salt", "sand", "save", "seat", "seed", "self", "ship", "shop",
  "silk", "sing", "sink", "site", "size", "skin", "slow", "snow", "soap", "sock",
  "soft", "soil", "song", "sort", "soup", "spin", "spot", "star", "stem", "step",
  "swim", "tail", "tale", "tank", "tape", "task", "team", "tent", "test", "text",
  "tide", "tile", "time", "tiny", "tone", "tool", "tour", "town", "tree", "trip",
  "tune", "turn", "twin", "type", "unit", "user", "vast", "view", "vote", "wage",
  "wait", "walk", "wall", "warm", "wave", "weak", "wear", "week", "well", "west",
  "wide", "wild", "wind", "wine", "wing", "wire", "wise", "wish", "wolf", "wood",
  "wool", "word", "work", "yard", "year", "zone",
  "sun", "sky", "sea", "red", "map", "cup", "pen", "box", "key", "owl",
  "apple", "brave", "chair", "dance", "eagle", "flame", "grape", "house", "juice",
  "lemon", "magic", "night", "ocean", "piano", "quiet", "river", "stone", "tiger",
  "uncle", "voice", "water", "young", "zebra", "bread", "cloud", "dream", "field",
  "green", "heart", "light", "money", "music", "paper", "plant", "sheep", "smile",
  "sound", "storm", "sugar", "table", "train", "world",
}

-- distinct random words
function M.pick(rng, n, opts)
  opts = opts or {}
  local max_len = opts.max_len or 99
  local min_len = opts.min_len or 1
  local used, out = {}, {}
  if opts.avoid then
    for _, w in ipairs(opts.avoid) do
      used[w] = true
    end
  end
  local guard = 0
  while #out < n and guard < 2000 do
    guard = guard + 1
    local w = rng:pick(M.list)
    if not used[w] and #w <= max_len and #w >= min_len then
      used[w] = true
      out[#out + 1] = w
    end
  end
  return out
end

function M.line(rng, n, opts)
  return table.concat(M.pick(rng, n, opts), " ")
end

-- several prose lines with distinct words across all lines
function M.lines(rng, count, words_min, words_max)
  local lines, used = {}, {}
  for i = 1, count do
    local ws = M.pick(rng, rng:int(words_min, words_max), { avoid = used })
    for _, w in ipairs(ws) do
      used[#used + 1] = w
    end
    lines[i] = table.concat(ws, " ")
  end
  return lines
end

-- Code-like lines with punctuation for the find stages.
local templates = {
  "%s(%s, %s);",
  "local %s = %s.%s(%s)",
  "if (%s > %s) %s();",
  "%s[%s] = \"%s\";",
  "return %s(%s) + %s;",
  "print(\"%s, %s!\")",
  "%s = {%s, %s, %s}",
  "call(%s.%s, %s);",
  "%s: %s, %s; %s",
}

function M.code_line(rng, opts)
  opts = opts or {}
  local tpl = opts.template or rng:pick(templates)
  local n = select(2, tpl:gsub("%%s", ""))
  local ws = M.pick(rng, n, { avoid = opts.avoid })
  return string.format(tpl, unpack(ws))
end

M.templates = templates

return M
