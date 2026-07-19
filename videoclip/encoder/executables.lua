--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html
]]

local utils = require('mp.utils')

local this = {}

local function alt_path_dirs()
    --- Return common executable directories outside PATH.
    return {
        '/opt/homebrew/bin',
        '/usr/local/bin',
        utils.join_path(os.getenv("HOME") or "~", '.local/bin'),
    }
end

--- Try to find name in alternative locations.
--- If not found, return name as is to use executable in PATH.
--- Examples:
---    find_exec("ffmpeg") → "/usr/local/bin/ffmpeg"
---    find_exec("ffmpeg") → "ffmpeg"
function this.find_exec(name)
    local path, info
    for _, alt_dir in pairs(alt_path_dirs()) do
        path = utils.join_path(alt_dir, name)
        info = utils.file_info(path)
        if info and info.is_file then
            return path
        end
    end
    return name
end

this.mpv = this.find_exec("mpv")
this.mpvnet = this.find_exec("mpvnet")
this.ffmpeg = this.find_exec("ffmpeg")

return this
