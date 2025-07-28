local M = {}

M.config = {
  env = {
    api_key = nil,
    url = nil,
    chat_url = nil,
  },
  model = nil,
  auto_push = false,
  commit_prompt_template = nil,
  system_prompt = nil,
  ignored_files = {},
  debug = false,
}

M.last_commit_messages = nil

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
end

M.generate_commit = function(extra_prompt)
  require("commit_generator").generate_commit(M.config, extra_prompt)
end

M.show_commit_suggestions = function(messages)
  M.last_commit_messages = messages

  local has_telescope, _ = pcall(require, "telescope")

  if not has_telescope then
    error "This plugin requires nvim-telescope/telescope.nvim"
  end

  require("telescope").extensions["ai-commit"].commit { messages = messages }
end

M.show_last_commit_suggestions = function()
  if M.last_commit_messages and #M.last_commit_messages > 0 then
    M.show_commit_suggestions(M.last_commit_messages)
  else
    vim.notify("No AI commit messages have been generated in this session.", vim.log.levels.WARN)
  end
end

vim.api.nvim_create_user_command("AICommit", function(opts)
  M.generate_commit(opts.args)
end, {
  nargs = "?",
})

vim.api.nvim_create_user_command("AICommitLast", function()
  M.show_last_commit_suggestions()
end, { desc = "Show last AI-generated commit suggestions" })

return M
