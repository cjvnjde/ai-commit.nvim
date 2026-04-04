# ai-commit.nvim

Generate AI commit message suggestions for your staged changes.

`ai-commit.nvim` reads the staged diff, asks an AI model for several commit message suggestions in the selected style, and lets you pick one from a Telescope picker. It supports multiple providers through [ai-provider.nvim](https://github.com/cjvnjde/ai-provider.nvim) — including GitHub Copilot (free with a Copilot subscription) and OpenRouter (access to dozens of models).

It can also be used by other plugins (like [ai-split-commit.nvim](https://github.com/cjvnjde/ai-split-commit.nvim)) through a small public API to generate commit messages from an arbitrary diff.

![image](https://i.postimg.cc/QCD3WpJ4/temp-screenshot-20260328-210514.png)

## Features

- Generate multiple commit message suggestions from staged changes
- Built-in commit styles: `regular`, `conventional`, and `emoji`
- Persisted commit style selection via `:AICommitStyle`
- Telescope picker UI with preview
- Model browser via `:AICommitModels`
- Ignored file filtering (skip lockfiles, build output, etc.)
- Binary-safe staged diff handling
- Optional auto-push after commit
- Gitcommit buffer support (pastes the message instead of committing)
- Extra instructions via command args (e.g., `:AICommit focus on the bug fix`)
- Custom commit styles with placeholder support
- Legacy full prompt overrides
- Debug prompt/response logging
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
| `commit_style` | `string` | `"regular"` | Active commit style. Built-ins: `regular` (default), `conventional`, `emoji`. Use `:AICommitStyle` to switch and persist it. |
| `commit_styles` | `table` | `{}` | Custom commit style dictionary, e.g. `{ my_style = { label?, description?, system_prompt?, user_prompt? } }`. Missing `system_prompt` or `user_prompt` fields inherit from the built-in `regular` style. |
| `max_tokens` | `number` | `4096` | Maximum output tokens for the AI response. |
| `max_diff_length` | `number?` | `nil` | Truncate the staged diff to this many characters before sending. Useful for very large diffs that would exceed token limits. When `nil`, the full diff is sent. |
| `commit_prompt_template` | `string?` | `nil` | Legacy global user prompt override. Overrides the active style's `user_prompt` for all styles. See [Commit Styles and Prompt Customization](#commit-styles-and-prompt-customization). |
| `system_prompt` | `string?` | `nil` | Legacy global system prompt override. Overrides the resolved style system prompt for all styles. |
| `ignored_files` | `string[]` | `{}` | List of file paths or glob patterns to exclude from the staged diff before sending to the AI. |
| `debug` | `boolean` | `false` | Save prompt + response transcripts to `~/.cache/nvim/ai-commit-debug/` for inspection. |
| `ai_options` | `table` | `{}` | Per-request options forwarded to `ai-provider.complete_simple()`. Use this for request-scoped settings such as `reasoning`, `temperature`, `headers`, or future request parameters added by `ai-provider.nvim`. |
| `ai_provider` | `table?` | `nil` | Full shared `ai-provider.setup()` passthrough. Use this to configure global `ai-provider.nvim` behavior such as `reasoning`, `debug`, `debug_toast`, `notification`, `providers`, or `custom_models` directly from `ai-commit.nvim`, with no separate `ai-provider.nvim` config block required. |

### `ai_provider` vs `ai_options`

- Use `ai_options` for **this plugin's requests only**.
- Use `ai_provider` for **shared/global `ai-provider.nvim` setup**.
- `debug = true` in `ai-commit.nvim` saves a readable prompt/response transcript for commit generation.
- `ai_provider.debug = true` saves raw provider-level JSON request/response dumps.
- If both `ai-commit.nvim` and another plugin set `ai_provider`, the resulting `ai-provider.nvim` config is shared, because `ai-provider.nvim` itself is global.
- In normal setups, you do **not** need a separate `ai-provider.nvim` `opts = { ... }` block at all.

Common patterns:

**1. High reasoning only for commit generation**

```lua
opts = {
  provider = "github-copilot",
  model = "gpt-5-mini",
  ai_options = {
    reasoning = "high",
  },
}
```

**2. Enable debug dumps + live debug toast globally through `ai-commit.nvim`**

```lua
opts = {
  provider = "github-copilot",
  model = "gpt-5-mini",
  ai_options = {
    reasoning = "high",
  },
  ai_provider = {
    debug = true,
    debug_toast = { enabled = true },
    notification = { enabled = true },
  },
}
```

**3. Register or override models without touching `ai-provider.nvim` directly**

```lua
opts = {
  provider = "openrouter",
  model = "openai/gpt-5-mini",
  ai_provider = {
    custom_models = {
      openrouter = {
        {
          id = "openai/gpt-5-mini",
          name = "GPT-5 Mini (my tuned preset)",
          api = "openai-completions",
          provider = "openrouter",
          base_url = "https://openrouter.ai/api/v1",
          reasoning = true,
          input = { "text", "image" },
          context_window = 128000,
          max_tokens = 64000,
        },
      },
    },
  },
}
```

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
    ai_provider = {
      providers = {
        openrouter = {
          api_key = "sk-or-your-key-here",
        },
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
    ai_provider = {
      providers = {
        ["github-copilot"] = {
          enterprise_domain = "company.ghe.com",
        },
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

### 10. Debug mode — inspect prompt + response

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

Prompt + response transcripts are saved to `~/.cache/nvim/ai-commit-debug/`.

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
    ai_provider = {
      providers = {
        ["github-copilot"] = {
          enterprise_domain = "company.ghe.com",
        },
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

### Select a commit style

```vim
:AICommitStyle
:AICommitStyle regular
:AICommitStyle conventional
:AICommitStyle emoji
```

The selected style is saved and reused for future commit generation requests.

### In a gitcommit buffer

If the current buffer has `filetype=gitcommit` (e.g., when running `git commit` with `EDITOR=nvim`), selecting a suggestion pastes the message into that buffer instead of running `git commit -m`.

---

## Commands

| Command | Description |
| --- | --- |
| `:AICommit [extra prompt]` | Generate commit suggestions from staged changes using the active style. Optional extra instructions are appended to the prompt. |
| `:AICommitLast` | Re-open the last generated suggestions in Telescope (no new AI request). |
| `:AICommitStyle [style]` | Open a style picker or set the active commit style directly. The selection is persisted to disk. |
| `:AICommitModels [provider]` | Browse and select a model for the current or specified provider. The selection is persisted to disk. |
| `:AICommitLogin [provider]` | Authenticate with a provider (default: current provider). Required for GitHub Copilot. |
| `:AICommitLogout [provider]` | Remove stored credentials for a provider. |
| `:AICommitStatus` | Show current provider, model, and commit style. |

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

## Commit Style Selection

Built-in styles:

- `regular` — default style. It checks recent commits and tries to match the existing repository style. If there are no previous commits, it falls back to short descriptive messages.
- `conventional` — Conventional Commits (`type(scope): subject`) with an optional body.
- `emoji` — concise commit messages that start with a fitting emoji.

Use either the Telescope picker or direct command:

```vim
:AICommitStyle
:AICommitStyle regular
:AICommitStyle conventional
:AICommitStyle emoji
```

The selected style is persisted to `~/.local/share/nvim/ai-commit/commit_style_selection.json` and restored on next startup if that style still exists.

---

## Public API

### Generate from staged changes

```lua
require("ai-commit").generate_commit()
require("ai-commit").generate_commit("emphasize test changes")
```

### Generate from an explicit diff

This is used by `ai-split-commit.nvim`, but you can use it yourself too. Pass `style = "..."` to override the currently selected style for a single request.

#### Interactive selection (opens Telescope)

```lua
require("ai-commit").generate_commit_for_diff(diff_text, {
  style = "emoji",
  extra_prompt = "focus on the bug fix",
  on_select = function(message)
    print("selected:", message)
  end,
})
```

#### Collect generated messages without opening Telescope

```lua
require("ai-commit").generate_commit_for_diff(diff_text, {
  style = "conventional",
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
  style = "regular",
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

## Commit Styles and Prompt Customization

The plugin now has style-independent default system behavior plus style-specific prompts.

### Built-in styles

- `regular` — default. Inspect recent commits and try to match the existing repository style. If there are no previous commits, write short descriptive messages.
- `conventional` — Conventional Commits output.
- `emoji` — commit subjects start with a fitting emoji.

### Custom styles

Add custom styles with `commit_styles`:

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    commit_style = "jira",
    commit_styles = {
      jira = {
        label = "Jira",
        description = "Short commits prefixed with a ticket reference",
        system_prompt = [[
You are a commit message writer.
Generate several concise commit message options.
Always separate each complete commit message with:
--- END COMMIT ---
]],
        user_prompt = [[
Write several short commit messages for the diff below.

Style rules:
- Match the general tone of recent commits when possible.
- If <extra_prompt /> contains a ticket number, place it at the start of the subject.
- Keep the subject short and descriptive.

Diff:
<git_diff />

Recent commits:
<recent_commits />
]],
      },
    },
  },
}
```

Each custom style can define:

- `label`
- `description`
- `system_prompt`
- `user_prompt`

If `system_prompt` or `user_prompt` is missing, that field inherits from the built-in `regular` style.

You can also override built-in styles by reusing their keys:

```lua
{
  "cjvnjde/ai-commit.nvim",
  opts = {
    commit_styles = {
      conventional = {
        user_prompt = [[
Write several Conventional Commit messages.
Prefer very short subjects and only add a body when necessary.

Diff:
<git_diff/>

Recent commits:
<recent_commits/>
]],
      },
    },
  },
}
```

### Available placeholders

Placeholders work in both `system_prompt` and `user_prompt`.
A space before `/>` is also accepted, so both `<git_diff/>` and `<git_diff />` work.

| Placeholder | Description |
|-------------|-------------|
| `<git_diff/>` | The staged diff (after filtering and truncation) |
| `<recent_commits/>` | The last 5 commit subjects from `git log --format=%s -n 5` |
| `<extra_prompt/>` | Extra instructions passed via `:AICommit ...` args |

### Separator note

For multiple suggestions to be parsed correctly, prompts should tell the model to separate each commit with exactly:

```text
--- END COMMIT ---
```

The built-in prompts already do this. If you fully override prompts and omit the separator instruction, the plugin still works, but the whole response will be treated as a single commit suggestion.

### Legacy global overrides

For backward compatibility, you can still override the active style globally with `commit_prompt_template` and `system_prompt`:

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
    system_prompt = [[
You are a commit message writer.
Generate 3-5 concise commit messages.
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
