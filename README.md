# ai-commit.nvim

A Neovim plugin that uses AI to generate high-quality, conventional commit messages based on your staged git changes.

> [!WARNING]
> Currently, the plugin only supports [openrouter.ai](https://openrouter.ai), but support for other services (OpenAI, Anthropic, local Ollama, etc.) will be added in the future

![image](https://i.imgur.com/mDR44F5.png)

## Features

- **AI-powered commit messages** - Generate multiple commit message suggestions based on your staged changes
- **Conventional commits** - Follows conventional commit format with proper type, scope, and description
- **Telescope integration** - Clean, minimal dropdown interface for selecting commit messages
- **Flexible configuration** - Customizable prompts, models, and behavior
- **Smart diff handling** - Automatic truncation of large diffs to avoid token limits
- **File filtering** - Ignore specific files or patterns (e.g., `package-lock.json`, `*.log`) from commit analysis
- **Error resilience** - Robust error handling for git operations and API calls
- **Auto-push support** - Optional automatic push after successful commit
- **Session memory** - Remembers last suggestions for easy re-selection
- **Gitcommit buffer support** - Seamlessly works in git commit buffers
- **Asynchronous processing** - Non-blocking AI generation with progress feedback
- **Debug mode** - Save prompts to cache for troubleshooting and fine-tuning

## Prerequisites

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (for commit message selection)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "cjvnjde/ai-commit.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    opts = {
      -- your configuration here
    },
}
```

## API Key Setup

The plugin requires an OpenRouter API key for AI generation.

### Option 1: Environment Variable (Recommended)

Set your API key as an environment variable before launching Neovim:

```bash
export OPENROUTER_API_KEY=sk-...
```

### Option 2: Configuration

Alternatively, you can set it directly in your configuration:

```lua
{
  env = {
    api_key = "sk-your-api-key-here",
  },
  -- ... other options
}
```

## Configuration

You can configure the plugin in your setup call. Here are all the available options:

```lua
{
  env = {
    api_key = nil, -- Will fallback to OPENROUTER_API_KEY env var
    url = "https://openrouter.ai/api/v1/", -- Default OpenRouter URL
    chat_url = "chat/completions", -- Default chat endpoint
  },
  model = "google/gemini-2.5-flash", -- Default AI model
  auto_push = false, -- Automatically git push after committing
  max_tokens = 4096, -- Maximum tokens for AI response (nil = no limit)
  max_diff_length = nil, -- Truncate large diffs to avoid token limits (nil = no limit)
  commit_prompt_template = [[
    You are to generate multiple, different git commit messages based on the following git diff.
    Format: type(scope): subject
    Git diff: <git_diff/>
    Recent commits: <recent_commits/>
  ]], -- Custom prompt template (optional)
  system_prompt = [[
    You are a commit message writer for git...
  ]], -- Custom system prompt (optional)
  ignored_files = { "package-lock.json", "*.log" }, -- Files/patterns to exclude from diff
  debug = false, -- Save prompts to cache directory for debugging
}
```

| Option                   | Type      | Default                        | Description                                                                          |
| ------------------------ | --------- | ------------------------------ | ------------------------------------------------------------------------------------ |
| `env.api_key`            | string    | nil (uses env var)             | OpenRouter API key (automatically uses `OPENROUTER_API_KEY` if not set)              |
| `env.url`                | string    | "<https://openrouter.ai/api/v1/>"| OpenRouter base API URL                                                              |
| `env.chat_url`           | string    | "chat/completions"             | API path for chat/completions                                                        |
| `model`                  | string    | "google/gemini-2.5-flash"      | OpenRouter model ID                                                                  |
| `auto_push`              | boolean   | false                          | Push to remote after committing                                                      |
| `max_tokens`             | number    | 4096                           | Maximum tokens for AI response (nil disables limit)                                  |
| `max_diff_length`        | number    | nil (no limit)                 | Truncate diffs longer than this to avoid token limits (nil disables limit)           |
| `commit_prompt_template` | string    | see below                      | Template for the user prompt sent to AI (see Placeholders)                           |
| `system_prompt`          | string    | see below                      | System prompt for AI (defines commit style, count, format, etc.)                     |
| `ignored_files`          | string[]  | `{}`                           | List of file names or glob patterns to ignore from diff (supports `*.ext`, `dir/*`)  |
| `debug`                  | boolean   | false                          | Save prompts to cache directory for debugging purposes `:echo stdpath('cache')`                               |

## Customizing the Prompt Template

You can provide your own prompt template, using the following placeholders:

- <git_diff/> — Will be replaced with the output of git diff --cached
- <recent_commits/> — Will be replaced with the latest commits (from git log)
You can omit any placeholder you don’t want.
- <extra_prompt/> — Will be replaced with any extra instructions you provide when running the command (e.g. `:AICommit improve focus on refactoring and avoid mentioning tests`)

Example:

```lua
  commit_prompt_template = [[
    Please write several git commit messages using the conventional format.
    DIFF:
    <git_diff/>
    RECENT:
    <recent_commits/>
  ]],
```

## Usage

### Basic Workflow

1. **Stage your changes:**

   ```bash
   git add <files>
   ```

   Or use your favorite Git plugin (fugitive, gitsigns, etc.)

2. **Generate commit messages:**

   ```vim
   :AICommit
   ```

   **With extra instructions:**

   ```vim
   :AICommit focus on performance improvements and avoid mentioning tests
   ```

3. **Select a commit message:**
   - A Telescope picker will show multiple AI-generated suggestions
   - Preview each message in the right pane
   - Press `<Enter>` to select and commit
   - Press `<Esc>` to cancel

4. **Optional auto-push:**
   Enable `auto_push = true` in your configuration to automatically push after committing

### Additional Commands

- **`:AICommitLast`** - Recall and re-select from the last batch of generated suggestions

### Troubleshooting

If you encounter issues:

1. **Enable debug mode** in your configuration:

   ```lua
   debug = true
   ```

   This saves prompts to your cache directory for inspection.

2. **Check git status:**
   Ensure you have staged changes: `git diff --cached`

3. **Verify API key:**
   Make sure your `OPENROUTER_API_KEY` environment variable is set correctly.

## Commands

- `:AICommit [extra prompt]` - Start the commit message generation process
- `:AICommitLast` - Show the last batch of generated commit suggestions (for re-selection)
