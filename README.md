# ai-commit.nvim

A Neovim plugin that generates meaningful commit messages using AI based on your git changes.

> [!WARNING]
> Currently, the plugin only supports [openrouter.ai](https://openrouter.ai), but support for other services (OpenAI, Anthropic, local Ollama, etc.) will be added in the future

![image](https://i.imgur.com/mDR44F5.png)

## Features

- Generate commit messages based on staged changes
- Multiple AI-generated commit suggestions
- Clean and minimal dropdown interface
- Follows conventional commit format
- Optional automatic push after commit
- Asynchronous message generation without UI blocking

## Prerequisites

- Neovim >= 0.8.0
- Git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (for commit message selection)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "vernette/ai-commit.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("ai-commit").setup({
            -- your configuration
        })
    end
}
```

## Configuration

```lua
{
  openrouter_api_key = "YOUR_API_KEY", -- or set OPENROUTER_API_KEY environment variable
  model = "qwen/qwen-2.5-72b-instruct:free", -- default model
  auto_push = false, -- whether to automatically push after commit
  commit_prompt_template = "Custom commit message prompt. Git diff: %s Resent commits: %s", -- template for commit message generation
}
```

## Usage

1. Stage your changes using git add
2. Run `:AICommit` command
3. Wait for AI to generate commit messages
4. Choose from the suggested messages in the dropdown window
5. The selected message will be used for the commit

## Commands

- `:AICommit` - Start the commit message generation process
