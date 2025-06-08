# ai-commit.nvim

A Neovim plugin that uses AI to generate high-quality, conventional commit messages based on your staged git changes.

> [!WARNING]
> Currently, the plugin only supports [openrouter.ai](https://openrouter.ai), but support for other services (OpenAI, Anthropic, local Ollama, etc.) will be added in the future

![image](https://i.imgur.com/mDR44F5.png)

## Features

- Generate commit messages based on staged changes
- Multiple AI-generated commit suggestions
- Clean and minimal dropdown interface
- Follows conventional commit format
- Optional automatic push after commit
- Remembers last suggestions so you can recall them
- Works in gitcommit buffers:
If you run :AICommit inside a `gitcommit` file (e.g., opened by :G commit or via git commit in terminal), the selected AI message will be inserted at the very top of your buffer—no manual copy-paste required.
- Asynchronous message generation without UI blocking

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

Set your API key as an environment variable before launching Neovim:

```bash
export OPENROUTER_API_KEY=sk-...
```

## Configuration

You can configure the plugin in your setup call. Here are all the available options:

```lua
{
  model = "google/gemini-2.0-flash-001", -- (required) OpenRouter model to use
  auto_push = false, -- (optional) Automatically git push after committing
  commit_prompt_template = [[
    You are to generate multiple, different git commit messages based on the following git diff.
    Format: type(scope): subject
    Git diff: <git_diff/>
    Recent commits: <recent_commits/>
  ]], -- (optional) Prompt template for commit message generation
  system_prompt = [[
    You are a commit message writer for git...
  ]], -- (optional) System prompt, for advanced customization
  ignored_files = { "package-lock.json" }, -- (optional) An array of file names or Lua patterns. Any matching file will be excluded from the diff used for commit message generation.
}
```

## Customizing the Prompt Template

You can provide your own prompt template, using the following placeholders:

- <git_diff/> — Will be replaced with the output of git diff --cached
- <recent_commits/> — Will be replaced with the latest commits (from git log)
You can omit any placeholder you don’t want.

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

1. Stage your changes:
git add <files> (or use your favorite plugin)
2. Generate commit messages:
Run :AICommit
3. Pick a message:
A Telescope picker will appear with several commit suggestions. Preview each with the right pane, then select one to commit.
4. (Optional) Push automatically:
Enable auto_push in your config to push right after the commit.

## Commands

- `:AICommit` - Start the commit message generation process
- `:AICommitLast` - Show the last batch of generated commit suggestions (for re-selection)
