local Commands = require("codegpt.commands")
local CommandsList = require("codegpt.commands_list")
local Utils = require("codegpt.utils")
local Parser = require("codegpt.parser")
local Providers = require("codegpt.providers")
local CodeGptModule = {}

function CodeGptModule.get_status(...)
    return Commands.get_status(...)
end

function CodeGptModule.run_cmd(opts)
    local text_selection = Utils.get_selected_lines()
    
    Parser.init()

    local experiences = Parser.check(text_selection)

    if experiences then
    	Commands.run_cmd("OMP", experiences, text_selection)
    else
    	print("Not parallelizable!")
    end
end

return CodeGptModule
