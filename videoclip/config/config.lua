--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Read/save config file.
]]

local mp = require('mp')
local mpopt = require('mp.options')
local defaults = require("config.defaults")
local msg = require('mp.msg')
local utils = require('mp.utils')
local h = require('helpers')

local this = {}
local NAME = 'videoclip'

this.read_config_file = function()
    --- Reads the cofig file and returns a new copy of the config dict.
    local config = defaults.get_default()
    mpopt.read_options(config, NAME)
    msg.info("Read config file: " .. NAME .. ".conf")
    return config
end

local function lua_to_mpv(config_value)
    if type(config_value) == 'boolean' then
        return config_value and 'yes' or 'no'
    else
        return config_value
    end
end

this.save_config_file = function(config)
    local ignore_list = {
        video_extension = true,
        audio_extension = true,
        video_codec = true,
        audio_codec = true,
    }
    local mpv_dirpath = string.gsub(mp.get_script_directory(), "scripts[\\/][^\\/]+", "")
    local config_filepath = utils.join_path(utils.join_path(mpv_dirpath, "script-opts"), string.format('%s.conf', NAME))
    local handle = io.open(config_filepath, 'w')
    if handle ~= nil then
        handle:write(string.format("# Written by %s on %s.\n", NAME, os.date()))
        for key, value in pairs(config) do
            if ignore_list[key] == nil then
                handle:write(string.format('%s=%s\n', key, lua_to_mpv(value)))
            end
        end
        handle:close()
        return "Settings saved.", nil
    else
        return nil, string.format("Couldn't open %s.", config_filepath)
    end
end

return this
