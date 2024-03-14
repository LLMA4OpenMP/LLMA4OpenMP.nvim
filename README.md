# LLMA4OpenMP.nvim


LLMA4OpenMP is a plugin for neovim that performs automatic parallelization on C code using OpenMP.

LLMA4OpenMP was modified from [dpayne/CodeGPT.nvim](https://github.com/dpayne/CodeGPT.nvim).

## Installation

* Set environment variable `OPENAI_API_KEY` to your [openai api key](https://platform.openai.com/account/api-keys).
* The plugins 'plenary' and 'nui' are also required.
* Requires ltreesitter for code parsing, check [euclidianAce/ltreesitter](https://github.com/euclidianAce/ltreesitter) for installation guide.

Install LLMA4OpenMP with [Lazy](https://github.com/folke/lazy.nvim).

```lua
{
    "LLMA4OpenMP/LLMA4OpenMP.nvim",
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
    },
    config = function()
        -- "codegpt.config" is correct
        require("codegpt.config")
    end
}
```

## Commands

To use the plugin, simply select the loop you want to parallelize and use the command `:OMP`. Then, wait for the parallelization process to complete.

Please note that LLMA4OpenMP does not support code comments.

![generation](example/OpenMP_code_generation.gif?raw=true)
