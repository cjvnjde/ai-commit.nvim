local M = {}

local default_commit_prompt_template = [[
You are to generate multiple, different git commit messages based on the following git diff.

Format:
- Each message must follow the Conventional Commits standard (type(scope): subject).
- If a longer explanation is needed, add a body after a blank line, explaining WHAT and WHY.
- Output at least 3–5 different commit messages, each focusing on a different significant aspect or perspective of the changes.
- Separate each commit message with the separator: --- END COMMIT ---
- Do NOT use quotes or backticks.

<extra_prompt/>

Git diff:
<git_diff/>

Recent commits:
<recent_commits/>
]]

local default_system_prompt = [[
You are a commit message writer for git. Your task is to generate multiple, distinct, high-quality commit messages following the Conventional Commits standard (types: feat, fix, build, chore, ci, docs, style, refactor, perf, test). Always output at least 3–5 different options, each reflecting a different possible focus or aspect of the changes, so the user can choose the most suitable one.

For each commit message:

- Use the format: type(scope): concise subject line
  The scope is optional, but recommended if it clarifies the context.
- Use the present tense and keep subject lines under 74 characters
- If needed, add a body after a blank line. In the body, explain WHAT was changed and, if relevant, briefly explain WHY the changes were made. Be clear but concise; don't start with "This commit..."
- Each option should capture a different angle or purpose: e.g., focus on features, bug fixes, refactoring, or testing.
- Do NOT use quotes, backticks, or code formatting. Output only commit messages.

**Separator:** After each commit message (including body, if present), write the separator line exactly as follows:
--- END COMMIT ---

Never add any other explanation, commentary, or formatting outside the commit messages and separator.

Your output should look like this:

type(scope): short summary

Longer body if needed, explaining what and why.

--- END COMMIT ---

type(other_scope): another summary

Another body.

--- END COMMIT ---

(etc.)
]]

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function split_diff_by_file(diff)
  local hunks = {}
  local current_hunk = {}
  local current_file = nil

  local function finalize_hunk()
    if current_file and #current_hunk > 0 then
      table.insert(hunks, { filename = current_file, hunk = table.concat(current_hunk, "\n") })
    end

    current_hunk = {}
    current_file = nil
  end

  local lines = vim.split(diff, "\n", { plain = true, trimempty = false })

  for _, line in ipairs(lines) do
    if line:match "^diff%s+--git" then
      finalize_hunk()

      current_hunk = { line }

      local old_file, new_file = line:match "^diff%s+%-%-git%s+a/(.-)%s+b/(.+)$"
      current_file = (new_file and new_file ~= "/dev/null") and new_file or old_file
    elseif #current_hunk > 0 then
      if line:match "^--- " then
        local a_file = line:match "^%-%-%-%s+(.+)$"

        if a_file and a_file ~= "/dev/null" then
          current_file = a_file:gsub("^a/", "")
        end
      elseif line:match "^%+%+%+ " then
        local b_file = line:match "^%+%+%+%s+(.+)$"

        if b_file and b_file ~= "/dev/null" then
          current_file = b_file:gsub("^b/", "")
        end
      elseif line:match "^Binary files " then
        local old_file, new_file = line:match "^Binary files (.-) and (.+) differ$"

        if new_file and new_file ~= "/dev/null" then
          current_file = new_file:gsub("^b/", "")
        elseif old_file and old_file ~= "/dev/null" then
          current_file = old_file:gsub("^a/", "")
        end
      end

      table.insert(current_hunk, line)
    end
  end

  finalize_hunk()

  return hunks
end

local function is_file_ignored(filename, ignored)
  for _, pattern in ipairs(ignored or {}) do
    if filename == pattern then
      return true
    end

    local regpat = vim.fn.glob2regpat(pattern)

    if filename:match(regpat) then
      return true
    end
  end

  return false
end

local function get_recent_commits()
  local recent_commits = ""
  local recent_commits_list = vim.fn.systemlist "git log --oneline -n 5 2>/dev/null"

  if vim.v.shell_error == 0 and #recent_commits_list > 0 then
    recent_commits = table.concat(recent_commits_list, "\n")
  else
    vim.fn.system "git rev-parse HEAD 2>/dev/null"

    if vim.v.shell_error ~= 0 then
      recent_commits = "Initial repository (no previous commits)"
    end
  end

  return recent_commits
end

