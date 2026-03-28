# ai-commit.nvim

Generate AI commit message suggestions for your staged changes.

`ai-commit.nvim` reads the staged diff, asks an AI model for several Conventional Commit suggestions, and lets you pick one from a Telescope picker. It supports multiple providers through [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim) — including GitHub Copilot (free with a Copilot subscription) and OpenRouter (access to dozens of models).

It can also be used by other plugins (like [ai-split-commit.nvim](https://github.com/cjvnjde/ai-split-commit.nvim)) through a small public API to generate commit messages from an arbitrary diff.

![image](https://i.imgur.com/mDR44F5.png)

## Features

- Generate multiple commit message suggestions from staged changes
- Conventional Commits output (type(scope): subject + optional body)
- Telescope picker UI with preview
- Model browser via `:AICommitModels`
- Ignored file filtering (skip lockfiles, build output, etc.)
- Binary-safe staged diff handling
- Optional auto-push after commit
- Gitcommit buffer support (pastes the message instead of committing)
- Extra instructions via command args (e.g., `:AICommit focus on the bug fix`)
- Custom prompt templates
- Debug prompt logging
- Public API for generating messages from an explicit diff

---

## Requirements

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim)

---

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
  },
}
```

---

## Setup

```lua
require("ai-commit").setup(opts)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `provider` | `string` | `"openrouter"` | AI provider to use. One of `"openrouter"`, `"github-copilot"`, `"anthropic"`, `"google"`, `"openai"`, `"xai"`, `"groq"`, `"cerebras"`, `"mistral"`. |
| `model` | `string` | `"google/gemini-2.5-flash"` | Model ID for the selected provider. Use `:AICommitModels` to browse available models. |
| `auto_push` | `boolean` | `false` | Automatically push after a successful commit. |
| `max_tokens` | `number` | `4096` | Maximum output tokens for the AI response. |
| `max_diff_length` | `number?` | `nil` | Truncate the staged diff to this many characters before sending. Useful for very large diffs that would exceed token limits. When `nil`, the full diff is sent. |
| `commit_prompt_template` | `string?` | `nil` | Custom user prompt template. See [Prompt Customization](#prompt-customization) for available placeholders. When `nil`, the built-in template is used. |
| `system_prompt` | `string?` | `nil` | Custom system prompt. When `nil`, the built-in system prompt is used. |
| `ignored_files` | `string[]` | `{}` | List of file paths or glob patterns to exclude from the staged diff before sending to the AI. |
| `debug` | `boolean` | `false` | Save prompts to `~/.cache/nvim/ai-commit-debug/` for inspection. |
| `provider_config` | `table?` | `nil` | Provider-specific settings forwarded to `ai-provider.setup()`. See [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim) for details. |

---

## Configuration Examples

### 1. GitHub Copilot with GPT-5 Mini

The simplest setup — free with a GitHub Copilot subscription:

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
  },
}
```

Then authenticate once:

```vim
:AICommitLogin
```

### 2. OpenRouter with Gemini 2.5 Flash

```bash
export OPENROUTER_API_KEY=sk-or-...
```

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "openrouter",
    model = "google/gemini-2.5-flash",
  },
}
```

### 3. OpenRouter with explicit API key (no env variable)

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "openrouter",
    model = "google/gemini-2.5-flash",
    provider_config = {
      openrouter = {
        api_key = "sk-or-your-key-here",
      },
    },
  },
}
```

### 4. OpenRouter with a stronger model

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "openrouter",
    model = "anthropic/claude-sonnet-4",
  },
}
```

### 5. GitHub Copilot with Claude Sonnet 4.6

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "claude-sonnet-4.6",
  },
}
```

### 6. GitHub Enterprise Copilot

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
    provider_config = {
      ["github-copilot"] = {
        enterprise_domain = "company.ghe.com",
      },
    },
  },
}
```

### 7. Ignore lockfiles, generated files, and build output

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
    ignored_files = {
      "package-lock.json",
      "yarn.lock",
      "pnpm-lock.yaml",
      "lazy-lock.json",
      "dist/*",
      "build/*",
      "*.min.js",
      "*.min.css",
    },
  },
}
```

### 8. Auto-push after commit

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
    auto_push = true,
  },
}
```

### 9. Truncate large diffs

Useful for monorepos or very large changesets:

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "openrouter",
    model = "google/gemini-2.5-pro",
    max_diff_length = 20000,
    max_tokens = 8192,
  },
}
```

### 10. Debug mode — inspect prompts

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
    debug = true,
  },
}
```

Prompts are saved to `~/.cache/nvim/ai-commit-debug/`.

