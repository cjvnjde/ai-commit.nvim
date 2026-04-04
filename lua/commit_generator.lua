local M = {}

local COMMIT_SEPARATOR = "--- END COMMIT ---"

local default_system_prompt = [[
You are a git commit message writer. Generate multiple, distinct, high-quality commit message options based on the provided git diff and recent commits.

General requirements:
- Always output 3-5 different commit message options unless the user explicitly asks for a different number.
- Each option should reflect a meaningfully different focus, phrasing, or emphasis so the user can choose the best fit.
- Use present tense and keep the subject concise.
- Add a body only when it materially improves clarity. If you add a body, leave a blank line between the subject and body.
- Output only commit messages. Do not add commentary, explanations, numbering, lists, quotes, code fences, or markdown formatting.
- After each complete commit message, write the separator line exactly as follows:
--- END COMMIT ---
If you omit the separator, the response may be interpreted as a single commit message.
]]

local builtin_commit_styles = {
  regular = {
    label = "Regular",
    description = "Default. Match the recent repository commit style when possible.",
    system_prompt = default_system_prompt,
    user_prompt = [[
Write several git commit messages for the provided changes.

Style rules:
- First, inspect Recent commits and infer the repository's usual commit style.
- Reuse that style closely: capitalization, punctuation, prefixes, scopes, tense, language, level of detail, and whether a body is typically used.
- If there are no previous commits or no clear pattern to follow, write short, regular, descriptive commit messages.
- Do not force Conventional Commits unless the recent commits already use them consistently.
- Do not force emojis unless the recent commits already use them consistently.

<extra_prompt/>

Git diff:
<git_diff/>

Recent commits:
<recent_commits/>
]],
  },
  conventional = {
    label = "Conventional Commits",
    description = "Use type(scope): subject with an optional body.",
    user_prompt = [[
Write several git commit messages for the provided changes using the Conventional Commits format.

Style rules:
- Use the format: type(scope): concise subject line
- Allowed types include: feat, fix, build, chore, ci, docs, style, refactor, perf, test
- The scope is optional, but include it when it adds useful context
- Keep the subject line under 74 characters
- If needed, add a short body after a blank line explaining what changed and why

<extra_prompt/>

Git diff:
<git_diff/>

Recent commits:
<recent_commits/>
]],
  },
  emoji = {
    label = "Emoji",
    description = "Start each commit subject with a fitting emoji.",
    user_prompt = [[
Write several git commit messages for the provided changes using an emoji-based style.

Style rules:
- Start each commit subject with one fitting emoji
- After the emoji, write a short, descriptive subject line
- Keep the message clear, concise, and easy to scan
- If needed, add a short body after a blank line explaining what changed and why
- Keep the language and tone natural; one emoji per commit subject is enough

<extra_prompt/>

Git diff:
<git_diff/>

Recent commits:
<recent_commits/>
]],
  },
}

local builtin_commit_style_order = { "regular", "conventional", "emoji" }

---------------------------------------------------------------------------
-- Commit styles
---------------------------------------------------------------------------

local function get_user_commit_styles(config)
  return config and config.commit_styles or {}
end

local function list_commit_style_names(config)
  local names = vim.deepcopy(builtin_commit_style_order)
  local custom = {}

  for name, _ in pairs(get_user_commit_styles(config)) do
    if not vim.tbl_contains(names, name) then
      table.insert(custom, name)
    end
  end

  table.sort(custom)
  vim.list_extend(names, custom)

  return names
end

local function get_regular_prompt_base(config)
  local builtin_regular = builtin_commit_styles.regular or {}
  local user_regular = get_user_commit_styles(config).regular or {}

  return {
    system_prompt = user_regular.system_prompt or builtin_regular.system_prompt or default_system_prompt,
    user_prompt = user_regular.user_prompt or builtin_regular.user_prompt or "",
  }
end

local function build_commit_style(config, style_name)
  local regular = get_regular_prompt_base(config)
  local builtin = builtin_commit_styles[style_name] or {}
  local user = get_user_commit_styles(config)[style_name] or {}

  return {
    key = style_name,
    label = user.label or user.name or builtin.label or style_name,
    description = user.description or builtin.description or "Custom commit style",
    system_prompt = user.system_prompt or builtin.system_prompt or regular.system_prompt or default_system_prompt,
    user_prompt = user.user_prompt or builtin.user_prompt or regular.user_prompt or "",
  }
end

function M.list_commit_styles(config)
  local styles = {}

  for _, style_name in ipairs(list_commit_style_names(config)) do
    table.insert(styles, build_commit_style(config, style_name))
  end

  return styles
end