local function prepare_diff_context(config, diff_context, empty_message)
  diff_context = diff_context or ""

  if diff_context == "" then
    return nil, empty_message or "No changes found.", false
  end

  local ignored_files = config and config.ignored_files or {}
  local max_diff_length = config and config.max_diff_length

  if #ignored_files > 0 then
    local hunks = split_diff_by_file(diff_context)

    if #hunks > 0 then
      local filtered = {}

      for _, h in ipairs(hunks) do
        if not is_file_ignored(h.filename or "", ignored_files) then
          table.insert(filtered, h.hunk)
        end
      end

      diff_context = table.concat(filtered, "\n")
    end

    if diff_context == "" then
      return nil, "All changes are in ignored files or no changes found.", false
    end
  end

  if max_diff_length and #diff_context > max_diff_length then
    return diff_context:sub(1, max_diff_length) .. "\n... (diff truncated for token limits)", nil, true
  end

  return diff_context, nil, false
end

local function collect_git_data(config)
  local diff_context =
    vim.fn.system "git -P diff --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/ --cached -U10"

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get git diff: Not in a git repo or git not available?", vim.log.levels.ERROR)
    return nil
  end

  local prepared, err, truncated = prepare_diff_context(config, diff_context, "No staged changes found. Add files with 'git add' first.")

  if not prepared then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  if truncated then
    vim.notify("Diff truncated to avoid token limits.", vim.log.levels.INFO)
  end

  return { diff = prepared, commits = get_recent_commits() }
end

