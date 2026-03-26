local telescope = require "telescope"

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------

local function setup_opts(opts)
  opts = opts or {}
  opts.layout_strategy = "horizontal"
  opts.layout_config = opts.layout_config or { width = 0.7 }
  return opts
end

---------------------------------------------------------------------------
-- Commit picker
---------------------------------------------------------------------------

local function push_changes()
  local Job = require "plenary.job"

  vim.notify("Pushing changes...", vim.log.levels.INFO)
  Job:new({
    command = "git",
    args = { "push" },
    on_exit = function(_, return_val)
      vim.schedule(function()
        if return_val == 0 then
          vim.notify("Changes pushed successfully!", vim.log.levels.INFO)
        else
          vim.notify("Failed to push changes", vim.log.levels.ERROR)
        end
      end)
    end,
  }):start()
end

local function commit_changes(message)
  if vim.bo.filetype == "gitcommit" then
    local lines = vim.split(message, "\n")
    vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
    vim.notify("Commit message pasted to buffer", vim.log.levels.INFO)
  else
    local Job = require "plenary.job"

    Job:new({
      command = "git",
      args = { "commit", "-m", message },
      on_exit = function(_, return_val)
        vim.schedule(function()
          if return_val == 0 then
            vim.notify("Commit created successfully!", vim.log.levels.INFO)
            if require("ai-commit").config.auto_push then
              push_changes()
            end
          else
            vim.notify("Failed to create commit", vim.log.levels.ERROR)
          end
        end)
      end,
    }):start()
  end
end

local function create_commit_picker(opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local previewers = require "telescope.previewers"

  opts = setup_opts(opts)
  local messages = opts.messages or {}

  local entry_maker = function(msg)
    local subject = vim.split(msg, "\n")[1] or msg
    return {
      value = msg,
      display = subject,
      ordinal = subject,
    }
  end

  pickers
    .new(opts, {
      prompt_title = "AI Commit Messages",
      finder = finders.new_table {
        results = messages,
        entry_maker = entry_maker,
      },
      previewer = previewers.new_buffer_previewer {
        title = "Commit Message",
        define_preview = function(self, entry)
          local lines = vim.split(entry.value, "\n")
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "gitcommit")
          vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
          vim.schedule(function()
            local win = self.state.winid
            if win and vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_set_option(win, "wrap", true)
              vim.api.nvim_win_set_option(win, "linebreak", true)
            end
          end)
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value then
            commit_changes(selection.value)
          else
            vim.notify("No commit message selected", vim.log.levels.WARN)
          end
        end)
        return true
      end,
    })
    :find()
end

---------------------------------------------------------------------------
-- Model picker
---------------------------------------------------------------------------

local function create_model_picker(opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local previewers = require "telescope.previewers"

  opts = setup_opts(opts)

  local provider_name = opts.provider or require("ai-commit").config.provider
  local current_model = opts.current_model or require("ai-commit").config.model
  local models = require("ai-provider").get_models(provider_name)

  if #models == 0 then
    vim.notify("No models found for provider: " .. provider_name, vim.log.levels.WARN)
    return
  end

  local entry_maker = function(model)
    local is_active = model.id == current_model
    local icon = is_active and "● " or "  "
    local display = icon .. model.name .. "  (" .. model.id .. ")"
    return {
      value = model,
      display = display,
      ordinal = model.name .. " " .. model.id,
    }
  end

  pickers
    .new(opts, {
      prompt_title = "AI Models (" .. provider_name .. ")",
      finder = finders.new_table {
        results = models,
        entry_maker = entry_maker,
      },
      previewer = previewers.new_buffer_previewer {
        title = "Model Details",
        define_preview = function(self, entry)
          local model = entry.value
          local is_active = model.id == current_model
          local lines = {
            "Model: " .. model.name,
            "ID: " .. model.id,
            "Provider: " .. model.provider,
            "",
            "Context Window: " .. string.format("%s tokens", vim.fn.printf("%'d", model.context_window)),
            "Max Output: " .. string.format("%s tokens", vim.fn.printf("%'d", model.max_tokens)),
            "",
            is_active and "✓ Currently active" or "Press <Enter> to select",
          }
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value then
            local model = selection.value
            require("ai-commit").set_model(model.id)
            vim.notify("Model set to: " .. model.name .. " (" .. model.id .. ")", vim.log.levels.INFO)
          end
        end)
        return true
      end,
    })
    :find()
end

---------------------------------------------------------------------------
-- Extension registration
---------------------------------------------------------------------------

return telescope.register_extension {
  exports = {
    commit = create_commit_picker,
    models = create_model_picker,
  },
}
