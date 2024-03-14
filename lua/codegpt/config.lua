if os.getenv("OPENAI_API_KEY") ~= nil then
    vim.g["codegpt_openai_api_key"] = os.getenv("OPENAI_API_KEY")
end
vim.g["codegpt_chat_completions_url"] = "https://api.openai.com/v1/chat/completions"

vim.g["codegpt_openai_api_provider"] = "OpenAI"

-- clears visual selection after completion
vim.g["codegpt_clear_visual_selection"] = true

vim.g["codegpt_hooks"] = {
    request_started = nil,
    request_finished = nil,
}

-- Border style to use for the popup
vim.g["codegpt_popup_border"] = { style = "rounded" }

-- Wraps the text on the popup window, deprecated in favor of codegpt_popup_window_options
vim.g["codegpt_wrap_popup_text"] = true

vim.g["codegpt_popup_window_options"] = {}

-- set the filetype of a text popup is markdown
vim.g["codegpt_text_popup_filetype"] = "markdown"

-- Set the type of ui to use for the popup, options are "popup", "vertical" or "horizontal"
vim.g["codegpt_popup_type"] = "popup"

-- Set the height of the horizontal popup
vim.g["codegpt_horizontal_popup_size"] = "20%"

-- Set the width of the vertical popup
vim.g["codegpt_vertical_popup_size"] = "20%"

vim.g["codegpt_commands_defaults"] = {
    ["OMP"] = {
        user_message_template = "You need use OpenMP to parallelize the following {{language}} loop:\n```{{filetype}}\n{{text_selection}}\n```\n\nHere are some OpenMP experiences:\n{{command_args}}If the loop is parallelizable, return it with OpenMP directives, if not, return the exact loop, do not do further modification.",
    },
}

-- Popup commands
vim.g["codegpt_ui_commands"] = {
    quit = "q",
    use_as_output = "<c-o>",
    use_as_input = "<c-i>",
}
vim.g["codegpt_ui_custom_commands"] = {}
