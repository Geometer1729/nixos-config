local group = vim.api.nvim_create_augroup("auto-session-checkpoint", { clear = true })
local socket = vim.fn.stdpath("run") .. "/nvim-session-" .. vim.fn.getpid() .. ".sock"

pcall(vim.fn.serverstart, socket)

vim.api.nvim_create_autocmd({ "BufWritePost", "CursorHold", "CursorHoldI", "FocusLost" }, {
  group = group,
  callback = function()
    local has_file = vim.iter(vim.api.nvim_list_bufs()):any(function(buffer)
      return vim.bo[buffer].buflisted
        and vim.bo[buffer].buftype == ""
        and vim.api.nvim_buf_get_name(buffer) ~= ""
    end)

    if has_file then
      require("auto-session").save_session(nil, { show_message = false, is_autosave = true })
    end
  end,
})
