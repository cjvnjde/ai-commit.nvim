local M = {}

M.config = {
  model = nil,
  auto_push = false,
  commit_prompt_template = nil,
}

M.setup = function(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
end

M.generate_commit = function()
  require("commit_generator").generate_commit(M.config)
end

M.show_commit_suggestions = function(messages)
  local has_telescope, _ = pcall(require, "telescope")
  if not has_telescope then
    error("This plugin requires nvim-telescope/telescope.nvim")
  end
  require("telescope").extensions["ai-commit"].commit({ messages = messages })
end

vim.api.nvim_create_user_command("AICommit", function()
  M.generate_commit()
end, {})

return M