### 11. Anthropic Claude direct (via API key)

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "anthropic",
    model = "claude-sonnet-4-20250514",
  },
}
```

### 12. Google Gemini direct (via API key)

```bash
export GEMINI_API_KEY=AIza...
```

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "google",
    model = "gemini-2.5-flash",
  },
}
```

### 13. Full kitchen-sink configuration

```lua
{
  "cjvnjde/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "cjvnjde/ai-provider.nvim",
  },
  opts = {
    provider = "github-copilot",
    model = "claude-sonnet-4.6",
    auto_push = false,
    max_tokens = 8192,
    max_diff_length = 30000,
    debug = false,
    ignored_files = {
      "package-lock.json",
      "yarn.lock",
      "pnpm-lock.yaml",
      "dist/*",
    },
    provider_config = {
      ["github-copilot"] = {
        enterprise_domain = "company.ghe.com",
      },
    },
  },
}
```

---

## Usage

### Basic staged commit flow

```bash
git add .
```

Then in Neovim:

```vim
:AICommit
```

Pick a message from Telescope and press `<Enter>`.

### With extra instructions

```vim
:AICommit focus on performance improvements
:AICommit emphasize the refactor
:AICommit prefer a concise subject and body
:AICommit this is a breaking change
```

### In a gitcommit buffer

If the current buffer has `filetype=gitcommit` (e.g., when running `git commit` with `EDITOR=nvim`), selecting a suggestion pastes the message into that buffer instead of running `git commit -m`.

---

## Commands

| Command | Description |
| --- | --- |
| `:AICommit [extra prompt]` | Generate commit suggestions from staged changes. Optional extra instructions are appended to the prompt. |
| `:AICommitLast` | Re-open the last generated suggestions in Telescope (no new AI request). |
| `:AICommitModels [provider]` | Browse and select a model for the current or specified provider. The selection is persisted to disk. |
| `:AICommitLogin [provider]` | Authenticate with a provider (default: current provider). Required for GitHub Copilot. |
| `:AICommitLogout [provider]` | Remove stored credentials for a provider. |
| `:AICommitStatus` | Show current provider, model, and authentication status. |

---

## Model Selection

```vim
:AICommitModels
:AICommitModels github-copilot
:AICommitModels openrouter
:AICommitModels anthropic
:AICommitModels google
```

The selected model is persisted to `~/.local/share/nvim/ai-commit/model_selection.json` and restored on next startup (as long as the provider matches).

---

## Public API

### Generate from staged changes

```lua
require("ai-commit").generate_commit()
require("ai-commit").generate_commit("emphasize test changes")
```

### Generate from an explicit diff

This is used by `ai-split-commit.nvim`, but you can use it yourself too.

#### Interactive selection (opens Telescope)

```lua
require("ai-commit").generate_commit_for_diff(diff_text, {
  extra_prompt = "focus on the bug fix",
  on_select = function(message)
    print("selected:", message)
  end,
})
```

#### Collect generated messages without opening Telescope

```lua
require("ai-commit").generate_commit_for_diff(diff_text, {
  extra_prompt = "Generate exactly one commit message only.",
  show_picker = false,
  on_result = function(messages, err)
    if err then
      print(err)
      return
    end
    print(messages[1])
  end,
})
```

#### Convenience wrapper for no-picker usage

```lua
require("ai-commit").generate_commit_messages_for_diff(diff_text, {
  extra_prompt = "Generate exactly one commit message only.",
}, function(messages, err)
  if err then
    print(err)
    return
  end
  print(messages[1])
end)
```

If `on_select` is omitted, the plugin uses its default behavior (commit or paste into gitcommit buffer) unless `show_picker = false` is set.

---

## Prompt Customization

You can replace the user prompt and/or system prompt entirely.

### Available placeholders

| Placeholder | Description |
|-------------|-------------|
| `<git_diff/>` | The staged diff (after filtering and truncation) |
| `<recent_commits/>` | The last 5 commit subjects from `git log --oneline` |
| `<extra_prompt/>` | Extra instructions passed via `:AICommit ...` args |

### Example: custom prompt template

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
    commit_prompt_template = [[
Write several Conventional Commit messages for the diff below.

Extra instructions:
<extra_prompt/>

Diff:
<git_diff/>

Recent commits:
<recent_commits/>
]],
  },
}
```

### Example: custom system prompt

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
    system_prompt = [[
You are a commit message writer. Generate 3-5 commit messages
following Conventional Commits. Be concise. Use present tense.
Separate each message with: --- END COMMIT ---
]],
  },
}
```

---

## Logging

When a request is sent, you see a single notification:

```text
Sending AI request: AICommit -> github-copilot / gpt-5-mini -> api.githubcopilot.com
```

This tells you which plugin initiated the request, which provider and model are being used, and which host receives the request.
