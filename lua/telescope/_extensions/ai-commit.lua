local telescope = require("telescope")

local function setup_opts(opts)
  local themes = require("telescope.themes")
  opts = opts or {}
  if opts.theme == nil then
    opts = themes.get_dropdown(opts)
  end
  return opts
end

local function push_changes()
  local Job = require("plenary.job")

  vim.notify("Pushing changes...", vim.log.levels.INFO)
  Job:new({
    command = "git",
    args = { "push" },
    on_exit = function(_, return_val)
      if return_val == 0 then
        vim.notify("Changes pushed successfully!", vim.log.levels.INFO)
      else
        vim.notify("Failed to push changes", vim.log.levels.ERROR)
      end
    end,
  }):start()
end

local function commit_changes(message)
  if vim.bo.filetype == "gitcommit" then
    local lines = vim.split(message, "\n")
    vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
    vim.notify("Commit message pasted to buffer", vim.log.levels.INFO)
  else
    local Job = require("plenary.job")

    Job:new({
      command = "git",
      args = { "commit", "-m", message },
      on_exit = function(_, return_val)
        if return_val == 0 then
          vim.notify("Commit created successfully!", vim.log.levels.INFO)
          if require("ai-commit").config.auto_push then
            push_changes()
          end
        else
          vim.notify("Failed to create commit", vim.log.levels.ERROR)
        end
      end,
    }):start()
  end
end

local function create_commit_picker(opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  opts = setup_opts(opts)

  pickers
    .new(opts, {
      prompt_title = "AI Commit Messages",
      finder = finders.new_table({ results = opts.messages or {} }),
      previewer = false,
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection[1] then
            commit_changes(selection[1])
          else
            vim.notify("No commit message selected", vim.log.levels.WARN)
          end
        end)
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  exports = { commit = create_commit_picker },
})
