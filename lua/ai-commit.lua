local M = {}

M.config = {
  provider = "openrouter",
  model = "google/gemini-2.5-flash",
  auto_push = false,
  commit_prompt_template = nil,
  system_prompt = nil,
  ignored_files = {},
  debug = false,
  max_tokens = 4096,
  max_diff_length = nil,
}

M.last_commit_messages = nil

---------------------------------------------------------------------------
-- Model persistence
---------------------------------------------------------------------------

local function get_model_save_path()
  return vim.fn.stdpath "data" .. "/ai-commit/model_selection.json"
end

--- Load the persisted model selection from disk.
--- Returns { provider = "…", model = "…" } or nil.
local function load_saved_model()
  local path = get_model_save_path()
  local file = io.open(path, "r")

  if not file then
    return nil
  end

  local content = file:read "*a"
  file:close()

  local ok, data = pcall(vim.json.decode, content)

  if ok and data and data.provider and data.model then
    return data
  end

  return nil
end

--- Persist the current provider + model to disk.
function M.save_model_selection()
  local path = get_model_save_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local file = io.open(path, "w")

  if file then
    file:write(vim.json.encode { provider = M.config.provider, model = M.config.model })
    file:close()
  end
end

--- Apply a model selection – updates runtime config and saves to disk.
function M.set_model(model_id)
  M.config.model = model_id
  M.save_model_selection()
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  -- Forward provider-specific settings to ai-provider if supplied.
  if opts and opts.provider_config then
    require("ai-provider").setup { providers = opts.provider_config }
  end

  -- Restore previously picked model (only if provider still matches).
  local saved = load_saved_model()

  if saved and saved.provider == M.config.provider then
    M.config.model = saved.model
  end
end

M.generate_commit = function(extra_prompt)
  require("commit_generator").generate_commit(M.config, extra_prompt)
end

--- Generate commit messages from an explicit diff (for integration with other plugins).
--- @param diff_text string The diff to generate messages for
--- @param opts? table { extra_prompt?: string, on_select?: fun(message: string), on_result?: fun(messages: string[]|nil, err: string|nil), show_picker?: boolean }
M.generate_commit_for_diff = function(diff_text, opts)
  require("commit_generator").generate_for_diff(M.config, diff_text, opts)
end

--- Generate commit messages from an explicit diff without opening Telescope.
--- @param diff_text string The diff to generate messages for
--- @param opts? table { extra_prompt?: string }
--- @param callback fun(messages: string[]|nil, err: string|nil)
M.generate_commit_messages_for_diff = function(diff_text, opts, callback)
  opts = opts or {}
  opts.show_picker = false
  opts.on_result = callback
  require("commit_generator").generate_for_diff(M.config, diff_text, opts)
end

M.show_commit_suggestions = function(messages, opts)
  M.last_commit_messages = messages

  local has_telescope, _ = pcall(require, "telescope")

  if not has_telescope then
    error "This plugin requires nvim-telescope/telescope.nvim"
  end

  require("telescope").extensions["ai-commit"].commit {
    messages = messages,
    on_select = opts and opts.on_select or nil,
  }
end

M.show_last_commit_suggestions = function()
  if M.last_commit_messages and #M.last_commit_messages > 0 then
    M.show_commit_suggestions(M.last_commit_messages)
  else
    vim.notify("No AI commit messages have been generated in this session.", vim.log.levels.WARN)
  end
end

--- Open a Telescope picker with models for the current (or given) provider.
M.show_model_picker = function(provider_name)
  provider_name = provider_name or M.config.provider

  local has_telescope, _ = pcall(require, "telescope")
  if not has_telescope then
    error "This plugin requires nvim-telescope/telescope.nvim"
  end

  require("telescope").extensions["ai-commit"].models {
    provider = provider_name,
    current_model = M.config.model,
  }
end

-- Commands ----------------------------------------------------------------

vim.api.nvim_create_user_command("AICommit", function(opts)
  M.generate_commit(opts.args)
end, {
  nargs = "?",
  desc = "Generate AI commit messages for staged changes",
})

vim.api.nvim_create_user_command("AICommitLast", function()
  M.show_last_commit_suggestions()
end, { desc = "Show last AI-generated commit suggestions" })

vim.api.nvim_create_user_command("AICommitLogin", function(opts)
  local provider = opts.args ~= "" and opts.args or M.config.provider
  require("ai-provider").login(provider, function(result, err)
    if result then
      vim.notify(provider .. ": authentication successful!", vim.log.levels.INFO)
    else
      vim.notify(provider .. ": authentication failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end, {
  nargs = "?",
  desc = "Authenticate with an AI provider (default: current provider)",
})

vim.api.nvim_create_user_command("AICommitLogout", function(opts)
  local provider = opts.args ~= "" and opts.args or M.config.provider
  require("ai-provider").logout(provider)
end, {
  nargs = "?",
  desc = "Remove stored credentials for an AI provider",
})

vim.api.nvim_create_user_command("AICommitStatus", function()
  local ai = require "ai-provider"
  local status = ai.status(M.config.provider)

  vim.notify(
    string.format("%s: %s\nProvider: %s | Model: %s", status.provider, status.message, M.config.provider, M.config.model),
    status.authenticated and vim.log.levels.INFO or vim.log.levels.WARN
  )
end, { desc = "Show current AI provider and authentication status" })

vim.api.nvim_create_user_command("AICommitModels", function(opts)
  local provider = opts.args ~= "" and opts.args or M.config.provider
  M.show_model_picker(provider)
end, {
  nargs = "?",
  desc = "Browse and select an AI model (default: current provider)",
})

return M
