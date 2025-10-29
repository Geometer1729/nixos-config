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

-- Use treesitter highlighting instead of vimwiki syntax
-- Force treesitter for vimwiki files
vim.api.nvim_create_autocmd({'FileType'}, {
  pattern = 'vimwiki',
  callback = function()
    -- Disable vimwiki syntax and use treesitter markdown
    vim.cmd('syntax off')
    vim.treesitter.start()
  end
})

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


local function get_current_vimwiki_path()
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Check if vimwiki_list is available
  if not vim.g.vimwiki_list then
    print("Vimwiki configuration not found")
    return nil
  end

  -- Iterate through all configured Vimwikis
  for _, wiki in ipairs(vim.g.vimwiki_list) do
    local wiki_path = vim.fn.expand(wiki.path)
    if current_file:find(wiki_path, 1, true) then
      return current_file, wiki_path
    end
  end

  return nil
end

vim.g.vimwiki_tag_format = {
  pre = '^#+%s*',
  pre_mark = '',
  post_mark = '',
  sep = ''
}

local function link_current_heading()
  -- Get the current line number
  local current_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Search backwards for the nearest heading
  local heading = nil
  for i = current_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, i-1, i, false)[1]
    if line:match('^#+%s+') or (i < #vim.api.nvim_buf_get_lines(0, 0, -1, false) and vim.api.nvim_buf_get_lines(0, i, i+1, false)[1]:match('^[=-]+$')) then
      heading = line:gsub('^#+%s+', ''):gsub('%s+$', '')
      break
    end
  end

  if heading then
    -- Get the current file name without extension
    local file = vim.fn.expand('%:t:r')
    -- Create the link
    local link = '[' .. heading .. '](' .. file .. '#' .. heading .. ')'
    -- Put the link in the " register
    vim.fn.setreg('+', link)
    print('Link copied to clipboard: ' .. link)
  else
    print('No heading found above the cursor')
  end
end

-- Create a command to call the function
vim.api.nvim_create_user_command('LinkCurrentHeading', link_current_heading, {})

-- Create a key mapping (optional)
vim.keymap.set('n', '<Leader>lh', link_current_heading, { noremap = true, silent = true })

-- Function to convert snake_case to camelCase
local function to_camel_case(snake_str)
    return snake_str:gsub("_%a", function(match)
        return match:sub(2, 2):upper()
    end):gsub("_", "")
end

-- Function to recursively collect all child nodes of a given heading node
local function collect_heading_content(node, bufnr, heading_level)
    local lines_to_move = {}
    local start_row, _, end_row, _ = node:range()

    -- Add the current node's text (the heading itself)
    table.insert(lines_to_move, vim.treesitter.get_node_text(node, bufnr))

    -- Iterate over siblings after this node
    local sibling = node:next_sibling()
    while sibling do
        if sibling:type() == "atx_heading" then
            -- Check the level of the next heading
            local sibling_text = vim.treesitter.get_node_text(sibling, bufnr)
            local sibling_level = #sibling_text:match("^#+")
            if sibling_level <= heading_level then
                -- Stop if we encounter a sibling or higher-level heading
                break
            end
        end

        -- Add this sibling's text (if it's not a higher-level heading)
        table.insert(lines_to_move, vim.treesitter.get_node_text(sibling, bufnr))
        sibling = sibling:next_sibling()
    end

    return lines_to_move
end

-- Function to convert a string to camelCase
local function to_camel_case(str)
    return str:gsub("%s+", "_"):gsub("_(.)", function(c)
        return c:upper()
    end)
end

