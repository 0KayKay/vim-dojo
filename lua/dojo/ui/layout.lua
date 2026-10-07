-- The game's tab page: one main window that shows the menu, explainer,
-- summary or play buffer, and a header window above it during rounds.
local config = require("dojo.config")

local M = {}

local state = { tab = nil, win = nil, hud = nil, bufs = {} }
local group = vim.api.nvim_create_augroup("dojo.layout", { clear = true })

local function valid_win(w)
  return w and vim.api.nvim_win_is_valid(w)
end

-- window options are set locally, so nothing leaks into the user's windows
local function wset(win, name, value)
  vim.api.nvim_set_option_value(name, value, { win = win, scope = "local" })
end

function M.buf(name)
  local b = state.bufs[name]
  if b and vim.api.nvim_buf_is_valid(b) then
    return b
  end
  b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "hide"
  vim.bo[b].buftype = "nofile"
  vim.bo[b].swapfile = false
  if name ~= "play" then
    vim.bo[b].modifiable = false
  end
  pcall(vim.api.nvim_buf_set_name, b, "dojo://" .. name)
  state.bufs[name] = b
  if name == "play" then
    require("dojo.round").prepare_buffer(b)
  end
  return b
end

local function window_options(win, play)
  wset(win, "number", play)
  wset(win, "relativenumber", play)
  wset(win, "cursorline", not play)
  wset(win, "wrap", false)
  wset(win, "list", false)
  wset(win, "signcolumn", "no")
  wset(win, "foldcolumn", "0")
  wset(win, "foldenable", false)
  wset(win, "spell", false)
  wset(win, "colorcolumn", "")
  wset(win, "statuscolumn", "")
  wset(win, "statusline", " Vim Dojo")
end

function M.open()
  if valid_win(state.win) then
    if vim.api.nvim_get_current_win() ~= state.win then
      vim.api.nvim_set_current_win(state.win)
    end
    return state.win
  end
  local reuse = config.get().quit_on_close
    and #vim.api.nvim_list_wins() == 1
    and vim.api.nvim_buf_get_name(0) == ""
    and not vim.bo.modified
    and vim.api.nvim_buf_line_count(0) <= 1
  if not reuse then
    vim.cmd("tabnew")
  end
  state.tab = vim.api.nvim_get_current_tabpage()
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_clear_autocmds({ group = group })
  -- the header window is never the place to type
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if state.hud and vim.api.nvim_get_current_win() == state.hud and valid_win(state.win) then
        vim.schedule(function()
          if valid_win(state.win) then
            vim.api.nvim_set_current_win(state.win)
          end
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(state.win),
    callback = function()
      require("dojo.session").abort()
      state.win = nil
      vim.schedule(M.close_hud)
    end,
  })
  return state.win
end

-- show a named buffer in the main window
function M.show(name, opts)
  local win = M.open()
  local b = M.buf(name)
  vim.api.nvim_win_set_buf(win, b)
  window_options(win, opts and opts.play or false)
  return b, win
end

function M.play()
  return M.show("play", { play = true })
end

function M.open_hud()
  if valid_win(state.hud) then
    return state.hud
  end
  local hb = M.buf("hud")
  state.hud = vim.api.nvim_open_win(hb, false, { split = "above", win = state.win, height = 4 })
  local w = state.hud
  wset(w, "number", false)
  wset(w, "relativenumber", false)
  wset(w, "cursorline", false)
  wset(w, "wrap", false)
  wset(w, "list", false)
  wset(w, "signcolumn", "no")
  wset(w, "foldcolumn", "0")
  wset(w, "statuscolumn", "")
  wset(w, "winfixheight", true)
  wset(w, "statusline", " ")
  return w
end

function M.hud_width()
  if valid_win(state.hud) then
    return vim.api.nvim_win_get_width(state.hud)
  end
  return vim.o.columns
end

function M.close_hud()
  if valid_win(state.hud) then
    pcall(vim.api.nvim_win_close, state.hud, true)
  end
  state.hud = nil
end

-- leave the game
function M.close()
  require("dojo.session").abort()
  M.close_hud()
  if config.get().quit_on_close then
    vim.cmd("qa!")
    return
  end
  local tab = state.tab
  state.win, state.tab = nil, nil
  vim.api.nvim_clear_autocmds({ group = group })
  if tab and vim.api.nvim_tabpage_is_valid(tab) then
    if #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(tab))
    else
      vim.cmd("enew")
    end
  end
end

function M.main_win()
  return state.win
end

return M
