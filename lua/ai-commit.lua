local M = {}

M.config = {
  provider = "openrouter",
  model = "google/gemini-2.5-flash",
  auto_push = false,
  commit_style = "regular",
  commit_styles = {},
  commit_prompt_template = nil, -- legacy global user prompt override
  system_prompt = nil,          -- legacy global system prompt override
  ignored_files = {},
  debug = false,
  max_tokens = 4096,
  max_diff_length = nil,
  ai_options = {},   -- per-request passthrough forwarded to ai-provider.complete_simple()
  ai_provider = nil, -- full ai-provider.setup() passthrough (global)
}

M.last_commit_messages = nil

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

local function get_data_dir()
  return vim.fn.stdpath "data" .. "/ai-commit"
end

local function load_json_file(path)
  local file = io.open(path, "r")

  if not file then
    return nil
  end

  local content = file:read "*a"
  file:close()

  local ok, data = pcall(vim.json.decode, content)

  if ok then
    return data
  end

  return nil
end

local function save_json_file(path, data)
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local file = io.open(path, "w")

  if file then
    file:write(vim.json.encode(data))
    file:close()
  end
end

local function get_model_save_path()
  return get_data_dir() .. "/model_selection.json"
end

local function get_commit_style_save_path()
  return get_data_dir() .. "/commit_style_selection.json"
end

--- Load the persisted model selection from disk.
--- Returns { provider = "…", model = "…" } or nil.
local function load_saved_model()
  local data = load_json_file(get_model_save_path())

  if data and data.provider and data.model then
    return data
  end

  return nil
end

--- Load the persisted commit style selection from disk.
--- Returns { style = "…" } or nil.
local function load_saved_commit_style()
  local data = load_json_file(get_commit_style_save_path())

  if data and data.style then
    return data
  end

  return nil
end

--- Persist the current provider + model to disk.
function M.save_model_selection()
  save_json_file(get_model_save_path(), {
    provider = M.config.provider,
    model = M.config.model,
  })
end

--- Persist the current commit style to disk.
function M.save_commit_style_selection()
  save_json_file(get_commit_style_save_path(), {
    style = M.config.commit_style,
  })
end

--- Apply a model selection – updates runtime config and saves to disk.
function M.set_model(model_id)
  M.config.model = model_id
  M.save_model_selection()
end

function M.get_commit_styles()
  return require("commit_generator").list_commit_styles(M.config)
end

local function has_commit_style(style_name)
  return require("commit_generator").has_commit_style(M.config, style_name)
end

function M.get_current_commit_style()
  return require("commit_generator").resolve_commit_style(M.config, M.config.commit_style)
end

--- Apply a commit style selection – updates runtime config and saves to disk.
--- @param style_name string
--- @return boolean ok
function M.set_commit_style(style_name)
  if not has_commit_style(style_name) then
    vim.notify("Unknown commit style: " .. tostring(style_name), vim.log.levels.ERROR)
    return false
  end

  M.config.commit_style = style_name
  M.save_commit_style_selection()
  return true
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

local function apply_ai_provider_setup(opts)
  if not opts or not opts.ai_provider then return end
  require("ai-provider").setup(opts.ai_provider)
end

local function normalize_commit_style()
  if not has_commit_style(M.config.commit_style) then
    M.config.commit_style = "regular"
  end
end

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  -- Forward ai-provider config through the consumer plugin for convenience.
  apply_ai_provider_setup(opts)

  normalize_commit_style()

  -- Restore previously picked model (only if provider still matches).
  local saved_model = load_saved_model()

  if saved_model and saved_model.provider == M.config.provider then
    M.config.model = saved_model.model
  end

  -- Restore previously picked commit style when it still exists.
  local saved_style = load_saved_commit_style()

  if saved_style and has_commit_style(saved_style.style) then
    M.config.commit_style = saved_style.style
  end
end

M.generate_commit = function(extra_prompt)
  require("commit_generator").generate_commit(M.config, extra_prompt)
end

--- Generate commit messages from an explicit diff (for integration with other plugins).
--- @param diff_text string The diff to generate messages for
--- @param opts? table { extra_prompt?: string, style?: string, on_select?: fun(message: string), on_result?: fun(messages: string[]|nil, err: string|nil), show_picker?: boolean }
M.generate_commit_for_diff = function(diff_text, opts)
  require("commit_generator").generate_for_diff(M.config, diff_text, opts)
end

--- Generate commit messages from an explicit diff without opening Telescope.
--- @param diff_text string The diff to generate messages for
--- @param opts? table { extra_prompt?: string, style?: string }
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

--- Open a Telescope picker with commit styles.
M.show_commit_style_picker = function()
  local has_telescope, _ = pcall(require, "telescope")
  if not has_telescope then
    error "This plugin requires nvim-telescope/telescope.nvim"
  end

  require("telescope").extensions["ai-commit"].styles {
    current_style = M.config.commit_style,
  }
end

local function complete_commit_styles(arg_lead)
  local matches = {}

  for _, style in ipairs(M.get_commit_styles()) do
    if arg_lead == "" or style.key:find(arg_lead, 1, true) == 1 then
      table.insert(matches, style.key)
    end
  end

  return matches
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
  local style_key, style = M.get_current_commit_style()

  vim.notify(
    string.format(
      "%s: %s\nProvider: %s | Model: %s | Style: %s (%s)",
      status.provider,
      status.message,
      M.config.provider,
      M.config.model,
      style.label,
      style_key
    ),
    status.authenticated and vim.log.levels.INFO or vim.log.levels.WARN
  )
end, { desc = "Show current AI provider, model, and commit style" })

vim.api.nvim_create_user_command("AICommitModels", function(opts)
  local provider = opts.args ~= "" and opts.args or M.config.provider
  M.show_model_picker(provider)
end, {
  nargs = "?",
  desc = "Browse and select an AI model (default: current provider)",
})

vim.api.nvim_create_user_command("AICommitStyle", function(opts)
  if opts.args ~= "" then
    if M.set_commit_style(opts.args) then
      local style_key, style = M.get_current_commit_style()
      vim.notify("Commit style set to: " .. style.label .. " (" .. style_key .. ")", vim.log.levels.INFO)
    end
    return
  end

  M.show_commit_style_picker()
end, {
  nargs = "?",
  complete = complete_commit_styles,
  desc = "Browse or set the active AI commit style",
})

return M
