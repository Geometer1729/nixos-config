local g = vim.g
local o = vim.o

g.vimwiki_list = {
  { path = '~/Documents/vw/',
    syntax = 'markdown',
    ext = '.md',
    links_space_char= '_',
    auto_diary_index = 1
  },
  { path = '~/Documents/P1-wiki/',
    syntax = 'markdown',
    ext = '.md',
    links_space_char= '_',
  }
}

-- Don't conceal markdown in any mode
o.concealcursor=""
-- Tells task wiki not to break this
g.taskwiki_disable_concealcursor=1

-- Default used by `task` command
g.taskwiki_data_location="~/.local/share/task"

-- No folds
g.taskwiki_dont_fold="yes"
g.vimwiki_folding=''
g.foldenable=false
g.foldmethod="syntax"

vim.api.nvim_create_autocmd({'BufNewFile'},
  { pattern = '*Documents/vw/diary/*',
    command = [[silent :0r !cat ~/Documents/vw/templates/diary.md | sed "s/DATE/$(date '+\%m\/\%d\/\%y\ \%A')/g"]]
  })

function AddLinkToVimwikiIndex(template_name)
  -- Get the current buffer's name
  local current_file = vim.fn.expand('%:t:r')

  -- Create the link
  local title = current_file:gsub("%u", " %1"):sub(2)
  local link = string.format("* [%s](%s)", title, current_file)

  -- Find the Vimwiki index file
  local index_file = string.format('%s_index.md', template_name)

  -- Read the index file
  local lines = vim.fn.readfile(index_file)

  -- Add the new link to the end
  table.insert(lines, link)

  -- Write the updated content back to the index file
  vim.fn.writefile(lines, index_file)

  print("Link added to Vimwiki index")
end

local function ttrpg(in_table)
  local template_name = in_table["args"]
  local vim_command_text = string.format('silent 0read %s_template.md', template_name)
  vim.api.nvim_command(vim_command_text)
  local filename = vim.fn.fnamemodify(vim.fn.expand('%:t'), ':r')
  local title = filename:gsub("%u", " %1"):sub(2)
  vim.api.nvim_command('%s/HEADER/' .. title .. '/g')
  AddLinkToVimwikiIndex(template_name)
end

vim.api.nvim_create_user_command("TTRPG", ttrpg, {
				nargs = 1,
				desc = 'Automatically load ttrpg templates',
				complete = function(ArgLead, CmdLine, CursorPos)
					return {'place', 'people', 'bestiary' }
				end
				})
