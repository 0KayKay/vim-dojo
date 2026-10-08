-- World bosses (SPEC §4, docs/decisions/0009). Bosses teach nothing new; the
-- session builds their rounds from the world's stages (mixed rounds and chains).
local M = {}

-- "which move when", after hardtime.nvim's recommended workflow
local guides = {
  {
    { "lines up / down", "a count and j k: 4j" },
    { "a few cells", "h l, or 3l" },
    { "stray letters", "x, 3x" },
    { "missing text here", "i a" },
    { "missing at a line end", "A I, from anywhere on the line" },
  },
  {
    { "lines up / down", "a count and j k: 4j" },
    { "a few cells", "h l" },
    { "word starts", "w b, 3w" },
    { "word ends", "e" },
    { "line edges", "0 ^ $" },
  },
  {
    { "delete", "d + any motion: dw d$ d2e" },
    { "change", "c + any motion, then type" },
    { "whole lines", "dd 3dd cc dj" },
    { "getting there", "4j, w b e, 0 ^ $" },
  },
  {
    { "lines up / down", "a count and j k" },
    { "a few cells", "h l" },
    { "word starts / ends", "w b e" },
    { "line edges", "0 ^ $" },
    { "one character", "f F onto it, t T next to it" },
    { "with operators", "dt, df) ct;" },
  },
}

-- w: world number; world: { name, boss }; next_name: the next world's name or nil
function M.make(w, world, next_name)
  local tip
  if next_name then
    tip = string.format(
      "Beat it to open World %d: %s. You can try it any time to skip the rest of this world.",
      w + 1,
      next_name
    )
  else
    tip = "The last boss. Beat it to finish the prototype; replay any stage to raise its stars."
  end
  return {
    key = world.boss,
    title = "Boss",
    name = "Mixes and chains",
    kind = "boss",
    is_boss = true,
    adds = {},
    focus = nil,
    explainer = {
      heading = string.format("World %d: %s", w, world.name),
      keys = {
        { "rounds 1-6", "mixed: at least two different moves in each" },
        { "rounds 7-10", "chains of 2-3 steps, one highlighted at a time" },
        { "every round", "needs a move from this world" },
      },
      guide = guides[w],
      tip = tip,
    },
  }
end

return M
