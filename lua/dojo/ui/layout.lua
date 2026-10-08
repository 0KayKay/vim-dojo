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

-- status: the key help for this screen, shown in the window's status line
local function window_options(win, play, status)
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
  wset(win, "fillchars", "eob: ") -- no ~ below short screens
  -- '%' starts a statusline item; key help is plain text
  local text = (status or " Vim Dojo"):gsub("%%", "%%%%")
  wset(win, "statusline", text)
end

function M.open()
  -- never switch windows here: timers call this too (next round, summary),
  -- and the player may be in another tab. Only focus() moves the cursor.
  if valid_win(state.win) then
    return state.win
  end
  local reuse = config.get().quit_on_close
    and #vim.api.nvim_list_wins() == 1
    and vim.api.nvim_buf_get_name(0) == ""
    and not vim.bo.modified
    and vim.api.nvim_buf_line_count(0) <= 1
  if not reuse then
    vim.cmd("tabnew")
    state.wipe = vim.api.nvim_get_current_buf() -- tabnew's empty buffer
  end
  state.tab = vim.api.nvim_get_current_tabpage()
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_clear_autocmds({ group = group })
  -- leaving the game tab stops the round; the clock must not run unseen
  vim.api.nvim_create_autocmd("TabLeave", {
    group = group,
    callback = function()
      if vim.api.nvim_get_current_tabpage() == state.tab and require("dojo.session").current() then
        vim.schedule(function()
          require("dojo.session").abort()
          if valid_win(state.win) then
            require("dojo.ui.menu").show()
          end
        end)
      end
    end,
  })
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
  M.watch(state.win)
  return state.win
end

-- When the main window closes (:q, <C-w>c), stop the round. If the header
-- window is still there, it becomes the main window and shows the menu, so :q
-- during a round means "back to the menu".
function M.watch(win)
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    once = true,
    callback = function()
      local hud = state.hud
      state.win, state.hud = nil, nil
      require("dojo.round").abort()
      vim.schedule(function()
        require("dojo.session").abort()
        if valid_win(hud) then
          state.win = hud
          wset(hud, "winfixheight", false)
          M.watch(hud)
          require("dojo.ui.menu").show()
        end
      end)
    end,
  })
end

-- open the game if needed and put the cursor in it (user commands only)
function M.focus()
  local win = M.open()
  if vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_set_current_win(win)
  end
  return win
end

-- show a named buffer in the main window; opts.play for the play buffer,
-- opts.status for the key help in the status line
function M.show(name, opts)
  opts = opts or {}
  local win = M.open()
  local b = M.buf(name)
  vim.api.nvim_win_set_buf(win, b)
  window_options(win, opts.play or false, opts.status)
  vim.cmd('echo ""') -- a message from the last screen does not belong here
  local w = state.wipe
  if w and vim.api.nvim_buf_is_valid(w) and #vim.fn.win_findbuf(w) == 0 and not vim.bo[w].modified then
    pcall(vim.api.nvim_buf_delete, w, { force = true })
  end
  state.wipe = nil
  return b, win
end

function M.play()
  return M.show("play", { play = true, status = " <Tab> hint   :q menu" })
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
