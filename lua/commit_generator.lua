local M = {}

local openrouter_api_endpoint = "https://openrouter.ai/api/v1/chat/completions"
local default_commit_prompt_template = [[
You are to generate multiple, different git commit messages based on the following git diff.

Format:
- Each message must follow the Conventional Commits standard (type(scope): subject).
- If a longer explanation is needed, add a body after a blank line, explaining WHAT and WHY.
- Output at least 3–5 different commit messages, each focusing on a different significant aspect or perspective of the changes.
- Separate each commit message with the separator: --- END COMMIT ---
- Do NOT use quotes or backticks.

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

local function validate_api_key()
  local api_key = vim.env.OPENROUTER_API_KEY

  if not api_key then
    vim.notify("OpenRouter API key not found. Please set OPENROUTER_API_KEY environment variable", vim.log.levels.ERROR)
    return nil
  end

  return api_key
end

local function split_diff_by_file(diff)
  local hunks = {}
  local current_hunk = {}
  local current_file = nil

  for line in diff:gmatch "([^\n]*)\n?" do
    if line:match "^diff%s+--git" then
      if current_file and #current_hunk > 0 then
        table.insert(hunks, { filename = current_file, hunk = table.concat(current_hunk, "\n") })
      end
      current_hunk = { line }
      current_file = nil
    elseif line:match "^%+%+%+ b/" then
      local file = line:match "^%+%+%+ b/(.+)"
      if not file or file == "/dev/null" then
        for i = #current_hunk, 1, -1 do
          local prev = current_hunk[i]
          local a_file = prev and prev:match "^--- a/(.+)"
          if a_file and a_file ~= "/dev/null" then
            file = a_file
            break
          end
        end
      end
      current_file = file
      table.insert(current_hunk, line)
    elseif #current_hunk > 0 then
      table.insert(current_hunk, line)
    end
  end

  if current_file and #current_hunk > 0 then
    table.insert(hunks, { filename = current_file, hunk = table.concat(current_hunk, "\n") })
  end

  return hunks
end

local function is_file_ignored(filename, ignored)
  for _, pattern in ipairs(ignored or {}) do
    if filename == pattern or filename:match(pattern) then
      return true
    end
  end

  return false
end

local function collect_git_data(config)
  local diff_context = vim.fn.system "git -P diff --cached -U10"

  if diff_context == "" then
    vim.notify("No staged changes found. Add files with 'git add' first.", vim.log.levels.ERROR)
    return nil
  end

  local ignored_files = config and config.ignored_files or {}

  if #ignored_files > 0 then
    local hunks = split_diff_by_file(diff_context)
    local filtered = {}

    for _, h in ipairs(hunks) do
      if not is_file_ignored(h.filename or "", ignored_files) then
        table.insert(filtered, h.hunk)
      end
    end

    diff_context = table.concat(filtered, "\n")
  end

  local recent_commits = vim.fn.system "git log --oneline -n 5"

  return {
    diff = diff_context,
    commits = recent_commits,
  }
end

local function create_prompt(git_data, template)
  template = template or default_commit_prompt_template

  local replacements = {
    ["<git_diff/>"] = git_data.diff or "",
    ["<recent_commits/>"] = git_data.commits or "",
  }

  for placeholder, value in pairs(replacements) do
    template = template:gsub(placeholder, value)
  end

  template = template:gsub("<[%w_]+/>", "")

  return template
end

local function prepare_request_data(prompt, system_prompt, model)
  system_prompt = system_prompt or default_system_prompt

  return {
    model = model,
    max_tokens = 4096,
    messages = {
      {
        role = "system",
        content = system_prompt,
      },
      {
        role = "user",
        content = prompt,
      },
    },
  }
end

local function parse_commit_messages(text)
  local messages = {}
  for msg in text:gmatch "(.-)%s*%-%-%- END COMMIT %-%-%-" do
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    if msg ~= "" then
      table.insert(messages, msg)
    end
  end
  return messages
end

local function handle_api_response(response)
  if response.status == 200 then
    local data = vim.json.decode(response.body)
    local messages = {}

    if data.choices and #data.choices > 0 and data.choices[1].message and data.choices[1].message.content then
      local message_content = data.choices[1].message.content

      messages = parse_commit_messages(message_content)

      if #messages > 0 then
        require("ai-commit").show_commit_suggestions(messages)
      else
        vim.notify("No commit messages were generated. Try again or modify your changes.", vim.log.levels.WARN)
      end
    else
      vim.notify(
        "Received empty response from model. The model may be warming up, try again in a few moments.",
        vim.log.levels.WARN
      )
    end
  else
    local error_info = "Unknown error"

    local ok, error_data = pcall(vim.json.decode, response.body)

    if ok and error_data and error_data.error then
      local error_code = error_data.error.code or response.status
      local error_message = error_data.error.message or "No error message provided"

      if error_code == 402 then
        error_info = "Insufficient credits: " .. error_message
      elseif error_code == 403 and error_data.error.metadata and error_data.error.metadata.reasons then
        local reasons = table.concat(error_data.error.metadata.reasons, ", ")
        error_info = "Content moderation error: " .. reasons
        if error_data.error.metadata.flagged_input then
          error_info = error_info .. " (flagged input: '" .. error_data.error.metadata.flagged_input .. "')"
        end
      elseif error_code == 408 then
        error_info = "Request timed out. Try again later."
      elseif error_code == 429 then
        error_info = "Rate limited. Please wait before trying again."
      elseif error_code == 502 then
        error_info = "Model provider error: " .. error_message
        if error_data.error.metadata and error_data.error.metadata.provider_name then
          error_info = error_info .. " (provider: " .. error_data.error.metadata.provider_name .. ")"
        end
      elseif error_code == 503 then
        error_info = "No available model provider: " .. error_message
      else
        error_info = string.format("Error %d: %s", error_code, error_message)
      end
    else
      error_info = string.format("Error %d: %s", response.status, response.body)
    end

    vim.notify("Failed to generate commit message: " .. error_info, vim.log.levels.ERROR)
  end
end

local function send_api_request(api_key, data)
  vim.schedule(function()
    vim.notify("Generating commit message...", vim.log.levels.INFO)
  end)

  require("plenary.curl").post(openrouter_api_endpoint, {
    headers = {
      content_type = "application/json",
      authorization = "Bearer " .. api_key,
    },
    body = vim.json.encode(data),
    callback = vim.schedule_wrap(handle_api_response),
  })
end

function M.generate_commit(config)
  local api_key = validate_api_key()

  if not api_key then
    return
  end

  local git_data = collect_git_data(config)

  if not git_data then
    return
  end

  local template = config.commit_prompt_template or default_commit_prompt_template
  local system_prompt = config.system_prompt or default_system_prompt

  local prompt = create_prompt(git_data, template)
  local data = prepare_request_data(prompt, system_prompt, config.model)

  send_api_request(api_key, data)
end

return M