-- Main function to move a heading and its subheadings into a new file
local function move_heading_to_new_file()
    -- Get the current buffer and cursor position
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

    -- Get the current line (assume it's a heading)
    local current_line = vim.fn.getline(cursor_row)
    local heading_level = current_line:match("^(#+)")
    if not heading_level then
        print("No Markdown heading found at cursor!")
        return
    end

    -- Extract the title from the heading (e.g., "# My Title" -> "My Title")
    local title = current_line:match("^#+%s*(.+)")
    if not title then
        print("Failed to extract heading text!")
        return
    end

    -- Format the filename in camelCase
    local filename = to_camel_case(title) .. ".md"

    -- Collect lines for this heading and its subheadings
    local lines_to_move = { current_line }
    local total_lines = vim.api.nvim_buf_line_count(bufnr)
    for i = cursor_row + 1, total_lines do
        local line = vim.fn.getline(i)

        -- Stop if we encounter another heading of the same or higher level
        if line:match("^#+") then
            local next_heading_level = line:match("^(#+)")
            if #next_heading_level <= #heading_level then
                break
            end
        end

        table.insert(lines_to_move, line)
    end

    local original_bufnr = bufnr
    -- Write the collected lines into a new file
    vim.cmd("silent! edit " .. filename)
    vim.api.nvim_buf_set_lines(0, 0, 0, false, lines_to_move)
    vim.cmd("silent! write")

    -- Return to the original buffer and replace the heading with a Markdown link
    vim.cmd("buffer" .. original_bufnr)
    local link = string.format("[%s](%s)", title, filename)
    vim.api.nvim_buf_set_lines(bufnr, cursor_row - 1, cursor_row + #lines_to_move - 1, false, { link })

    print("Heading and subheadings moved to new file: " .. filename)
end

-- Map the function to a keybinding (e.g., <Leader>sh)
vim.keymap.set("n", "<Leader>sh", move_heading_to_new_file, { noremap = true, silent = true })
vim.keymap.set("n", "<Leader>vl", vim.cmd.VimwikiVSplitLink)

-- Task management integration

-- Function to convert heading text to anchor slug
local function heading_to_anchor(heading_text)
  -- Remove markdown heading markers and trim
  local clean = heading_text:gsub('^#+%s+', ''):gsub('%s+$', '')
  -- Convert to lowercase and replace spaces with hyphens
  local anchor = clean:lower():gsub('[%s_]+', '-')
  -- Remove any characters that aren't alphanumeric or hyphens
  anchor = anchor:gsub('[^%w%-]', '')
  return anchor
end

-- Function to get current heading and its info
local function get_heading_info()
  local current_line_num = vim.api.nvim_win_get_cursor(0)[1]

  -- Search backwards for the nearest heading
  local heading_text = nil
  for i = current_line_num, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, i-1, i, false)[1]
    if line:match('^#+%s+') then
      heading_text = line:gsub('^#+%s+', ''):gsub('%s+$', '')
      break
    end
  end

  if not heading_text then
    return nil
  end

  -- Get file path relative to wiki root
  local current_file, wiki_path = get_current_vimwiki_path()
  if not current_file or not wiki_path then
    print("Not in a vimwiki directory")
    return nil
  end

  -- Strip leading slash if present and calculate path relative to tasks/ directory
  local relative_to_wiki = current_file:sub(#wiki_path + 1)
  if relative_to_wiki:sub(1, 1) == '/' then
    relative_to_wiki = relative_to_wiki:sub(2)
  end

  -- Since redirect files are in tasks/ subdirectory, we need to go up one level
  local relative_path = '../' .. relative_to_wiki
  local anchor = heading_to_anchor(heading_text)

  return {
    heading = heading_text,
    file_path = relative_path,
    anchor = anchor
  }
end

-- Function to create a task from current heading
local function create_task_from_heading()
  local info = get_heading_info()
  if not info then
    print("No heading found above cursor")
    return
  end

  -- Call the shell script
  local cmd = string.format(
    'create-task-from-heading %s %s %s',
    vim.fn.shellescape(info.heading),
    vim.fn.shellescape(info.file_path),
    vim.fn.shellescape(info.anchor)
  )

  local result = vim.fn.system(cmd)
  print(result)
end

-- Function to update an existing task to point to current heading
local function update_task_to_heading()
  local info = get_heading_info()
  if not info then
    print("No heading found above cursor")
    return
  end

  -- Use vim terminal to run fzf interactively
  local cmd = string.format(
    'update-task-link %s %s',
    vim.fn.shellescape(info.file_path),
    vim.fn.shellescape(info.anchor)
  )

  -- Open in a split terminal
  vim.cmd('split | terminal ' .. cmd)
  -- Auto-close terminal when command finishes
  vim.cmd('autocmd TermClose <buffer> quit')
end

-- Create commands
vim.api.nvim_create_user_command('TaskFromHeading', create_task_from_heading, {})
vim.api.nvim_create_user_command('TaskUpdateLink', update_task_to_heading, {})

-- Create keybindings
vim.keymap.set('n', '<Leader>tc', create_task_from_heading, { noremap = true, silent = true, desc = 'Create task from current heading' })
vim.keymap.set('n', '<Leader>tu', update_task_to_heading, { noremap = true, silent = true, desc = 'Update task link to current heading' })