function M.has_commit_style(config, style_name)
  if type(style_name) ~= "string" or style_name == "" then
    return false
  end

  for _, name in ipairs(list_commit_style_names(config)) do
    if name == style_name then
      return true
    end
  end

  return false
end

function M.resolve_commit_style(config, style_name)
  local requested = style_name

  if type(requested) ~= "string" or requested == "" then
    requested = config and config.commit_style or "regular"
  end

  if M.has_commit_style(config, requested) then
    return requested, build_commit_style(config, requested), false
  end

  return "regular", build_commit_style(config, "regular"), true
end

M.commit_separator = COMMIT_SEPARATOR

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
    if line:match "^diff%s+%-%-git" then
      finalize_hunk()

      current_hunk = { line }

      local old_file, new_file = line:match "^diff%s+%-%-git%s+a/(.-)%s+b/(.+)$"
      current_file = (new_file and new_file ~= "/dev/null") and new_file or old_file
    elseif #current_hunk > 0 then
      if line:match "^%-%-%- " then
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
  local recent_commits_list = vim.fn.systemlist "git log --format=%s -n 5 2>/dev/null"

  if vim.v.shell_error == 0 and #recent_commits_list > 0 then
    recent_commits = table.concat(recent_commits_list, "\n")
  else
    vim.fn.system "git rev-parse --verify HEAD 2>/dev/null"

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

local function build_template_context(git_data, extra_prompt)
  return {
    git_diff = git_data.diff or "",
    recent_commits = git_data.commits or "",
    extra_prompt = extra_prompt or "",
  }
end

local function render_template(template, context)
  template = template or ""

  for placeholder, value in pairs(context or {}) do
    local pattern = "<%s*" .. escape_pattern(placeholder) .. "%s*/>"
    local escaped_value = (value or ""):gsub("%%", "%%%%")
    template = template:gsub(pattern, escaped_value)
  end

  return template:gsub("<%s*[%w_]+%s*/>", "")
end

local function create_prompts(style, git_data, extra_prompt)
  local context = build_template_context(git_data, extra_prompt)
  local prompt = render_template(style.user_prompt, context)
  local system_prompt = render_template(style.system_prompt, context)

  return prompt, system_prompt
end

local function resolve_style_for_request(config, requested_style)
  local style_name, style, fallback = M.resolve_commit_style(config, requested_style)

  if fallback and requested_style and requested_style ~= "" then
    vim.notify("Unknown commit style: " .. requested_style .. ". Using regular.", vim.log.levels.WARN)
  end

  return style_name, style
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
  local parts = {}
  local start_pos = 1

  while true do
    local sep_start, sep_end = text:find(COMMIT_SEPARATOR, start_pos, true)

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

local function save_debug_prompt(path, prompt, system_prompt, style_name)
  if not path then return end
  local file = io.open(path, "w")
  if file then
    if style_name then
      file:write("=== COMMIT STYLE ===\n" .. style_name .. "\n\n")
    end
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

  local style_name, style = resolve_style_for_request(config, config.commit_style)
  local prompt, system_prompt = create_prompts(style, git_data, extra_prompt)

  -- Legacy top-level overrides still take precedence if provided.
  if config.commit_prompt_template ~= nil then
    prompt = render_template(config.commit_prompt_template, build_template_context(git_data, extra_prompt))
  end
  if config.system_prompt ~= nil then
    system_prompt = render_template(config.system_prompt, build_template_context(git_data, extra_prompt))
  end

  local debug_path = get_debug_path(config)
  save_debug_prompt(debug_path, prompt, system_prompt, style_name)

  send_request(config, prompt, system_prompt, nil, function(msg, err)
    handle_response(msg, { _debug_path = debug_path }, err)
  end)
end

--- Generate commit messages from an explicit diff text.
--- @param config table Plugin config
--- @param diff_text string The diff to generate messages for
--- @param opts? table { extra_prompt?: string, style?: string, on_select?: fun(message: string), on_result?: fun(messages: string[]|nil, err: string|nil), show_picker?: boolean }
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
  local style_name, style = resolve_style_for_request(config, opts.style or config.commit_style)
  local prompt, system_prompt = create_prompts(style, git_data, opts.extra_prompt)

  -- Legacy top-level overrides still take precedence if provided.
  if config.commit_prompt_template ~= nil then
    prompt = render_template(config.commit_prompt_template, build_template_context(git_data, opts.extra_prompt))
  end
  if config.system_prompt ~= nil then
    system_prompt = render_template(config.system_prompt, build_template_context(git_data, opts.extra_prompt))
  end

  local debug_path = get_debug_path(config)
  save_debug_prompt(debug_path, prompt, system_prompt, style_name)

  send_request(config, prompt, system_prompt, nil, function(msg, err)
    opts._debug_path = debug_path
    handle_response(msg, opts, err)
  end)
end

return M