local function escape_pattern(str)
  return (str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function create_prompt(git_data, template, extra_prompt)
  template = template or default_commit_prompt_template

  local replacements = {
    ["<git_diff/>"] = git_data.diff or "",
    ["<recent_commits/>"] = git_data.commits or "",
    ["<extra_prompt/>"] = extra_prompt or "",
  }

  for placeholder, value in pairs(replacements) do
    local escaped_placeholder = escape_pattern(placeholder)
    local escaped_value = (value:gsub("%%", "%%%%"))
    template = template:gsub(escaped_placeholder, escaped_value)
  end

  template = template:gsub("<[%w_]+/>", "")
  return template
end

---------------------------------------------------------------------------
-- Streaming request helper
---------------------------------------------------------------------------

local function send_request(config, prompt, system_prompt, options, callback)
  local ai = require "ai-provider"
  local model = ai.get_model(config.provider or "openrouter", config.model)

  if not model then
    local err = "Unknown model: " .. (config.provider or "openrouter") .. "/" .. config.model
    callback(nil, err)
    return
  end

  local context = {
    system_prompt = system_prompt or default_system_prompt,
    messages = { { role = "user", content = prompt } },
  }

  local opts = vim.tbl_deep_extend("force", {
    max_tokens = config.max_tokens,
  }, config.ai_options or {}, options or {})

  ai.complete_simple(model, context, opts, function(msg)
    vim.schedule(function()
      callback(msg, nil)
    end)
  end)
end

---------------------------------------------------------------------------
-- Response handling
---------------------------------------------------------------------------

local save_debug_response

local function parse_commit_messages(text)
  local messages = {}
  local separator = "--- END COMMIT ---"
  local parts = {}
  local start_pos = 1

  while true do
    local sep_start, sep_end = text:find(separator, start_pos, true)

    if not sep_start then
      local remaining = text:sub(start_pos)
      if remaining:match "%S" then
        table.insert(parts, remaining)
      end
      break
    end

    table.insert(parts, text:sub(start_pos, sep_start - 1))
    start_pos = sep_end + 1
  end

  for _, part in ipairs(parts) do
    part = part:gsub("^%s+", ""):gsub("%s+$", "")
    if part ~= "" then
      table.insert(messages, part)
    end
  end

  return messages
end

--- Extract concatenated text from an AssistantMessage.
local function extract_text(msg)
  local parts = {}
  for _, block in ipairs(msg.content or {}) do
    if block.type == "text" and block.text then
      table.insert(parts, block.text)
    end
  end
  return table.concat(parts, "")
end

local function emit_result(opts, messages, err)
  if opts and opts.on_result then
    opts.on_result(messages, err)
  end
end

local function handle_response(msg, opts, err)
  if not msg then
    local emsg = err or "Request failed"
    emit_result(opts, nil, emsg)
    vim.notify("Request failed: " .. emsg, vim.log.levels.ERROR)
    return
  end

  -- Save response to debug file if path was captured
  if opts and opts._debug_path then
    save_debug_response(opts._debug_path, msg)
  end

  if msg.stop_reason == "error" or msg.stop_reason == "aborted" then
    local emsg = msg.error_message or "Request failed"
    emit_result(opts, nil, emsg)
    vim.notify("Request failed: " .. emsg, vim.log.levels.ERROR)
    return
  end

  local text = extract_text(msg)

  if text == "" then
    emit_result(opts, nil, "Received empty response from model")
    vim.notify("Received empty response from model. Try again in a few moments.", vim.log.levels.WARN)
    return
  end

  local messages = parse_commit_messages(text)

  if #messages == 0 then
    emit_result(opts, nil, "No commit messages were generated")
    vim.notify("No commit messages were generated. Try again or modify your changes.", vim.log.levels.WARN)
    return
  end

  emit_result(opts, messages, nil)

  if opts and opts.show_picker == false and not opts.on_select then
    return
  end

  require("ai-commit").show_commit_suggestions(messages, opts)
end

---------------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------------

local function get_debug_path(config)
  if not config.debug then return nil end
  local dir = vim.fn.stdpath "cache" .. "/ai-commit-debug"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. os.date "%Y%m%d_%H%M%S" .. ".txt"
end

local function save_debug_prompt(path, prompt, system_prompt)
  if not path then return end
  local file = io.open(path, "w")
  if file then
    file:write("=== SYSTEM PROMPT ===\n" .. (system_prompt or ""))
    file:write("\n\n=== USER PROMPT ===\n" .. prompt)
    file:close()
  end
end

save_debug_response = function(path, msg)
  if not path or not msg then return end
  local file = io.open(path, "a")
  if not file then return end

  file:write("\n\n=== RESPONSE ===\n")
  file:write("stop_reason: " .. (msg.stop_reason or "?") .. "\n")
  if msg.error_message then
    file:write("error: " .. msg.error_message .. "\n")
  end
  if msg.usage then
    local u = msg.usage
    file:write(string.format("usage: %d in / %d out / %d cached",
      u.input or 0, u.output or 0, u.cache_read or 0))
    if (u.reasoning_tokens or 0) > 0 then
      file:write(string.format(" / %d reasoning", u.reasoning_tokens))
    end
    file:write("\n")
  end
  file:write("\n")
  for _, block in ipairs(msg.content or {}) do
    if block.type == "thinking" and block.thinking then
      file:write("[thinking]\n" .. block.thinking .. "\n\n")
    elseif block.type == "text" and block.text then
      file:write(block.text)
    end
  end
  file:close()
  vim.schedule(function()
    vim.notify("Debug: saved to " .. path, vim.log.levels.INFO)
  end)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function M.generate_commit(config, extra_prompt)
  local git_data = collect_git_data(config)
  if not git_data then
    return
  end

  local template = config.commit_prompt_template or default_commit_prompt_template
  local system_prompt = config.system_prompt or default_system_prompt
  local prompt = create_prompt(git_data, template, extra_prompt)

  local debug_path = get_debug_path(config)
  save_debug_prompt(debug_path, prompt, system_prompt)

  send_request(config, prompt, system_prompt, nil, function(msg, err)
    handle_response(msg, { _debug_path = debug_path }, err)
  end)
end

--- Generate commit messages from an explicit diff text.
--- @param config table Plugin config
--- @param diff_text string The diff to generate messages for
--- @param opts? table { extra_prompt?: string, on_select?: fun(message: string), on_result?: fun(messages: string[]|nil, err: string|nil), show_picker?: boolean }
function M.generate_for_diff(config, diff_text, opts)
  opts = opts or {}

  local prepared, err, truncated = prepare_diff_context(config, diff_text, "No changes found in provided diff.")

  if not prepared then
    emit_result(opts, nil, err)
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if truncated then
    vim.notify("Diff truncated to avoid token limits.", vim.log.levels.INFO)
  end

  local git_data = { diff = prepared, commits = get_recent_commits() }
  local template = config.commit_prompt_template or default_commit_prompt_template
  local system_prompt = config.system_prompt or default_system_prompt
  local prompt = create_prompt(git_data, template, opts.extra_prompt)

  local debug_path = get_debug_path(config)
  save_debug_prompt(debug_path, prompt, system_prompt)

  send_request(config, prompt, system_prompt, nil, function(msg, err)
    opts._debug_path = debug_path
    handle_response(msg, opts, err)
  end)
end

return M
