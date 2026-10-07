-- Seeded random numbers (Park–Miller), independent of math.random so that a
-- round can be reproduced from its seed.
local Rng = {}
Rng.__index = Rng

local MOD = 2147483647

function Rng.new(seed)
  local s = math.floor(tonumber(seed) or 1) % MOD
  if s <= 0 then
    s = s + MOD - 1
  end
  return setmetatable({ s = s }, Rng)
end

function Rng:next()
  self.s = (self.s * 48271) % MOD
  return self.s
end

-- float in [0, 1)
function Rng:float()
  return (self:next() - 1) / (MOD - 1)
end

-- integer in [a, b]
function Rng:int(a, b)
  return a + math.floor(self:float() * (b - a + 1))
end

function Rng:pick(list)
  return list[self:int(1, #list)]
end

function Rng:chance(p)
  return self:float() < p
end

function Rng:shuffle(list)
  for i = #list, 2, -1 do
    local j = self:int(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

-- a fresh seed derived from this generator
function Rng:seed()
  return self:int(1, MOD - 2)
end

return Rng
