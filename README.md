# ai-commit.nvim

Generate AI commit message suggestions for your staged changes.

`ai-commit.nvim` reads the staged diff, asks an AI model for several Conventional Commit suggestions, and lets you pick one from Telescope.

It can also be used by other plugins through a small public API.

![image](https://i.imgur.com/mDR44F5.png)

## Features

- generate multiple commit message suggestions from staged changes
- Conventional Commit output
- OpenRouter and GitHub Copilot support via `ai-provider.nvim`
- Telescope picker UI
- model browser via `:AICommitModels`
- ignored file filtering
- optional auto-push after commit
- gitcommit buffer support
- debug prompt logging
- public API for generating messages from an explicit diff

---

## Requirements

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim)

---

## Installation

### 1. GitHub Copilot setup

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

### 2. OpenRouter setup

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

### 3. Local development setup

```lua
{
  dir = "/mnt/shared/projects/personal/nvim-plugins/ai-commit.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    { dir = "/mnt/shared/projects/personal/nvim-plugins/ai-provider.nvim" },
  },
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
  },
}
```

---

## Provider setup

## OpenRouter

Set your key:

```bash
export OPENROUTER_API_KEY=sk-...
```

Or forward it through the plugin:

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "openrouter",
    model = "google/gemini-2.5-flash",
    provider_config = {
      openrouter = {
        api_key = "sk-your-key",
      },
    },
  },
}
```

## GitHub Copilot

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
  },
}
```

Authenticate once:

```vim
:AICommitLogin
```

### GitHub Enterprise

```lua
{
  "cjvnjde/ai-commit.nvim",
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

---

## Configuration

```lua
{
  provider = "openrouter",
  model = "google/gemini-2.5-flash",
  auto_push = false,
  max_tokens = 4096,
  max_diff_length = nil,
  commit_prompt_template = nil,
  system_prompt = nil,
  ignored_files = {},
  debug = false,

  provider_config = {
    openrouter = { api_key = nil },
    ["github-copilot"] = { enterprise_domain = nil },
  },
}
```

## Options

| Option | Type | Description |
| --- | --- | --- |
| `provider` | `string` | `openrouter` or `github-copilot` |
| `model` | `string` | model ID for the selected provider |
| `auto_push` | `boolean` | push after successful commit |
| `max_tokens` | `number` | max output tokens |
| `max_diff_length` | `number?` | truncate large diffs before sending |
| `commit_prompt_template` | `string?` | custom user prompt |
| `system_prompt` | `string?` | custom system prompt |
| `ignored_files` | `string[]` | ignore files/globs in staged diff |
| `debug` | `boolean` | save prompts to cache |
| `provider_config` | `table?` | forwarded to `ai-provider.setup()` |

---

## Usage

## Basic staged commit flow

```bash
git add .
```

Then in Neovim:

```vim
:AICommit
```

Pick a message from Telescope and press `<Enter>`.

## With extra instructions

```vim
:AICommit focus on performance improvements
:AICommit emphasize the refactor
:AICommit prefer a concise subject and body
```

## In a `gitcommit` buffer

If the current buffer has `filetype=gitcommit`, selecting a suggestion pastes the message into that buffer instead of running `git commit -m`.

---

## Model selection

```vim
:AICommitModels
:AICommitModels github-copilot
:AICommitModels openrouter
```

---

## Commands

| Command | Description |
| --- | --- |
| `:AICommit [extra prompt]` | Generate commit suggestions from staged changes |
| `:AICommitLast` | Re-open last generated suggestions |
| `:AICommitModels [provider]` | Select a model |
| `:AICommitLogin [provider]` | Authenticate provider |
| `:AICommitLogout [provider]` | Remove stored credentials |
| `:AICommitStatus` | Show provider + model + auth status |

---

## Examples

## 1. Ignore lockfiles and generated files

```lua
{
  "cjvnjde/ai-commit.nvim",
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
    },
  },
}
```

## 2. Use OpenRouter with a stronger model

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "openrouter",
    model = "google/gemini-2.5-pro",
  },
}
```

## 3. Use Copilot with a fast model

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    provider = "github-copilot",
    model = "gpt-5-mini",
  },
}
```

## 4. Forward provider config through the plugin

```lua
{
  "cjvnjde/ai-commit.nvim",
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

If `on_select` is omitted, the plugin uses its default behavior unless `show_picker = false` is set.

---

## Logging

When a request is sent, you now get a single clearer notification.

Example:

```text
Sending AI request: AICommit -> github-copilot / gpt-5-mini -> api.githubcopilot.com
```

This makes it obvious:
- which plugin initiated the request
- which provider is being used
- which model is being used
- which host receives the request

---

## Prompt customization

Available placeholders:
- `<git_diff/>`
- `<recent_commits/>`
- `<extra_prompt/>`

Example:

```lua
commit_prompt_template = [[
Write several Conventional Commit messages for the diff below.

Extra instructions:
<extra_prompt/>

Diff:
<git_diff/>

Recent commits:
<recent_commits/>
]]
```
