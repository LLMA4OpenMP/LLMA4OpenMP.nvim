local Utils = require("codegpt.utils")
local Ui = require("codegpt.ui")
local TS = require("codegpt.parser")

local CommandsList = {}
local cmd_default = {
    model = "gpt-3.5-turbo",
    max_tokens = 4096,
    temperature = 0.1,
    number_of_choices = 1,
    system_message_template = "You are ParallelGPT, an autonomous agent specialized in parallel computing that assists developers in optimizing their code by parallelizing C programs using OpenMP.\nBe cautious and careful, always try to understand the code and make sure all your modification will not creat any data-race conditions.\nYour decisions must always be made independently without seeking user assistance.\nYou will be given some 'parallelizing experiences', you must learn from the code and comments in the 'parallelizing experiences', especially the comments, as it can help you do the right parallelization.\nWhen you try to parallelize a loop, there must be at least one experiences that support your decision.\nIf you think the loop is parallelizable, return the exact same loop with the correct modification, do not create anything else (like a declearation expression or a comment). If you think the loop is not parallelizable, return the exact same loop with your comment on why it is not parallelizable.",
    user_message_template = "You need use OpenMP to parallelize the following {{language}} loop:\n```{{filetype}}\n{{text_selection}}\n```\nHere are some parallelizing experiences:\n{{command_args}}",
    callback_type = "replace_lines",
}

CommandsList.CallbackTypes = {
    ["text_popup"] = function(lines, bufnr, start_row, start_col, end_row, end_col)
        local popup_filetype = vim.g["codegpt_text_popup_filetype"]
        Ui.popup(lines, popup_filetype, bufnr, start_row, start_col, end_row, end_col)
    end,
    ["code_popup"] = function(lines, bufnr, start_row, start_col, end_row, end_col)
        lines = Utils.trim_to_code_block(lines)
        Utils.fix_indentation(bufnr, start_row, end_row, lines)
        Ui.popup(lines, Utils.get_filetype(), bufnr, start_row, start_col, end_row, end_col)
    end,
    ["replace_lines"] = function(lines, bufnr, start_row, start_col, end_row, end_col)
        lines = Utils.trim_to_code_block(lines)
        Utils.fix_indentation(bufnr, start_row, end_row, lines)
        if vim.api.nvim_buf_is_valid(bufnr) == true then
            Utils.replace_lines(lines, bufnr, start_row, start_col, end_row, end_col)
        else
            Ui.popup(lines, Utils.get_filetype(), bufnr, start_row, start_col, end_row, end_col)
        end
    end,
    ["custom"] = nil,
}

function CommandsList.get_cmd_opts(cmd)
    local opts = cmd_default

    if opts.callback_type == "custom" then
        opts.callback = user_set_opts.callback
    else
        opts.callback = CommandsList.CallbackTypes[opts.callback_type]
    end

    return opts
end

return CommandsList
