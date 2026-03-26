# ai-commit.nvim

A Neovim plugin that uses AI to generate high-quality, conventional commit messages based on your staged git changes.

![image](https://i.imgur.com/mDR44F5.png)

## Features

- **AI-powered commit messages** – Generate multiple commit message suggestions based on your staged changes
- **Multiple providers** – Supports [OpenRouter](https://openrouter.ai) and **GitHub Copilot** via [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim)
- **Model browser** – Browse and switch models with `:AICommitModels`
- **Conventional commits** – Follows conventional commit format with proper type, scope, and description
- **Telescope integration** – Clean, minimal dropdown interface for selecting commit messages
- **Flexible configuration** – Customizable prompts, models, and behavior
- **Smart diff handling** – Automatic truncation of large diffs to avoid token limits
- **File filtering** – Ignore specific files or patterns (e.g., `package-lock.json`, `*.log`) from commit analysis
- **Auto-push support** – Optional automatic push after successful commit
- **Session memory** – Remembers last suggestions for easy re-selection
- **Gitcommit buffer support** – Seamlessly works in git commit buffers
- **Debug mode** – Save prompts to cache for troubleshooting and fine-tuning

## Prerequisites

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "openrouter",          -- or "github-copilot"
    model = "google/gemini-2.5-flash", -- model ID (provider-specific)
  },
}
```

## Provider Setup

### OpenRouter (default)

Set your API key as an environment variable:

```bash
export OPENROUTER_API_KEY=sk-...
```

Or configure it explicitly via `ai-provider`:

```lua
require("ai-provider").setup({
  providers = {
    openrouter = { api_key = "sk-your-key" },
  },
})
```

### GitHub Copilot

Use your existing GitHub Copilot subscription — no separate API key needed:

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "github-copilot",
    model = "gpt-4o", -- or claude-sonnet-4, gemini-2.5-pro, etc.
  },
}
```

On first use (or via `:AICommitLogin`), a browser will open for one-time authorization. Tokens are cached and auto-refreshed.

#### GitHub Enterprise

```lua
require("ai-provider").setup({
  providers = {
    ["github-copilot"] = { enterprise_domain = "company.ghe.com" },
  },
})
```

Run `:AICommitModels` to browse all available models, or `:AICommitStatus` to check authentication.

## Configuration

```lua
{
  provider = "openrouter",            -- "openrouter" or "github-copilot"
  model = "google/gemini-2.5-flash",  -- model ID (depends on provider)
  auto_push = false,                  -- git push after committing
  max_tokens = 4096,                  -- max tokens for AI response
  max_diff_length = nil,              -- truncate large diffs (nil = no limit)
  commit_prompt_template = nil,       -- custom prompt template (see below)
  system_prompt = nil,                -- custom system prompt
  ignored_files = {},                 -- file patterns to exclude from diff
  debug = false,                      -- save prompts to cache for debugging

  -- Optional: forward provider config to ai-provider in one place
  provider_config = {
    openrouter = { api_key = nil },
    ["github-copilot"] = { enterprise_domain = nil },
  },
}
```

| Option                   | Type     | Default                     | Description                                              |
| ------------------------ | -------- | --------------------------- | -------------------------------------------------------- |
| `provider`               | string   | `"openrouter"`              | AI provider (`"openrouter"` or `"github-copilot"`)       |
| `model`                  | string   | `"google/gemini-2.5-flash"` | Model ID (provider-specific)                             |
| `auto_push`              | boolean  | `false`                     | Push to remote after committing                          |
| `max_tokens`             | number   | `4096`                      | Maximum tokens for AI response                           |
| `max_diff_length`        | number   | `nil`                       | Truncate diffs longer than this                          |
| `commit_prompt_template` | string   | built-in                    | Template for the user prompt                             |
| `system_prompt`          | string   | built-in                    | System prompt defining commit style                      |
| `ignored_files`          | string[] | `{}`                        | File names or globs to ignore                            |
| `debug`                  | boolean  | `false`                     | Save prompts to cache (`:echo stdpath('cache')`)         |
| `provider_config`        | table    | `nil`                       | Forwarded to `ai-provider.setup({ providers = ... })`    |

## Customizing the Prompt Template

Available placeholders:

- `<git_diff/>` — Replaced with the output of `git diff --cached`
- `<recent_commits/>` — Replaced with the latest commits from `git log`
- `<extra_prompt/>` — Replaced with extra text passed to `:AICommit <text>`

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

1. **Stage your changes:** `git add <files>`
2. **Generate commit messages:** `:AICommit`
   - With extra instructions: `:AICommit focus on performance improvements`
3. **Select a message** from the Telescope picker and press `<Enter>` to commit

### Browse Models

```vim
:AICommitModels
```

Opens a Telescope picker showing all available models for the current provider. Select one to switch models for the session.

```vim
:AICommitModels github-copilot
:AICommitModels openrouter
```

## Commands

| Command                         | Description                                            |
| ------------------------------- | ------------------------------------------------------ |
| `:AICommit [extra prompt]`      | Generate commit message suggestions                    |
| `:AICommitLast`                 | Re-show the last batch of generated suggestions        |
| `:AICommitModels [provider]`    | Browse and select a model                              |
| `:AICommitLogin [provider]`     | Authenticate with a provider                           |
| `:AICommitLogout [provider]`    | Remove stored credentials                              |
| `:AICommitStatus`               | Show provider, model, and auth status                  |
